defmodule Twinspin.Repo.Migrations.AddObanPeersTable do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:oban_peers, primary_key: false) do
      add :name, :text, null: false, primary_key: true
      add :node, :text, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec, null: false
    end
  end

  def down do
    drop_if_exists table(:oban_peers)
  end
end
