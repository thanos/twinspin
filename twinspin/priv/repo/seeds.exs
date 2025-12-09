# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Twinspin.Repo.insert!(%Twinspin.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Twinspin.Repo

alias Twinspin.Reconciliation.{
  DatabaseConnection,
  Job,
  TableReconciliation,
  Run,
  Partition,
  DiscrepancyResult
}

# Clear existing data
Repo.delete_all(DiscrepancyResult)
Repo.delete_all(Partition)
Repo.delete_all(Run)
Repo.delete_all(TableReconciliation)
Repo.delete_all(Job)
Repo.delete_all(DatabaseConnection)

# Create database connections
source_db =
  Repo.insert!(%DatabaseConnection{
    name: "Production DB2",
    db_type: "db2",
    connection_string:
      "DATABASE=PRODDB;HOSTNAME=db2-prod.example.com;PORT=50000;UID=db2admin;PWD=***",
    description: "Production DB2 database on mainframe"
  })

target_db =
  Repo.insert!(%DatabaseConnection{
    name: "Analytics PostgreSQL",
    db_type: "postgres",
    connection_string: "postgresql://postgres:postgres@analytics.example.com:5432/analytics_db",
    description: "PostgreSQL analytics warehouse"
  })

oracle_db =
  Repo.insert!(%DatabaseConnection{
    name: "Legacy Oracle",
    db_type: "oracle",
    connection_string:
      "Data Source=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=oracle.example.com)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=LEGACY)));User Id=admin;Password=***;",
    description: "Legacy Oracle system"
  })

# Create a reconciliation job
job =
  Repo.insert!(%Job{
    name: "Customer Data Reconciliation",
    description: "Reconcile customer records between DB2 and PostgreSQL",
    source_database_connection_id: source_db.id,
    target_database_connection_id: target_db.id,
    partition_row_threshold: 50_000,
    partition_max_depth: 8
  })

# Create table reconciliations for the job
customers_table =
  Repo.insert!(%TableReconciliation{
    reconciliation_job_id: job.id,
    table_name: "customers",
    columns: %{
      "primary_key" => ["customer_id"],
      "compare_columns" => ["email", "first_name", "last_name", "phone", "updated_at"]
    }
  })

orders_table =
  Repo.insert!(%TableReconciliation{
    reconciliation_job_id: job.id,
    table_name: "orders",
    columns: %{
      "primary_key" => ["order_id"],
      "compare_columns" => ["customer_id", "total_amount", "status", "created_at"]
    }
  })

# Create a completed run
run =
  Repo.insert!(%Run{
    reconciliation_job_id: job.id,
    status: "completed",
    started_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-3600, :second),
    completed_at:
      DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-1800, :second),
    total_rows: 125_000,
    processed_rows: 125_000,
    discrepancies_found: 47
  })

# Create partition tree for customers table
# Root partition
root_partition =
  Repo.insert!(%Partition{
    reconciliation_run_id: run.id,
    table_reconciliation_id: customers_table.id,
    partition_key: "0000-ZZZZ",
    depth: 0,
    status: "completed",
    row_count_estimate: 125_000
  })

# Level 1 partitions
partition_1a =
  Repo.insert!(%Partition{
    reconciliation_run_id: run.id,
    table_reconciliation_id: customers_table.id,
    parent_partition_id: root_partition.id,
    partition_key: "0000-MMMM",
    depth: 1,
    status: "completed",
    row_count_estimate: 62_500
  })

partition_1b =
  Repo.insert!(%Partition{
    reconciliation_run_id: run.id,
    table_reconciliation_id: customers_table.id,
    parent_partition_id: root_partition.id,
    partition_key: "MMMM-ZZZZ",
    depth: 1,
    status: "completed",
    row_count_estimate: 62_500
  })

# Level 2 partitions under 1a
partition_2a =
  Repo.insert!(%Partition{
    reconciliation_run_id: run.id,
    table_reconciliation_id: customers_table.id,
    parent_partition_id: partition_1a.id,
    partition_key: "0000-GGGG",
    depth: 2,
    status: "completed",
    row_count_estimate: 31_250
  })

partition_2b =
  Repo.insert!(%Partition{
    reconciliation_run_id: run.id,
    table_reconciliation_id: customers_table.id,
    parent_partition_id: partition_1a.id,
    partition_key: "GGGG-MMMM",
    depth: 2,
    status: "completed",
    row_count_estimate: 31_250
  })

# Level 2 partitions under 1b
partition_2c =
  Repo.insert!(%Partition{
    reconciliation_run_id: run.id,
    table_reconciliation_id: customers_table.id,
    parent_partition_id: partition_1b.id,
    partition_key: "MMMM-SSSS",
    depth: 2,
    status: "completed",
    row_count_estimate: 31_250
  })

partition_2d =
  Repo.insert!(%Partition{
    reconciliation_run_id: run.id,
    table_reconciliation_id: customers_table.id,
    parent_partition_id: partition_1b.id,
    partition_key: "SSSS-ZZZZ",
    depth: 2,
    status: "completed",
    row_count_estimate: 31_250
  })

# Add some discrepancy results
Repo.insert!(%DiscrepancyResult{
  partition_id: partition_2a.id,
  discrepancy_type: "field_mismatch",
  row_identifier: %{"customer_id" => "12345"},
  field_diffs: %{
    "email" => %{"source" => "old@example.com", "target" => "new@example.com"},
    "phone" => %{"source" => "555-1234", "target" => "555-5678"}
  }
})

Repo.insert!(%DiscrepancyResult{
  partition_id: partition_2a.id,
  discrepancy_type: "missing_in_target",
  row_identifier: %{"customer_id" => "12346"},
  field_diffs: nil
})

Repo.insert!(%DiscrepancyResult{
  partition_id: partition_2d.id,
  discrepancy_type: "missing_in_source",
  row_identifier: %{"customer_id" => "98765"},
  field_diffs: nil
})

IO.puts("✓ Seeded 3 database connections")
IO.puts("✓ Seeded 1 reconciliation job with 2 table reconciliations")
IO.puts("✓ Seeded 1 completed run")
IO.puts("✓ Seeded partition tree with 7 partitions across 3 levels")
IO.puts("✓ Seeded 3 sample discrepancy results")
