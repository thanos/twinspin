defmodule Twinspin.Reconciliation.DatabaseConnection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "database_connections" do
    field :name, :string
    field :db_type, :string
    field :connection_string, :string
    field :description, :string

    has_many :source_jobs, Twinspin.Reconciliation.Job,
      foreign_key: :source_database_connection_id

    has_many :target_jobs, Twinspin.Reconciliation.Job,
      foreign_key: :target_database_connection_id

    timestamps()
  end

  @doc false
  def changeset(database_connection, attrs) do
    database_connection
    |> cast(attrs, [:name, :db_type, :connection_string, :description])
    |> validate_required([:name, :db_type, :connection_string])
    |> validate_inclusion(:db_type, ["db2", "oracle", "postgres", "mysql"])
    |> unique_constraint(:name)
  end
end
