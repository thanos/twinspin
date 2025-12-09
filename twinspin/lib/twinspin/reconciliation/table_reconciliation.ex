defmodule Twinspin.Reconciliation.TableReconciliation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "table_reconciliations" do
    field :table_name, :string
    field :columns, :map

    belongs_to :reconciliation_job, Twinspin.Reconciliation.Job

    has_many :partitions, Twinspin.Reconciliation.Partition, foreign_key: :table_reconciliation_id

    timestamps()
  end

  @doc false
  def changeset(table_reconciliation, attrs) do
    table_reconciliation
    |> cast(attrs, [:table_name, :columns, :reconciliation_job_id])
    |> validate_required([:table_name, :columns, :reconciliation_job_id])
    |> foreign_key_constraint(:reconciliation_job_id)
  end
end
