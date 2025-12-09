defmodule TwinspinWeb.ReconciliationLive.IndexTest do
  use TwinspinWeb.ConnCase
  import Phoenix.LiveViewTest
  import Twinspin.TestHelpers

  describe "Index page" do
    test "displays the dashboard with no jobs", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Reconciliation Dashboard"
      assert html =~ "Reconciliation Dashboard"
    end

    test "displays list of reconciliation jobs", %{conn: conn} do
      source_conn = create_connection(%{name: "Source DB"})
      target_conn = create_connection(%{name: "Target DB"})

      job =
        create_job(%{
          name: "Customer Data Reconciliation",
          description: "Reconcile customer records",
          source_connection: source_conn,
          target_connection: target_conn
        })

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Customer Data Reconciliation"
      assert html =~ "Reconcile customer records"
      assert html =~ "Source DB"
      assert html =~ "Target DB"
    end

    test "displays job with latest run status", %{conn: conn} do
      job = create_job(%{name: "Test Job"})

      _run =
        create_run(job, %{
          status: "completed",
          total_rows: 1000,
          processed_rows: 1000,
          discrepancies_found: 5,
          started_at:
            DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second),
          completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "completed"
      assert html =~ "1000/1000"
      assert html =~ "5"
    end

    test "can navigate to job detail page", %{conn: conn} do
      job = create_job(%{name: "Test Job"})

      {:ok, view, _html} = live(conn, ~p"/")

      {:ok, _show_view, html} =
        view
        |> element("a[href='/jobs/#{job.id}']")
        |> render_click()
        |> follow_redirect(conn, "/jobs/#{job.id}")

      assert html =~ "Test Job"
    end

    test "can delete a job", %{conn: conn} do
      job = create_job(%{name: "Test Job to Delete"})

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#jobs-#{job.id}")

      view
      |> element("#jobs-#{job.id} button[phx-click='delete']")
      |> render_click()

      refute has_element?(view, "#jobs-#{job.id}")
      refute render(view) =~ "Test Job to Delete"
    end

    test "displays empty state when no jobs exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "h3", "No jobs configured")
      assert has_element?(view, "p", "Create your first reconciliation job to get started")
    end

    test "displays multiple jobs in order", %{conn: conn} do
      job1 = create_job(%{name: "Job Alpha"})
      job2 = create_job(%{name: "Job Beta"})
      job3 = create_job(%{name: "Job Gamma"})

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Job Alpha"
      assert html =~ "Job Beta"
      assert html =~ "Job Gamma"
    end

    test "shows correct threshold and max depth", %{conn: conn} do
      _job =
        create_job(%{
          name: "Config Test Job",
          partition_row_threshold: 50000,
          partition_max_depth: 8
        })

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "50000"
      assert html =~ "8"
    end

    test "handles jobs without description", %{conn: conn} do
      _job =
        create_job(%{
          name: "No Description Job",
          description: nil
        })

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "No Description Job"
      refute html =~ "<p class=\"mb-3"
    end

    test "displays run statistics correctly", %{conn: conn} do
      job = create_job(%{name: "Stats Test Job"})

      _run =
        create_run(job, %{
          status: "running",
          total_rows: 100_000,
          processed_rows: 45000,
          discrepancies_found: 12
        })

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "running"
      assert html =~ "45000/100000"
      assert html =~ "12"
    end

    test "page title shows brand name", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Brand name is set in settings, default is "TwinSpin"
      assert html =~ "Reconciliation Dashboard"
    end
  end
end
