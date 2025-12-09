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
alias Twinspin.Reconciliation.{DatabaseConnection, Job, TableReconciliation, Run}

# Clear existing data
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
Repo.insert!(%TableReconciliation{
  reconciliation_job_id: job.id,
  table_name: "customers",
  columns: %{
    "primary_key" => ["customer_id"],
    "compare_columns" => ["email", "first_name", "last_name", "phone", "updated_at"]
  }
})

Repo.insert!(%TableReconciliation{
  reconciliation_job_id: job.id,
  table_name: "orders",
  columns: %{
    "primary_key" => ["order_id"],
    "compare_columns" => ["customer_id", "total_amount", "status", "created_at"]
  }
})

# Create a completed run
Repo.insert!(%Run{
  reconciliation_job_id: job.id,
  status: "completed",
  started_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-3600, :second),
  completed_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-1800, :second),
  total_rows: 125_000,
  processed_rows: 125_000,
  discrepancies_found: 47
})

IO.puts("✓ Seeded 3 database connections")
IO.puts("✓ Seeded 1 reconciliation job with 2 table reconciliations")
IO.puts("✓ Seeded 1 completed run")
