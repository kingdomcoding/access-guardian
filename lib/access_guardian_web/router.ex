defmodule AccessGuardianWeb.Router do
  use AccessGuardianWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AccessGuardianWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AccessGuardianWeb do
    pipe_through :browser

    live_session :default do
      live "/", DashboardLive, :index
      live "/requests", RequestsLive, :index
      live "/applications", ApplicationsLive, :index
      live "/integrations/setup", IntegrationSetupLive, :index
    end
  end

  scope "/api/slack", AccessGuardianWeb do
    pipe_through :api

    post "/commands", SlackController, :commands
    post "/interactions", SlackController, :interactions
    post "/events", SlackController, :events
  end

  if Application.compile_env(:access_guardian, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AccessGuardianWeb.Telemetry
    end
  end
end
