defmodule Twinspin.Reconciliation.Job do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reconciliation_jobs" do
    field :source_db_type, :string
    field :source_connection_string, :string
    field :source_table, :string
    field :source_columns, :string

    field :target_db_type, :string
    field :target_connection_string, :string
    field :target_table, :string
    field :target_columns, :string

    field :partition_row_threshold, :integer, default: 1_000_000
    field :partition_max_depth, :integer, default: 10

    field :status, :string, default: "pending"
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    field :total_rows, :integer
    field :processed_rows, :integer, default: 0
    field :discrepancies_found, :integer, default: 0

    field :error_message, :string

    has_many :partitions, Twinspin.Reconciliation.Partition, foreign_key: :reconciliation_job_id

    timestamps()
  end

  @doc false
  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :source_db_type,
      :source_connection_string,
      :source_table,
      :source_columns,
      :target_db_type,
      :target_connection_string,
      :target_table,
      :target_columns,
      :partition_row_threshold,
      :partition_max_depth,
      :status,
      :started_at,
      :completed_at,
      :total_rows,
      :processed_rows,
      :discrepancies_found,
      :error_message
    ])
    |> validate_required([
      :source_db_type,
      :source_connection_string,
      :source_table,
      :target_db_type,
      :target_connection_string,
      :target_table
    ])
    |> validate_inclusion(:source_db_type, ["db2", "oracle", "postgres", "mysql"])
    |> validate_inclusion(:target_db_type, ["db2", "oracle", "postgres", "mysql"])
    |> validate_inclusion(:status, ["pending", "running", "completed", "failed"])
  end
end
