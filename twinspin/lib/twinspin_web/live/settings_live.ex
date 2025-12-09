defmodule TwinspinWeb.SettingsLive do
  use TwinspinWeb, :live_view
  alias Twinspin.Settings

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.get_settings()
    changeset = Twinspin.Settings.Settings.changeset(settings, %{})

    {:ok,
     socket
     |> assign(:settings, settings)
     |> assign(:form, to_form(changeset))
     |> assign(:page_title, "Settings")}
  end

  @impl true
  def handle_event("validate", %{"settings" => settings_params}, socket) do
    changeset =
      socket.assigns.settings
      |> Twinspin.Settings.Settings.changeset(settings_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"settings" => settings_params}, socket) do
    case Settings.update_settings(settings_params) do
      {:ok, settings} ->
        {:noreply,
         socket
         |> put_flash(:info, "Settings updated successfully")
         |> assign(:settings, settings)
         |> assign(:form, to_form(Twinspin.Settings.Settings.changeset(settings, %{})))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
