defmodule TwinspinWeb.ReconciliationLive.ShowTest do
  use TwinspinWeb.ConnCase
  import Phoenix.LiveViewTest
  import Twinspin.TestHelpers

  describe "Show page" do
    test "displays job details", %{conn: conn} do
      source_conn = create_connection(%{name: "Source DB", db_type: "postgres"})	1
      target_conn = create_connection(%{name: "Target DB", db_type: "mysql"})

      job =
        create_job(%{
          name: "Customer Reconciliation",
          description: "Reconcile customer data",
          source_connection: source_conn,
          target_connection: target_conn,
          partition_row_threshold: 5000,
          partition_max_depth: 5
        })

      {:ok, _view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "Customer Reconciliation"
      assert html =~ "Reconcile customer data"
      assert html =~ "Source DB"
      assert html =~ "Target DB"
      assert html =~ "postgresql"
      assert html =~ "mysql"
      assert html =~ "5000"
      assert html =~ "5"
    end

    test "displays table reconciliations", %{conn: conn} do
      job = create_job(%{name: "Test Job"})

      create_table_reconciliation(job, %{
        table_name: "customers",
        columns: %{
          "primary_key" => ["id"],
          "compare_columns" => ["name", "email", "created_at"]
        }
      })

      {:ok, _view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "customers"
      assert html =~ "id"
      assert html =~ "name, email, created_at"
    end

    test "shows empty state when no tables configured", %{conn: conn} do
      job = create_job(%{name: "Test Job"})

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert has_element?(view, "p", "No tables configured")
    end

    test "displays reconciliation runs", %{conn: conn} do
      job = create_job(%{name: "Test Job"})

      create_run(job, %{
        status: "completed",
        total_rows: 5000,
        processed_rows: 5000,
        discrepancies_found: 10,
        started_at:
          DateTime.utc_now() |> DateTime.add(-7200, :second) |> DateTime.truncate(:second),
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      {:ok, _view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "completed"
      assert html =~ "5000"
      assert html =~ "10"
    end

    test "shows empty state when no runs exist", %{conn: conn} do
      job = create_job(%{name: "Test Job"})

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert has_element?(view, "h3", "No runs yet")
      assert has_element?(view, "p", "Start your first reconciliation run")
    end

    test "can start a new run", %{conn: conn} do
      job = create_job(%{name: "Test Job"})

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      view
      |> element("button[phx-click='start_run']")
      |> render_click()

      assert_receive {:run_created, _run}
    end

    test "can delete a run", %{conn: conn} do
      job = create_job(%{name: "Test Job"})
      run = create_run(job, %{status: "completed"})

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert has_element?(view, "#runs-#{run.id}")

      view
      |> element("button[phx-click='delete_run'][phx-value-id='#{run.id}']")
      |> render_click()

      refute has_element?(view, "#runs-#{run.id}")
    end

    test "displays partition tree", %{conn: conn} do
      job = create_job(%{name: "Test Job"})
      table_rec = create_table_reconciliation(job)
      run = create_run(job, %{status: "completed"})

      create_partition(run, table_rec, %{
        partition_key: "0-1000",
        depth: 0,
        status: "completed",
        row_count_estimate: 1000
      })

      {:ok, _view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "Partition Tree"
      assert html =~ "0-1000"
      assert html =~ "L0"
    end

    test "can open discrepancy modal", %{conn: conn} do
      job = create_job(%{name: "Test Job"})
      table_rec = create_table_reconciliation(job)
      run = create_run(job, %{status: "completed"})
      partition = create_partition(run, table_rec, %{partition_key: "0-100"})
      create_discrepancy(partition)

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      view
      |> element(
        "button[phx-click='show_discrepancies'][phx-value-partition_id='#{partition.id}']"
      )
      |> render_click()

      assert has_element?(view, "h3", "Discrepancies in Partition")
      assert has_element?(view, "code", "0-100")
    end

    test "can close discrepancy modal", %{conn: conn} do
      job = create_job(%{name: "Test Job"})
      table_rec = create_table_reconciliation(job)
      run = create_run(job, %{status: "completed"})
      partition = create_partition(run, table_rec)
      create_discrepancy(partition)

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      view
      |> element(
        "button[phx-click='show_discrepancies'][phx-value-partition_id='#{partition.id}']"
      )
      |> render_click()

      assert has_element?(view, "h3", "Discrepancies in Partition")

      view
      |> element("button[phx-click='close_modal']")
      |> render_click()

      refute has_element?(view, "h3", "Discrepancies in Partition")
    end

    test "displays discrepancy details in modal", %{conn: conn} do
      job = create_job(%{name: "Test Job"})
      table_rec = create_table_reconciliation(job)
      run = create_run(job)
      partition = create_partition(run, table_rec)

      create_discrepancy(partition, %{
        discrepancy_type: "field_mismatch",
        row_identifier: %{"id" => 456},
        field_diffs: %{
          "name" => %{
            "source" => "John Doe",
            "target" => "Jane Doe"
          }
        }
      })

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      html =
        view
        |> element(
          "button[phx-click='show_discrepancies'][phx-value-partition_id='#{partition.id}']"
        )
        |> render_click()

      assert html =~ "field_mismatch"
      assert html =~ "456"
      assert html =~ "name"
      assert html =~ "John Doe"
      assert html =~ "Jane Doe"
    end

    test "has edit job link", %{conn: conn} do
      job = create_job(%{name: "Test Job"})

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert has_element?(view, "a[href='/jobs/#{job.id}/edit']", "Edit Job")
    end

    test "displays running job progress", %{conn: conn} do
      job = create_job(%{name: "Test Job"})

      create_run(job, %{
        status: "running",
        total_rows: 10000,
        processed_rows: 3000,
        discrepancies_found: 2
      })

      {:ok, _view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "running"
      assert html =~ "3000"
      assert html =~ "10000"
    end
  end
end
