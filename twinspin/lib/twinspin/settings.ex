defmodule Twinspin.Settings do
  @moduledoc """
  The Settings context for managing application-wide configuration.
  """

  import Ecto.Query, warn: false
  alias Twinspin.Repo
  alias Twinspin.Settings.Settings

  @doc """
  Gets the singleton settings record.
  Creates it with defaults if it doesn't exist.
  """
  def get_settings do
    case Repo.get(Settings, 1) do
      nil ->
        %Settings{id: 1, brand_name: "TwinSpin"}
        |> Repo.insert!()

      settings ->
        settings
    end
  end

  @doc """
  Updates the settings.
  """
  def update_settings(attrs) do
    settings = get_settings()

    settings
    |> Settings.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets the current brand name.
  """
  def get_brand_name do
    get_settings().brand_name
  end
end
