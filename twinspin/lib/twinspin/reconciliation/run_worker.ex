defmodule Twinspin.Reconciliation.RunWorker do
  @moduledoc """
  GenServer that processes a single reconciliation run.
  Implements the divide-and-conquer partition algorithm and broadcasts
  progress updates via PubSub.
  """

  use GenServer
  require Logger
  alias Twinspin.Repo
  alias Twinspin.Reconciliation.{Run, Job, Partition, TableReconciliation, PartitionProcessor}
  import Ecto.Query

  defstruct [:run_id, :run, :job]

  # Client API

  def start_link(opts) do
    run_id = Keyword.fetch!(opts, :run_id)
    GenServer.start_link(__MODULE__, run_id, name: via_tuple(run_id))
  end

  def get_run_id(pid) do
    GenServer.call(pid, :get_run_id)
  end

  def cancel(run_id) do
    case Registry.lookup(Twinspin.RunRegistry, run_id) do
      [{pid, _}] -> GenServer.call(pid, :cancel)
      [] -> {:error, :not_found}
    end
  end

  # Server Callbacks

  @impl true
  def init(run_id) do
    # Register with Registry for lookups (handle already registered)
    case Registry.register(Twinspin.RunRegistry, run_id, nil) do
      {:ok, _} -> :ok
      {:error, {:already_registered, _pid}} -> :ok
    end

    run = load_run(run_id)
    job = load_job(run.reconciliation_job_id)

    state = %__MODULE__{
      run_id: run_id,
      run: run,
      job: job
    }

    # Start processing immediately
    {:ok, state, {:continue, :start_reconciliation}}
  end

  @impl true
  def handle_continue(:start_reconciliation, state) do
    Logger.info("Starting reconciliation run #{state.run_id}")

    # Update run status to running
    state = update_run_status(state, "running")

    # Process each table reconciliation
    state =
      Enum.reduce(state.job.table_reconciliations, state, fn table_rec, acc_state ->
        process_table_reconciliation(acc_state, table_rec)
      end)

    # Mark run as completed
    state = complete_run(state)

    Logger.info("Completed reconciliation run #{state.run_id}")

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_run_id, _from, state) do
    {:reply, state.run_id, state}
  end

  @impl true
  def handle_call(:cancel, _from, state) do
    Logger.info("Cancelling reconciliation run #{state.run_id}")

    state =
      state
      |> update_run_status("failed")
      |> update_run_error("Cancelled by user")

    {:stop, :normal, :ok, state}
  end

  # Private Functions

  defp via_tuple(run_id) do
    {:via, Registry, {Twinspin.RunRegistry, run_id}}
  end

  defp load_run(run_id) do
    Run
    |> Repo.get!(run_id)
  end

  defp load_job(job_id) do
    Job
    |> Repo.get!(job_id)
    |> Repo.preload([
      :source_database_connection,
      :target_database_connection,
      :table_reconciliations
    ])
  end

  defp process_table_reconciliation(state, table_rec) do
    Logger.info("Processing table: #{table_rec.table_name}")

    # Create root partition for this table
    root_partition = create_root_partition(state, table_rec)

    # Process the root partition recursively
    process_partition_tree(state, root_partition, table_rec, 0)

    state
  end

  defp create_root_partition(state, table_rec) do
    # Get estimated row count from source database
    row_count = estimate_row_count(state.job.source_database_connection, table_rec)

    {:ok, partition} =
      %Partition{}
      |> Partition.changeset(%{
        reconciliation_run_id: state.run_id,
        table_reconciliation_id: table_rec.id,
        partition_key: "0000-ZZZZ",
        depth: 0,
        status: "pending",
        row_count_estimate: row_count
      })
      |> Repo.insert()

    # Update total rows for run
    update_run_total_rows(state, row_count)

    partition
  end

  defp process_partition_tree(state, partition, table_rec, depth) do
    Logger.debug("Processing partition #{partition.partition_key} at depth #{depth}")

    # Update partition status
    partition = update_partition_status(partition, "processing")

    # Check if we need to split this partition
    should_split =
      partition.row_count_estimate > state.job.partition_row_threshold and
        depth < state.job.partition_max_depth

    if should_split do
      # Split partition and process children
      children = split_partition(state, partition, table_rec)

      Enum.each(children, fn child ->
        process_partition_tree(state, child, table_rec, depth + 1)
      end)

      # Mark parent as completed after children are processed
      update_partition_status(partition, "completed")
    else
      # Leaf partition - perform actual reconciliation
      discrepancies = reconcile_partition(state, partition, table_rec)

      # Update counters
      update_run_progress(state, partition.row_count_estimate, length(discrepancies))

      # Mark partition as completed
      update_partition_status(partition, "completed")
    end
  end

  defp split_partition(state, parent_partition, table_rec) do
    Logger.debug("Splitting partition #{parent_partition.partition_key}")

    # Split partition key range in half
    [start_key, end_key] = String.split(parent_partition.partition_key, "-")
    mid_key = calculate_mid_key(start_key, end_key)

    # Create two child partitions
    estimated_rows = div(parent_partition.row_count_estimate, 2)

    child1_attrs = %{
      reconciliation_run_id: state.run_id,
      table_reconciliation_id: table_rec.id,
      parent_partition_id: parent_partition.id,
      partition_key: "#{start_key}-#{mid_key}",
      depth: parent_partition.depth + 1,
      status: "pending",
      row_count_estimate: estimated_rows
    }

    child2_attrs = %{
      reconciliation_run_id: state.run_id,
      table_reconciliation_id: table_rec.id,
      parent_partition_id: parent_partition.id,
      partition_key: "#{mid_key}-#{end_key}",
      depth: parent_partition.depth + 1,
      status: "pending",
      row_count_estimate: estimated_rows
    }

    {:ok, child1} = %Partition{} |> Partition.changeset(child1_attrs) |> Repo.insert()
    {:ok, child2} = %Partition{} |> Partition.changeset(child2_attrs) |> Repo.insert()

    broadcast_run_updated(state)

    [child1, child2]
  end

  defp calculate_mid_key(start_key, end_key) do
    # Simple midpoint calculation for alphabetic keys
    # Convert to integers, find midpoint, convert back
    start_num = key_to_number(start_key)
    end_num = key_to_number(end_key)
    mid_num = div(start_num + end_num, 2)

    number_to_key(mid_num)
  end

  defp key_to_number(key) do
    # Convert "AAAA" to integer (base 26)
    key
    |> String.to_charlist()
    |> Enum.reduce(0, fn char, acc ->
      acc * 26 + (char - ?A)
    end)
  end

  defp number_to_key(num) do
    # Convert integer back to "AAAA" format
    if num == 0 do
      "AAAA"
    else
      digits = Integer.digits(num, 26)

      digits
      |> Enum.map(fn d -> d + ?A end)
      |> List.to_string()
      |> String.pad_leading(4, "A")
    end
  end

  defp reconcile_partition(state, partition, table_rec) do
    # Delegate to PartitionProcessor for actual reconciliation logic
    PartitionProcessor.reconcile(
      partition,
      table_rec,
      state.job.source_database_connection,
      state.job.target_database_connection
    )
  end

  defp estimate_row_count(_connection, _table_rec) do
    # Stub implementation - return random count for demo
    Enum.random(50_000..200_000)
  end

  defp update_run_status(state, status) do
    {:ok, run} =
      state.run
      |> Run.changeset(%{status: status})
      |> Repo.update()

    broadcast_run_updated(state)

    %{state | run: run}
  end

  defp update_run_error(state, error_message) do
    {:ok, run} =
      state.run
      |> Run.changeset(%{error_message: error_message})
      |> Repo.update()

    broadcast_run_updated(state)

    %{state | run: run}
  end

  defp update_run_total_rows(state, additional_rows) do
    current_total = state.run.total_rows || 0

    {:ok, _run} =
      state.run
      |> Run.changeset(%{total_rows: current_total + additional_rows})
      |> Repo.update()

    broadcast_run_updated(state)
  end

  defp update_run_progress(state, processed_rows, discrepancies_found) do
    current_processed = state.run.processed_rows || 0
    current_discrepancies = state.run.discrepancies_found || 0

    {:ok, _run} =
      state.run
      |> Run.changeset(%{
        processed_rows: current_processed + processed_rows,
        discrepancies_found: current_discrepancies + discrepancies_found
      })
      |> Repo.update()

    broadcast_run_updated(state)
  end

  defp complete_run(state) do
    {:ok, run} =
      state.run
      |> Run.changeset(%{
        status: "completed",
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.update()

    broadcast_run_updated(state)

    %{state | run: run}
  end

  defp update_partition_status(partition, status) do
    {:ok, partition} =
      partition
      |> Partition.changeset(%{status: status})
      |> Repo.update()

    partition
  end

  defp broadcast_run_updated(state) do
    # Reload run with fresh data for broadcast
    run = Repo.get!(Run, state.run_id)

    Phoenix.PubSub.broadcast(
      Twinspin.PubSub,
      "reconciliation_runs:#{state.job.id}",
      {:run_updated, run}
    )
  end
end
