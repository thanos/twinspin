defmodule Twinspin.Reconciliation.Partition do
  use Ecto.Schema
  import Ecto.Changeset

  schema "partitions" do
    field :partition_key, :string
    field :depth, :integer, default: 0
    field :status, :string, default: "pending"
    field :row_count_estimate, :integer

    belongs_to :reconciliation_run, Twinspin.Reconciliation.Run
    belongs_to :table_reconciliation, Twinspin.Reconciliation.TableReconciliation
    belongs_to :parent_partition, __MODULE__

    has_many :child_partitions, __MODULE__, foreign_key: :parent_partition_id
    has_many :discrepancy_results, Twinspin.Reconciliation.DiscrepancyResult

    timestamps()
  end

  @doc false
  def changeset(partition, attrs) do
    partition
    |> cast(attrs, [
      :partition_key,
      :depth,
      :status,
      :row_count_estimate,
      :reconciliation_run_id,
      :table_reconciliation_id,
      :parent_partition_id
    ])
    |> validate_required([:partition_key, :reconciliation_run_id, :table_reconciliation_id])
    |> validate_inclusion(:status, ["pending", "processing", "completed", "failed"])
    |> foreign_key_constraint(:reconciliation_run_id)
    |> foreign_key_constraint(:table_reconciliation_id)
    |> foreign_key_constraint(:parent_partition_id)
  end
end
