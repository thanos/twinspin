defmodule Twinspin.Reconciliation.Engine do
  @moduledoc """
  Supervises and manages reconciliation run workers.
  Provides API for starting, stopping, and monitoring reconciliation runs.
  """

  use DynamicSupervisor
  alias Twinspin.Reconciliation.RunWorker

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new reconciliation run worker.
  Returns {:ok, pid} on success.
  """
  def start_run(run_id) do
    spec = {RunWorker, run_id: run_id}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  @doc """
  Stops a running reconciliation run worker.
  """
  def stop_run(run_id) do
    case find_run_worker(run_id) do
      nil -> {:error, :not_found}
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end

  @doc """
  Returns a list of all active run workers.
  """
  def list_active_runs do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} ->
      case pid do
        :restarting -> nil
        pid when is_pid(pid) -> RunWorker.get_run_id(pid)
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Checks if a run worker is currently active.
  """
  def run_active?(run_id) do
    find_run_worker(run_id) != nil
  end

  # Private helpers

  defp find_run_worker(run_id) do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.find_value(fn {_, pid, _, _} ->
      case pid do
        :restarting ->
          nil

        pid when is_pid(pid) ->
          if RunWorker.get_run_id(pid) == run_id, do: pid
      end
    end)
  end
end
