defmodule Twinspin.Reconciliation.Partition do
  use Ecto.Schema
  import Ecto.Changeset

  schema "partitions" do
    field :partition_key_start, :string
    field :partition_key_end, :string
    field :depth, :integer, default: 0

    field :status, :string, default: "pending"
    field :row_count_estimate, :integer
    field :processed_rows, :integer, default: 0
    field :discrepancies_found, :integer, default: 0

    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    field :error_message, :string

    belongs_to :reconciliation_job, Twinspin.Reconciliation.Job
    belongs_to :parent_partition, Twinspin.Reconciliation.Partition

    has_many :child_partitions, Twinspin.Reconciliation.Partition,
      foreign_key: :parent_partition_id

    has_many :discrepancy_results, Twinspin.Reconciliation.DiscrepancyResult

    timestamps()
  end

  @doc false
  def changeset(partition, attrs) do
    partition
    |> cast(attrs, [
      :partition_key_start,
      :partition_key_end,
      :depth,
      :status,
      :row_count_estimate,
      :processed_rows,
      :discrepancies_found,
      :started_at,
      :completed_at,
      :error_message,
      :reconciliation_job_id,
      :parent_partition_id
    ])
    |> validate_required([
      :partition_key_start,
      :partition_key_end,
      :reconciliation_job_id
    ])
    |> validate_inclusion(:status, ["pending", "running", "completed", "failed"])
    |> validate_number(:depth, greater_than_or_equal_to: 0)
  end
end
