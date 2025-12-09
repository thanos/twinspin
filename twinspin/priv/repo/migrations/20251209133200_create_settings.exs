defmodule Twinspin.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :brand_name, :string, null: false, default: "TwinSpin"

      timestamps(type: :utc_datetime)
    end

    # Ensure only one settings row exists
    create constraint(:settings, :singleton_settings, check: "id = 1")

    # Insert default settings row
    execute "INSERT INTO settings (id, brand_name, inserted_at, updated_at) VALUES (1, 'TwinSpin', NOW(), NOW())"
  end
end
