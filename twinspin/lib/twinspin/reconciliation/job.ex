defmodule Twinspin.Reconciliation.Job do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reconciliation_jobs" do
    field :name, :string
    field :description, :string
    field :partition_row_threshold, :integer, default: 100_000
    field :partition_max_depth, :integer, default: 10

    belongs_to :source_database_connection, Twinspin.Reconciliation.DatabaseConnection
    belongs_to :target_database_connection, Twinspin.Reconciliation.DatabaseConnection

    has_many :table_reconciliations, Twinspin.Reconciliation.TableReconciliation,
      foreign_key: :reconciliation_job_id

    has_many :reconciliation_runs, Twinspin.Reconciliation.Run,
      foreign_key: :reconciliation_job_id

    timestamps()
  end

  @doc false
  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :name,
      :description,
      :source_database_connection_id,
      :target_database_connection_id,
      :partition_row_threshold,
      :partition_max_depth
    ])
    |> validate_required([
      :name,
      :source_database_connection_id,
      :target_database_connection_id
    ])
    |> validate_number(:partition_row_threshold, greater_than: 0)
    |> validate_number(:partition_max_depth, greater_than: 0)
    |> foreign_key_constraint(:source_database_connection_id)
    |> foreign_key_constraint(:target_database_connection_id)
  end
end
