defmodule Twinspin.Repo.Migrations.ReorganizeSchema do
  use Ecto.Migration

  def change do
    # Drop old tables
    drop_if_exists table(:discrepancy_results)
    drop_if_exists table(:partitions)
    drop_if_exists table(:reconciliation_jobs)

    # Create database_connections table
    create table(:database_connections) do
      add :name, :string, null: false
      add :db_type, :string, null: false
      add :connection_string, :text, null: false
      add :description, :text

      timestamps()
    end

    create unique_index(:database_connections, [:name])

    # Create reconciliation_jobs table
    create table(:reconciliation_jobs) do
      add :name, :string, null: false
      add :description, :text

      add :source_database_connection_id, references(:database_connections, on_delete: :restrict),
        null: false

      add :target_database_connection_id, references(:database_connections, on_delete: :restrict),
        null: false

      add :partition_row_threshold, :integer, default: 100_000
      add :partition_max_depth, :integer, default: 10

      timestamps()
    end

    create index(:reconciliation_jobs, [:source_database_connection_id])
    create index(:reconciliation_jobs, [:target_database_connection_id])

    # Create table_reconciliations table
    create table(:table_reconciliations) do
      add :reconciliation_job_id, references(:reconciliation_jobs, on_delete: :delete_all),
        null: false

      add :table_name, :string, null: false
      add :columns, :map, null: false

      timestamps()
    end

    create index(:table_reconciliations, [:reconciliation_job_id])

    # Create reconciliation_runs table
    create table(:reconciliation_runs) do
      add :reconciliation_job_id, references(:reconciliation_jobs, on_delete: :delete_all),
        null: false

      add :status, :string, null: false, default: "pending"
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :total_rows, :integer, default: 0
      add :processed_rows, :integer, default: 0
      add :discrepancies_found, :integer, default: 0
      add :error_message, :text

      timestamps()
    end

    create index(:reconciliation_runs, [:reconciliation_job_id])
    create index(:reconciliation_runs, [:status])

    # Create partitions table (now belongs to reconciliation_run)
    create table(:partitions) do
      add :reconciliation_run_id, references(:reconciliation_runs, on_delete: :delete_all),
        null: false

      add :table_reconciliation_id, references(:table_reconciliations, on_delete: :delete_all),
        null: false

      add :parent_partition_id, references(:partitions, on_delete: :delete_all)
      add :partition_key, :string, null: false
      add :depth, :integer, default: 0
      add :status, :string, null: false, default: "pending"
      add :row_count_estimate, :integer

      timestamps()
    end

    create index(:partitions, [:reconciliation_run_id])
    create index(:partitions, [:table_reconciliation_id])
    create index(:partitions, [:parent_partition_id])

    # Create discrepancy_results table
    create table(:discrepancy_results) do
      add :partition_id, references(:partitions, on_delete: :delete_all), null: false
      add :discrepancy_type, :string, null: false
      add :row_identifier, :map, null: false
      add :field_diffs, :map

      timestamps()
    end

    create index(:discrepancy_results, [:partition_id])
  end
end
