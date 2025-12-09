defmodule TwinspinWeb.ReconciliationLive.Index do
  use TwinspinWeb, :live_view
  alias Twinspin.Repo
  alias Twinspin.Reconciliation.Job
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Twinspin.PubSub, "reconciliation_jobs")
    end

    jobs = list_jobs()

    {:ok,
     socket
     |> assign(:page_title, "Reconciliation Dashboard")
     |> assign(:jobs_empty?, jobs == [])
     |> assign(:show_form, false)
     |> assign(:job_form, to_form(Job.changeset(%Job{}, %{})))
     |> stream(:jobs, jobs)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Reconciliation Dashboard")
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, :show_form, !socket.assigns.show_form)}
  end

  @impl true
  def handle_event("validate", %{"job" => job_params}, socket) do
    changeset =
      %Job{}
      |> Job.changeset(job_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :job_form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"job" => job_params}, socket) do
    case create_job(job_params) do
      {:ok, job} ->
        Phoenix.PubSub.broadcast(
          Twinspin.PubSub,
          "reconciliation_jobs",
          {:job_created, job}
        )

        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:job_form, to_form(Job.changeset(%Job{}, %{})))
         |> put_flash(:info, "Job created successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :job_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    job = Repo.get!(Job, id)
    {:ok, _} = Repo.delete(job)

    Phoenix.PubSub.broadcast(Twinspin.PubSub, "reconciliation_jobs", {:job_deleted, job})

    {:noreply, put_flash(socket, :info, "Job deleted successfully")}
  end

  @impl true
  def handle_info({:job_created, job}, socket) do
    {:noreply,
     socket
     |> assign(:jobs_empty?, false)
     |> stream_insert(:jobs, job, at: 0)}
  end

  @impl true
  def handle_info({:job_updated, job}, socket) do
    {:noreply, stream_insert(socket, :jobs, job)}
  end

  @impl true
  def handle_info({:job_deleted, job}, socket) do
    {:noreply, stream_delete(socket, :jobs, job)}
  end

  defp list_jobs do
    jobs =
      Job
      |> order_by([j], desc: j.inserted_at)
      |> Repo.all()

    Repo.preload(jobs, [
      :source_database_connection,
      :target_database_connection,
      reconciliation_runs:
        from(r in Twinspin.Reconciliation.Run,
          order_by: [desc: r.inserted_at],
          limit: 1
        )
    ])
  end

  defp create_job(attrs) do
    %Job{}
    |> Job.changeset(attrs)
    |> Repo.insert()
  end

  defp job_metrics(jobs) do
    Enum.reduce(jobs, %{total: 0, running: 0, completed: 0, failed: 0}, fn {_id, job}, acc ->
      %{
        total: acc.total + 1,
        running: acc.running + if(job.status == "running", do: 1, else: 0),
        completed: acc.completed + if(job.status == "completed", do: 1, else: 0),
        failed: acc.failed + if(job.status == "failed", do: 1, else: 0)
      }
    end)
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

  defp status_badge_class("pending"), do: "bg-gray-900 text-gray-300"
  defp status_badge_class("running"), do: "bg-blue-900 text-blue-300"
  defp status_badge_class("completed"), do: "bg-emerald-900 text-emerald-300"
  defp status_badge_class("failed"), do: "bg-red-900 text-red-300"
  defp status_badge_class(_), do: "bg-gray-900 text-gray-300"

  defp progress_bar_class("pending"), do: "bg-gray-500"
  defp progress_bar_class("running"), do: "bg-blue-500"
  defp progress_bar_class("completed"), do: "bg-emerald-500"
  defp progress_bar_class("failed"), do: "bg-red-500"
  defp progress_bar_class(_), do: "bg-gray-500"
end
