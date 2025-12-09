defmodule Twinspin.Settings.Settings do
  use Ecto.Schema
  import Ecto.Changeset

  schema "settings" do
    field :brand_name, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:brand_name])
    |> validate_required([:brand_name])
    |> validate_length(:brand_name, min: 1, max: 100)
  end
end
