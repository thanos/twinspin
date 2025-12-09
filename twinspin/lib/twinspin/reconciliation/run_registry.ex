defmodule Twinspin.RunRegistry do
  @moduledoc """
  Registry for tracking active reconciliation run workers.
  Allows looking up workers by run_id.
  """

  def child_spec(_opts) do
    Registry.child_spec(
      keys: :unique,
      name: __MODULE__
    )
  end
end
