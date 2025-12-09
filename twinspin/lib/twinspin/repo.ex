defmodule Twinspin.Repo do
  use Ecto.Repo,
    otp_app: :twinspin,
    adapter: Ecto.Adapters.Postgres
end
