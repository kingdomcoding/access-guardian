# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :access_guardian,
  ecto_repos: [AccessGuardian.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [
    AccessGuardian.Catalog,
    AccessGuardian.Access
  ]

config :access_guardian, :slack_enabled, false

config :access_guardian, Oban,
  repo: AccessGuardian.Repo,
  queues: [default: 10, provisioning: 5]

# Configure the endpoint
config :access_guardian, AccessGuardianWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AccessGuardianWeb.ErrorHTML, json: AccessGuardianWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AccessGuardian.PubSub,
  live_view: [signing_salt: "dXIvuogt"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  access_guardian: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  access_guardian: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
