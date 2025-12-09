defmodule Twinspin.Reconciliation.DiscrepancyResult do
  use Ecto.Schema
  import Ecto.Changeset

  schema "discrepancy_results" do
    field :discrepancy_type, :string
    field :row_identifier, :map
    field :field_diffs, :map

    field :source_value, :string
    field :target_value, :string

    belongs_to :partition, Twinspin.Reconciliation.Partition

    timestamps()
  end

  @doc false
  def changeset(discrepancy_result, attrs) do
    discrepancy_result
    |> cast(attrs, [
      :discrepancy_type,
      :row_identifier,
      :field_diffs,
      :source_value,
      :target_value,
      :partition_id
    ])
    |> validate_required([
      :discrepancy_type,
      :row_identifier,
      :partition_id
    ])
    |> validate_inclusion(:discrepancy_type, [
      "missing_source",
      "missing_target",
      "value_mismatch"
    ])
  end
end
