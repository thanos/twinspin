defmodule TwinspinWeb.DatabaseConnectionLive.Index do
  use TwinspinWeb, :live_view
  alias Twinspin.Repo
  alias Twinspin.Reconciliation.DatabaseConnection
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Twinspin.PubSub, "database_connections")
    end

    connections = list_connections()

    {:ok,
     socket
     |> assign(:page_title, "Database Connections")
     |> assign(:connections_empty?, connections == [])
     |> assign(:show_form, false)
     |> assign(:editing_connection_id, nil)
     |> assign(
       :connection_form,
       to_form(DatabaseConnection.changeset(%DatabaseConnection{}, %{}))
     )
     |> stream(:connections, connections)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Database Connections")
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, !socket.assigns.show_form)
     |> assign(:editing_connection_id, nil)
     |> assign(
       :connection_form,
       to_form(DatabaseConnection.changeset(%DatabaseConnection{}, %{}))
     )}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    connection = Repo.get!(DatabaseConnection, id)
    changeset = DatabaseConnection.changeset(connection, %{})

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_connection_id, String.to_integer(id))
     |> assign(:connection_form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"database_connection" => connection_params}, socket) do
    connection =
      if socket.assigns.editing_connection_id do
        Repo.get!(DatabaseConnection, socket.assigns.editing_connection_id)
      else
        %DatabaseConnection{}
      end

    changeset =
      connection
      |> DatabaseConnection.changeset(connection_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :connection_form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"database_connection" => connection_params}, socket) do
    result =
      if socket.assigns.editing_connection_id do
        connection = Repo.get!(DatabaseConnection, socket.assigns.editing_connection_id)
        update_connection(connection, connection_params)
      else
        create_connection(connection_params)
      end

    case result do
      {:ok, connection} ->
        action = if socket.assigns.editing_connection_id, do: :updated, else: :created

        Phoenix.PubSub.broadcast(
          Twinspin.PubSub,
          "database_connections",
          {:connection_updated, connection}
        )

        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:editing_connection_id, nil)
         |> assign(
           :connection_form,
           to_form(DatabaseConnection.changeset(%DatabaseConnection{}, %{}))
         )
         |> put_flash(:info, "Connection #{action} successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :connection_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    connection = Repo.get!(DatabaseConnection, id)

    case Repo.delete(connection) do
      {:ok, _} ->
        Phoenix.PubSub.broadcast(
          Twinspin.PubSub,
          "database_connections",
          {:connection_deleted, connection}
        )

        {:noreply, put_flash(socket, :info, "Connection deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Cannot delete connection - it's in use by jobs")}
    end
  end

  @impl true
  def handle_info({:connection_updated, connection}, socket) do
    {:noreply,
     socket
     |> assign(:connections_empty?, false)
     |> stream_insert(:connections, connection)}
  end

  @impl true
  def handle_info({:connection_deleted, connection}, socket) do
    {:noreply, stream_delete(socket, :connections, connection)}
  end

  defp list_connections do
    DatabaseConnection
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  defp create_connection(attrs) do
    %DatabaseConnection{}
    |> DatabaseConnection.changeset(attrs)
    |> Repo.insert()
  end

  defp update_connection(connection, attrs) do
    connection
    |> DatabaseConnection.changeset(attrs)
    |> Repo.update()
  end

  defp db_type_badge_class("db2"), do: "bg-blue-900 text-blue-300"
  defp db_type_badge_class("oracle"), do: "bg-red-900 text-red-300"
  defp db_type_badge_class("postgres"), do: "bg-cyan-900 text-cyan-300"
  defp db_type_badge_class("mysql"), do: "bg-orange-900 text-orange-300"
  defp db_type_badge_class(_), do: "bg-gray-900 text-gray-300"
end
