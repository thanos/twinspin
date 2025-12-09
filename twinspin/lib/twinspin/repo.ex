defmodule Twinspin.Repo do
  use Ecto.Repo,
    otp_app: :twinspin,
    adapter: Ecto.Adapters.SQLite3
end
