defmodule Twinspin.TestHelpers do
  @moduledoc """
  Test helper functions for creating test data and common assertions.
  """
  alias Twinspin.Repo
  alias Twinspin.DatabaseConnections.Connection
  alias Twinspin.Reconciliation.{Job, Run, TableReconciliation, Partition, DiscrepancyResult}

  @doc """
  Creates a test database connection with given attributes.
  """
  def create_connection(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Connection",
      db_type: "postgresql",
      host: "localhost",
      port: 5432,
      database: "test_db",
      username: "test_user",
      password: "test_pass"
    }

    attrs = Map.merge(default_attrs, Enum.into(attrs, %{}))

    %Connection{}
    |> Connection.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Creates a test reconciliation job with given attributes.
  """
  def create_job(attrs \\ %{}) do
    source_conn = attrs[:source_connection] || create_connection(%{name: "Source DB"})
    target_conn = attrs[:target_connection] || create_connection(%{name: "Target DB"})

    default_attrs = %{
      name: "Test Job",
      description: "Test reconciliation job",
      source_database_connection_id: source_conn.id,
      target_database_connection_id: target_conn.id,
      partition_row_threshold: 1000,
      partition_max_depth: 3
    }

    attrs = Map.merge(default_attrs, Enum.into(attrs, %{}))
    attrs = Map.drop(attrs, [:source_connection, :target_connection])

    %Job{}
    |> Job.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Creates a test table reconciliation for a job.
  """
  def create_table_reconciliation(job, attrs \\ %{}) do
    default_attrs = %{
      table_name: "test_table",
      columns: %{
        "primary_key" => ["id"],
        "compare_columns" => ["name", "email", "updated_at"]
      }
    }

    attrs = Map.merge(default_attrs, Enum.into(attrs, %{}))

    %TableReconciliation{}
    |> TableReconciliation.changeset(Map.put(attrs, :reconciliation_job_id, job.id))
    |> Repo.insert!()
  end

  @doc """
  Creates a test reconciliation run for a job.
  """
  def create_run(job, attrs \\ %{}) do
    default_attrs = %{
      reconciliation_job_id: job.id,
      status: "pending",
      started_at: DateTime.utc_now() |> DateTime.truncate(:second),
      total_rows: 0,
      processed_rows: 0,
      discrepancies_found: 0
    }

    attrs = Map.merge(default_attrs, Enum.into(attrs, %{}))

    %Run{}
    |> Run.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Creates a test partition for a run.
  """
  def create_partition(run, table_rec, attrs \\ %{}) do
    default_attrs = %{
      reconciliation_run_id: run.id,
      table_reconciliation_id: table_rec.id,
      partition_key: "0-100",
      depth: 0,
      status: "pending",
      row_count_estimate: 100
    }

    attrs = Map.merge(default_attrs, Enum.into(attrs, %{}))

    %Partition{}
    |> Partition.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Creates a test discrepancy result for a partition.
  """
  def create_discrepancy(partition, attrs \\ %{}) do
    default_attrs = %{
      partition_id: partition.id,
      discrepancy_type: "field_mismatch",
      row_identifier: %{"id" => 123},
      field_diffs: %{
        "email" => %{
          "source" => "old@example.com",
          "target" => "new@example.com"
        }
      }
    }

    attrs = Map.merge(default_attrs, Enum.into(attrs, %{}))

    %DiscrepancyResult{}
    |> DiscrepancyResult.changeset(attrs)
    |> Repo.insert!()
  end
end
