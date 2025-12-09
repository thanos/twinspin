defmodule TwinspinWeb.Router do
  use TwinspinWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TwinspinWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public routes (e.g., landing page, login, registration)
  scope "/", TwinspinWeb do
    pipe_through :browser

    # Oban Web Dashboard
    forward "/oban", Oban.Web.Router

    # live "/", DatabaseConnectionLive.Index, :index

    # Removed the old root route
    live "/", ReconciliationLive.Index, :index
  end

  # Authenticated routes
  scope "/", TwinspinWeb do
    # on_mount will be added later for authentication
    live_session :require_authenticated_user, on_mount: [] do
      live "/settings", SettingsLive, :index
      live "/connections", DatabaseConnectionLive.Index, :index
      live "/jobs/:id", ReconciliationLive.Show, :show
      live "/jobs/:id/edit", ReconciliationLive.Edit, :edit
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", TwinspinWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:twinspin, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      live_dashboard "/dashboard", metrics: TwinspinWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
