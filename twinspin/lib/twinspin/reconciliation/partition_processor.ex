defmodule Twinspin.Reconciliation.PartitionProcessor do
  @moduledoc """
  Handles reconciliation of individual partitions.
  Compares source and target data within a partition range,
  detects discrepancies, and records them.
  """

  require Logger
  alias Twinspin.Repo

  alias Twinspin.Reconciliation.{
    Partition,
    TableReconciliation,
    DatabaseConnection,
    DiscrepancyResult
  }

  @doc """
  Reconciles a single partition by comparing source and target data.
  Returns a list of discrepancy results that were inserted.
  """
  def reconcile(partition, table_rec, source_conn, target_conn) do
    Logger.debug(
      "Reconciling partition #{partition.partition_key} for table #{table_rec.table_name}"
    )

    # Fetch data from source and target within partition range
    source_data = fetch_partition_data(source_conn, table_rec, partition.partition_key)
    target_data = fetch_partition_data(target_conn, table_rec, partition.partition_key)

    # Build maps keyed by primary key for efficient comparison
    source_map = build_key_map(source_data, table_rec.columns["primary_key"])
    target_map = build_key_map(target_data, table_rec.columns["primary_key"])

    # Find discrepancies
    discrepancies = []

    # Check for missing in target and field mismatches
    discrepancies =
      Enum.reduce(source_map, discrepancies, fn {key, source_row}, acc ->
        case Map.get(target_map, key) do
          nil ->
            # Missing in target
            [create_missing_target_discrepancy(partition, key, source_row) | acc]

          target_row ->
            # Compare fields
            case compare_rows(source_row, target_row, table_rec.columns["compare_columns"]) do
              {:ok, _} ->
                acc

              {:mismatch, diffs} ->
                [create_field_mismatch_discrepancy(partition, key, diffs) | acc]
            end
        end
      end)

    # Check for missing in source
    discrepancies =
      Enum.reduce(target_map, discrepancies, fn {key, target_row}, acc ->
        case Map.get(source_map, key) do
          nil -> [create_missing_source_discrepancy(partition, key, target_row) | acc]
          _ -> acc
        end
      end)

    Logger.debug(
      "Found #{length(discrepancies)} discrepancies in partition #{partition.partition_key}"
    )

    discrepancies
  end

  # Private Functions

  defp fetch_partition_data(conn, table_rec, partition_key) do
    # Stub implementation - returns sample data for demo
    # In production, this would query the actual database using the connection
    [start_key, end_key] = String.split(partition_key, "-")

    # Generate sample rows based on partition key range
    sample_count = :rand.uniform(10)

    Enum.map(1..sample_count, fn i ->
      primary_key = table_rec.columns["primary_key"] |> hd()

      # Generate a key within the partition range
      key_value = "#{start_key}#{String.pad_leading(Integer.to_string(i), 4, "0")}"

      # Build sample row
      %{
        primary_key => key_value,
        "email" => "user#{i}@example.com",
        "first_name" => "User#{i}",
        "last_name" => "LastName#{i}",
        "phone" => "555-#{String.pad_leading(Integer.to_string(i * 1000), 4, "0")}",
        "updated_at" => DateTime.utc_now()
      }
    end)
  end

  defp build_key_map(rows, primary_key_columns) do
    Enum.into(rows, %{}, fn row ->
      # Build composite key from primary key columns
      key = build_composite_key(row, primary_key_columns)
      {key, row}
    end)
  end

  defp build_composite_key(row, primary_key_columns) do
    primary_key_columns
    |> Enum.map(fn col -> Map.get(row, col) end)
    |> Enum.join(":")
  end

  defp compare_rows(source_row, target_row, compare_columns) do
    diffs =
      Enum.reduce(compare_columns, %{}, fn col, acc ->
        source_val = Map.get(source_row, col)
        target_val = Map.get(target_row, col)

        if source_val != target_val do
          Map.put(acc, col, %{"source" => source_val, "target" => target_val})
        else
          acc
        end
      end)

    if map_size(diffs) == 0 do
      {:ok, :match}
    else
      {:mismatch, diffs}
    end
  end

  defp create_missing_target_discrepancy(partition, key, _source_row) do
    attrs = %{
      partition_id: partition.id,
      discrepancy_type: "missing_in_target",
      row_identifier: build_row_identifier(key),
      field_diffs: nil
    }

    {:ok, result} =
      %DiscrepancyResult{}
      |> DiscrepancyResult.changeset(attrs)
      |> Repo.insert()

    result
  end

  defp create_missing_source_discrepancy(partition, key, _target_row) do
    attrs = %{
      partition_id: partition.id,
      discrepancy_type: "missing_in_source",
      row_identifier: build_row_identifier(key),
      field_diffs: nil
    }

    {:ok, result} =
      %DiscrepancyResult{}
      |> DiscrepancyResult.changeset(attrs)
      |> Repo.insert()

    result
  end

  defp create_field_mismatch_discrepancy(partition, key, diffs) do
    attrs = %{
      partition_id: partition.id,
      discrepancy_type: "field_mismatch",
      row_identifier: build_row_identifier(key),
      field_diffs: diffs
    }

    {:ok, result} =
      %DiscrepancyResult{}
      |> DiscrepancyResult.changeset(attrs)
      |> Repo.insert()

    result
  end

  defp build_row_identifier(key) do
    # Parse composite key back to map
    # For single key, just use the value
    # For composite, split and build map
    %{"key" => key}
  end
end
