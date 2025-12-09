defmodule TwinspinWeb.ReconciliationLive.Show do
  use TwinspinWeb, :live_view
  alias Twinspin.Repo

  alias Twinspin.Reconciliation.{
    Job,
    Run,
    Partition
  }

  import Ecto.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Twinspin.PubSub, "reconciliation_jobs")
      Phoenix.PubSub.subscribe(Twinspin.PubSub, "reconciliation_runs:#{id}")
    end

    job = get_job!(id)

    {:ok,
     socket
     |> assign(:page_title, job.name)
     |> assign(:job, job)
     |> assign(:runs_empty?, job.reconciliation_runs == [])
     |> stream(:runs, job.reconciliation_runs)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, socket.assigns.job.name)
  end

  @impl true
  def handle_event("start_run", _params, socket) do
    job = socket.assigns.job

    case create_run(job.id) do
      {:ok, run} ->
        Phoenix.PubSub.broadcast(
          Twinspin.PubSub,
          "reconciliation_runs:#{job.id}",
          {:run_created, run}
        )

        {:noreply,
         socket
         |> assign(:runs_empty?, false)
         |> put_flash(:info, "Run started successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to start run")}
    end
  end

  @impl true
  def handle_event("delete_run", %{"id" => id}, socket) do
    run = Repo.get!(Run, id)
    {:ok, _} = Repo.delete(run)

    Phoenix.PubSub.broadcast(
      Twinspin.PubSub,
      "reconciliation_runs:#{socket.assigns.job.id}",
      {:run_deleted, run}
    )

    {:noreply, put_flash(socket, :info, "Run deleted successfully")}
  end

  @impl true
  def handle_event("show_discrepancies", %{"partition_id" => partition_id}, socket) do
    partition = Repo.get!(Partition, partition_id)
    partition_with_discrepancies = Repo.preload(partition, :discrepancy_results)

    {:noreply,
     socket
     |> assign(:selected_partition, partition_with_discrepancies)
     |> assign(:show_discrepancy_modal, true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_discrepancy_modal, false)}
  end

  @impl true
  def handle_info({:run_created, run}, socket) do
    {:noreply,
     socket
     |> assign(:runs_empty?, false)
     |> stream_insert(:runs, run, at: 0)}
  end

  @impl true
  def handle_info({:run_updated, run}, socket) do
    {:noreply, stream_insert(socket, :runs, run)}
  end

  @impl true
  def handle_info({:run_deleted, run}, socket) do
    {:noreply, stream_delete(socket, :runs, run)}
  end

  @impl true
  def handle_info({:job_updated, job}, socket) do
    if job.id == socket.assigns.job.id do
      updated_job = get_job!(job.id)
      {:noreply, assign(socket, :job, updated_job)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:job_deleted, _job}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Job was deleted")
     |> push_navigate(to: ~p"/")}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp get_job!(id) do
    job =
      Job
      |> Repo.get!(id)
      |> Repo.preload([
        :source_database_connection,
        :target_database_connection,
        :table_reconciliations,
        reconciliation_runs: from(r in Run, order_by: [desc: r.inserted_at])
      ])

    # Manually preload nested partitions with Repo.preload for deeper nesting
    runs_with_partitions =
      Enum.map(job.reconciliation_runs, fn run ->
        # Get root partitions
        root_partitions =
          Partition
          |> where([p], p.reconciliation_run_id == ^run.id and is_nil(p.parent_partition_id))
          |> order_by([p], asc: p.partition_key)
          |> Repo.all()
          |> Repo.preload(:discrepancy_results)

        # Load children for each root
        partitions_with_children =
          Enum.map(root_partitions, fn root ->
            children =
              Partition
              |> where([p], p.parent_partition_id == ^root.id)
              |> order_by([p], asc: p.partition_key)
              |> Repo.all()
              |> Repo.preload(:discrepancy_results)

            # Load grandchildren for each child
            children_with_grandchildren =
              Enum.map(children, fn child ->
                grandchildren =
                  Partition
                  |> where([p], p.parent_partition_id == ^child.id)
                  |> order_by([p], asc: p.partition_key)
                  |> Repo.all()
                  |> Repo.preload(:discrepancy_results)

                Map.put(child, :child_partitions, grandchildren)
              end)

            Map.put(root, :child_partitions, children_with_grandchildren)
          end)

        Map.put(run, :partitions, partitions_with_children)
      end)

    Map.put(job, :reconciliation_runs, runs_with_partitions)
  end

  defp create_run(job_id) do
    %Run{}
    |> Run.changeset(%{
      reconciliation_job_id: job_id,
      status: "pending",
      started_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert()
  end

  defp format_timestamp(nil), do: "—"

  defp format_timestamp(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end

  defp format_duration(nil, nil), do: "—"
  defp format_duration(_started, nil), do: "Running..."

  defp format_duration(started_at, completed_at) do
    diff = DateTime.diff(completed_at, started_at, :second)

    cond do
      diff < 60 -> "#{diff}s"
      diff < 3600 -> "#{div(diff, 60)}m #{rem(diff, 60)}s"
      true -> "#{div(diff, 3600)}h #{div(rem(diff, 3600), 60)}m"
    end
  end

  defp status_badge_class("pending"), do: "bg-gray-900 text-gray-300"
  defp status_badge_class("running"), do: "bg-blue-900 text-blue-300"
  defp status_badge_class("completed"), do: "bg-emerald-900 text-emerald-300"
  defp status_badge_class("failed"), do: "bg-red-900 text-red-300"
  defp status_badge_class(_), do: "bg-gray-900 text-gray-300"

  defp progress_percentage(0, _), do: 0

  defp progress_percentage(processed, total) do
    Float.round(processed / total * 100, 1)
  end
end
