# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :twinspin,
  ecto_repos: [Twinspin.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: false]

# Configures the endpoint
config :twinspin, TwinspinWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TwinspinWeb.ErrorHTML, json: TwinspinWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Twinspin.PubSub,
  live_view: [signing_salt: "zQh4P7kz"]

# Configure Oban
config :twinspin, Oban,
  repo: Twinspin.Repo,
  notifier: Oban.Notifiers.PG,
  engine: Oban.Engines.Basic,
  queues: [reconciliation: 10],
  plugins: [Oban.Plugins.Pruner]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  twinspin: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.1",
  twinspin: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/css/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console, format: "$time $metadata[$level] $message\n"

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
