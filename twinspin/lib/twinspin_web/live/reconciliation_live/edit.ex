defmodule TwinspinWeb.ReconciliationLive.Edit do
  use TwinspinWeb, :live_view
  alias Twinspin.Repo
  alias Twinspin.Reconciliation.{Job, TableReconciliation, DatabaseConnection}
  import Ecto.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Twinspin.PubSub, "reconciliation_jobs")
    end

    job = get_job!(id)
    connections = list_connections()

    {:ok,
     socket
     |> assign(:page_title, "Edit Job")
     |> assign(:job, job)
     |> assign(:connections, connections)
     |> assign(:job_form, to_form(Job.changeset(job, %{})))
     |> assign(:show_add_table, false)
     |> assign(:editing_table_id, nil)
     |> assign(
       :table_form,
       to_form(TableReconciliation.changeset(%TableReconciliation{}, %{}))
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, _params) do
    socket
    |> assign(:page_title, "Edit Job")
  end

  @impl true
  def handle_event("validate_job", %{"job" => job_params}, socket) do
    changeset =
      socket.assigns.job
      |> Job.changeset(job_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :job_form, to_form(changeset))}
  end

  @impl true
  def handle_event("save_job", %{"job" => job_params}, socket) do
    case update_job(socket.assigns.job, job_params) do
      {:ok, job} ->
        Phoenix.PubSub.broadcast(
          Twinspin.PubSub,
          "reconciliation_jobs",
          {:job_updated, job}
        )

        {:noreply,
         socket
         |> assign(:job, get_job!(job.id))
         |> assign(:job_form, to_form(Job.changeset(job, %{})))
         |> put_flash(:info, "Job updated successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :job_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("toggle_add_table", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_table, !socket.assigns.show_add_table)
     |> assign(:editing_table_id, nil)
     |> assign(
       :table_form,
       to_form(TableReconciliation.changeset(%TableReconciliation{}, %{}))
     )}
  end

  @impl true
  def handle_event("edit_table", %{"id" => id}, socket) do
    table = Repo.get!(TableReconciliation, id)
    changeset = TableReconciliation.changeset(table, %{})

    {:noreply,
     socket
     |> assign(:show_add_table, true)
     |> assign(:editing_table_id, String.to_integer(id))
     |> assign(:table_form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate_table", %{"table_reconciliation" => table_params}, socket) do
    table =
      if socket.assigns.editing_table_id do
        Repo.get!(TableReconciliation, socket.assigns.editing_table_id)
      else
        %TableReconciliation{}
      end

    changeset =
      table
      |> TableReconciliation.changeset(table_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :table_form, to_form(changeset))}
  end

  @impl true
  def handle_event("save_table", %{"table_reconciliation" => table_params}, socket) do
    table_params = Map.put(table_params, "reconciliation_job_id", socket.assigns.job.id)

    result =
      if socket.assigns.editing_table_id do
        table = Repo.get!(TableReconciliation, socket.assigns.editing_table_id)
        update_table(table, table_params)
      else
        create_table(table_params)
      end

    case result do
      {:ok, _table} ->
        {:noreply,
         socket
         |> assign(:job, get_job!(socket.assigns.job.id))
         |> assign(:show_add_table, false)
         |> assign(:editing_table_id, nil)
         |> assign(
           :table_form,
           to_form(TableReconciliation.changeset(%TableReconciliation{}, %{}))
         )
         |> put_flash(:info, "Table reconciliation saved successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :table_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete_table", %{"id" => id}, socket) do
    table = Repo.get!(TableReconciliation, id)
    {:ok, _} = Repo.delete(table)

    {:noreply,
     socket
     |> assign(:job, get_job!(socket.assigns.job.id))
     |> put_flash(:info, "Table reconciliation deleted successfully")}
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
        :table_reconciliations
      ])

    job
  end

  defp list_connections do
    DatabaseConnection
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  defp update_job(job, attrs) do
    job
    |> Job.changeset(attrs)
    |> Repo.update()
  end

  defp create_table(attrs) do
    %TableReconciliation{}
    |> TableReconciliation.changeset(attrs)
    |> Repo.insert()
  end

  defp update_table(table, attrs) do
    table
    |> TableReconciliation.changeset(attrs)
    |> Repo.update()
  end

  defp db_type_badge_class("db2"), do: "bg-blue-900 text-blue-300"
  defp db_type_badge_class("oracle"), do: "bg-red-900 text-red-300"
  defp db_type_badge_class("postgres"), do: "bg-cyan-900 text-cyan-300"
  defp db_type_badge_class("mysql"), do: "bg-orange-900 text-orange-300"
  defp db_type_badge_class(_), do: "bg-gray-900 text-gray-300"
end
