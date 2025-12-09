defmodule Twinspin.Reconciliation.ReconciliationWorker do
  @moduledoc """
  Oban worker that processes reconciliation runs.
  Implements the divide-and-conquer partition algorithm and broadcasts
  progress updates via PubSub.
  """

  use Oban.Worker,
    queue: :reconciliation,
    max_attempts: 3

  require Logger
  alias Twinspin.Repo
  alias Twinspin.Reconciliation.{Run, Job, Partition, TableReconciliation, PartitionProcessor}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"run_id" => run_id}}) do
    Logger.info("Starting reconciliation run #{run_id}")

    run = load_run(run_id)
    job = load_job(run.reconciliation_job_id)

    # Update run status to running
    update_run_status(run, job, "running")

    # Track start time for ETA calculation
    start_time = System.monotonic_time(:second)

    # Process each table reconciliation
    Enum.each(job.table_reconciliations, fn table_rec ->
      process_table_reconciliation(run, job, table_rec, start_time)
    end)

    # Mark run as completed
    complete_run(run, job)

    Logger.info("Completed reconciliation run #{run_id}")

    :ok
  rescue
    error ->
      Logger.error("Reconciliation run #{run_id} failed: #{inspect(error)}")
      run = load_run(run_id)
      job = load_job(run.reconciliation_job_id)

      update_run_status(run, job, "failed")
      update_run_error(run, job, Exception.message(error))

      {:error, error}
  end

  # Private Functions

  defp load_run(run_id) do
    Repo.get!(Run, run_id)
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

  defp process_table_reconciliation(run, job, table_rec, start_time) do
    Logger.info("Processing table: #{table_rec.table_name}")

    # Create root partition for this table
    root_partition = create_root_partition(run, table_rec)

    # Process the root partition recursively
    process_partition_tree(run, job, root_partition, table_rec, 0, start_time)
  end

  defp create_root_partition(run, table_rec) do
    # Get estimated row count (stub for now)
    row_count = estimate_row_count(table_rec)

    {:ok, partition} =
      %Partition{}
      |> Partition.changeset(%{
        reconciliation_run_id: run.id,
        table_reconciliation_id: table_rec.id,
        partition_key: "0000-ZZZZ",
        depth: 0,
        status: "pending",
        row_count_estimate: row_count
      })
      |> Repo.insert()

    # Update total rows for run
    update_run_total_rows(run, row_count)

    partition
  end

  defp process_partition_tree(run, job, partition, table_rec, depth, start_time) do
    Logger.debug("Processing partition #{partition.partition_key} at depth #{depth}")

    # Update partition status to processing
    partition = update_partition_status(partition, "processing")

    # Broadcast partition started
    broadcast_partition_update(run, job, partition, "started")

    # Check if we need to split this partition
    should_split =
      partition.row_count_estimate > job.partition_row_threshold and
        depth < job.partition_max_depth

    if should_split do
      # Split partition and process children
      children = split_partition(run, partition, table_rec)

      # Broadcast partition split event
      broadcast_partition_update(run, job, partition, "split", %{
        children_count: length(children)
      })

      Enum.each(children, fn child ->
        process_partition_tree(run, job, child, table_rec, depth + 1, start_time)
      end)

      # Mark parent as completed after children are processed
      partition = update_partition_status(partition, "completed")
      broadcast_partition_update(run, job, partition, "completed")
    else
      # Leaf partition - perform actual reconciliation
      discrepancies = reconcile_partition(job, partition, table_rec)

      # Update counters
      update_run_progress(run, partition.row_count_estimate, length(discrepancies))

      # Calculate and broadcast progress with ETA
      fresh_run = Repo.get!(Run, run.id)
      broadcast_progress_update(fresh_run, job, start_time)

      # Mark partition as completed
      partition = update_partition_status(partition, "completed")
      broadcast_partition_update(run, job, partition, "completed")
    end

    # Broadcast updates after processing
    broadcast_run_updated(run, job)
  end

  defp split_partition(run, parent_partition, table_rec) do
    Logger.debug("Splitting partition #{parent_partition.partition_key}")

    # Split partition key range in half
    [start_key, end_key] = String.split(parent_partition.partition_key, "-")
    mid_key = calculate_mid_key(start_key, end_key)

    # Create two child partitions
    estimated_rows = div(parent_partition.row_count_estimate, 2)

    child1_attrs = %{
      reconciliation_run_id: run.id,
      table_reconciliation_id: table_rec.id,
      parent_partition_id: parent_partition.id,
      partition_key: "#{start_key}-#{mid_key}",
      depth: parent_partition.depth + 1,
      status: "pending",
      row_count_estimate: estimated_rows
    }

    child2_attrs = %{
      reconciliation_run_id: run.id,
      table_reconciliation_id: table_rec.id,
      parent_partition_id: parent_partition.id,
      partition_key: "#{mid_key}-#{end_key}",
      depth: parent_partition.depth + 1,
      status: "pending",
      row_count_estimate: estimated_rows
    }

    {:ok, child1} = %Partition{} |> Partition.changeset(child1_attrs) |> Repo.insert()
    {:ok, child2} = %Partition{} |> Partition.changeset(child2_attrs) |> Repo.insert()

    [child1, child2]
  end

  defp calculate_mid_key(start_key, end_key) do
    # Simple midpoint calculation for alphabetic keys
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

  defp reconcile_partition(job, partition, table_rec) do
    # Delegate to PartitionProcessor for actual reconciliation logic
    PartitionProcessor.reconcile(
      partition,
      table_rec,
      job.source_database_connection,
      job.target_database_connection
    )
  end

  defp estimate_row_count(_table_rec) do
    # Stub implementation - return random count for demo
    Enum.random(50_000..200_000)
  end

  defp update_run_status(run, job, status) do
    {:ok, updated_run} =
      run
      |> Run.changeset(%{status: status})
      |> Repo.update()

    broadcast_run_updated(updated_run, job)

    updated_run
  end

  defp update_run_error(run, job, error_message) do
    {:ok, updated_run} =
      run
      |> Run.changeset(%{error_message: error_message})
      |> Repo.update()

    broadcast_run_updated(updated_run, job)

    updated_run
  end

  defp update_run_total_rows(run, additional_rows) do
    current_total = run.total_rows || 0

    {:ok, _run} =
      run
      |> Run.changeset(%{total_rows: current_total + additional_rows})
      |> Repo.update()
  end

  defp update_run_progress(run, processed_rows, discrepancies_found) do
    current_processed = run.processed_rows || 0
    current_discrepancies = run.discrepancies_found || 0

    {:ok, _run} =
      run
      |> Run.changeset(%{
        processed_rows: current_processed + processed_rows,
        discrepancies_found: current_discrepancies + discrepancies_found
      })
      |> Repo.update()
  end

  defp complete_run(run, job) do
    {:ok, updated_run} =
      run
      |> Run.changeset(%{
        status: "completed",
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.update()

    broadcast_run_updated(updated_run, job)

    updated_run
  end

  defp update_partition_status(partition, status) do
    {:ok, partition} =
      partition
      |> Partition.changeset(%{status: status})
      |> Repo.update()

    partition
  end

  defp broadcast_run_updated(run, job) do
    # Reload run with fresh data for broadcast
    fresh_run = Repo.get!(Run, run.id)

    Phoenix.PubSub.broadcast(
      Twinspin.PubSub,
      "reconciliation_runs:#{job.id}",
      {:run_updated, fresh_run}
    )
  end

  defp broadcast_partition_update(run, job, partition, event_type, metadata \\ %{}) do
    Phoenix.PubSub.broadcast(
      Twinspin.PubSub,
      "reconciliation_runs:#{job.id}",
      {:partition_update,
       %{
         run_id: run.id,
         partition_id: partition.id,
         partition_key: partition.partition_key,
         status: partition.status,
         depth: partition.depth,
         event_type: event_type,
         timestamp: DateTime.utc_now()
       }}
    )
  end

  defp broadcast_progress_update(run, job, start_time) do
    current_time = System.monotonic_time(:second)
    elapsed_seconds = current_time - start_time

    # Calculate processing rate
    rows_per_second =
      if elapsed_seconds > 0 do
        run.processed_rows * 1.0 / elapsed_seconds
      else
        0.0
      end

    # Calculate ETA
    remaining_rows = run.total_rows - run.processed_rows

    eta_seconds =
      if rows_per_second > 0 do
        round(remaining_rows / rows_per_second)
      else
        nil
      end

    Phoenix.PubSub.broadcast(
      Twinspin.PubSub,
      "reconciliation_runs:#{job.id}",
      {:progress_update,
       %{
         run_id: run.id,
         processed_rows: run.processed_rows,
         total_rows: run.total_rows,
         discrepancies_found: run.discrepancies_found,
         rows_per_second: Float.round(rows_per_second, 2),
         eta_seconds: eta_seconds,
         elapsed_seconds: elapsed_seconds,
         timestamp: DateTime.utc_now()
       }}
    )
  end
end
