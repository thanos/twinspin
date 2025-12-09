defmodule Twinspin.Reconciliation.Run do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reconciliation_runs" do
    field :status, :string, default: "pending"
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :total_rows, :integer, default: 0
    field :processed_rows, :integer, default: 0
    field :discrepancies_found, :integer, default: 0
    field :error_message, :string

    belongs_to :reconciliation_job, Twinspin.Reconciliation.Job

    has_many :partitions, Twinspin.Reconciliation.Partition, foreign_key: :reconciliation_run_id

    timestamps()
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :status,
      :started_at,
      :completed_at,
      :total_rows,
      :processed_rows,
      :discrepancies_found,
      :error_message,
      :reconciliation_job_id
    ])
    |> validate_required([:status, :reconciliation_job_id])
    |> validate_inclusion(:status, ["pending", "running", "completed", "failed"])
    |> foreign_key_constraint(:reconciliation_job_id)
  end
end
