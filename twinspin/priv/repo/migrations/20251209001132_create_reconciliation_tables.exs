defmodule Twinspin.Repo.Migrations.CreateReconciliationTables do
  use Ecto.Migration

  def change do
    create table(:reconciliation_jobs) do
      add :source_db_type, :string, null: false
      add :source_connection_string, :text, null: false
      add :source_table, :string, null: false
      add :source_columns, :text

      add :target_db_type, :string, null: false
      add :target_connection_string, :text, null: false
      add :target_table, :string, null: false
      add :target_columns, :text

      add :partition_row_threshold, :integer, default: 1_000_000
      add :partition_max_depth, :integer, default: 10

      add :status, :string, default: "pending", null: false
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      add :total_rows, :bigint
      add :processed_rows, :bigint, default: 0
      add :discrepancies_found, :integer, default: 0

      add :error_message, :text

      timestamps()
    end

    create index(:reconciliation_jobs, [:status])
    create index(:reconciliation_jobs, [:started_at])

    create table(:partitions) do
      add :reconciliation_job_id, references(:reconciliation_jobs, on_delete: :delete_all),
        null: false

      add :parent_partition_id, references(:partitions, on_delete: :delete_all)

      add :partition_key_start, :string, null: false
      add :partition_key_end, :string, null: false
      add :depth, :integer, default: 0, null: false

      add :status, :string, default: "pending", null: false
      add :row_count_estimate, :bigint
      add :processed_rows, :bigint, default: 0
      add :discrepancies_found, :integer, default: 0

      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      add :error_message, :text

      timestamps()
    end

    create index(:partitions, [:reconciliation_job_id])
    create index(:partitions, [:parent_partition_id])
    create index(:partitions, [:status])
    create index(:partitions, [:depth])

    create table(:discrepancy_results) do
      add :partition_id, references(:partitions, on_delete: :delete_all), null: false

      add :discrepancy_type, :string, null: false
      add :row_identifier, :map, null: false
      add :field_diffs, :map

      add :source_value, :text
      add :target_value, :text

      timestamps()
    end

    create index(:discrepancy_results, [:partition_id])
    create index(:discrepancy_results, [:discrepancy_type])
  end
end
