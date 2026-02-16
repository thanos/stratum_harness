defmodule StratumHarnessWeb.Router do
  use StratumHarnessWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StratumHarnessWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_auth do
    plug StratumHarnessWeb.Plugs.Auth
  end

  # Public routes (no authentication)
  scope "/", StratumHarnessWeb do
    pipe_through :browser

    live "/", LandingLive
    live "/instructions", InstructionsLive
  end

  # Auth routes
  scope "/auth", StratumHarnessWeb do
    pipe_through :browser

    post "/login", AuthController, :login
    get "/logout", AuthController, :logout
  end

  # Protected routes (requires authentication)
  scope "/", StratumHarnessWeb do
    pipe_through [:browser, :require_auth]

    live "/dashboard", DashboardLive
  end

  # API routes (no authentication for now - you may want to add API keys later)
  scope "/api", StratumHarnessWeb do
    pipe_through :api

    get "/state", ApiController, :state
    get "/sessions", ApiController, :sessions
    get "/traces", ApiController, :traces
    post "/control/profile", ApiController, :switch_profile
    post "/control/rotate_job", ApiController, :rotate_job
    post "/control/advance_tip", ApiController, :advance_tip
    post "/control/set_difficulty", ApiController, :set_difficulty
    get "/debug/bundle/:session_id", ApiController, :debug_bundle
  end

  # Other scopes may use custom stacks.
  # scope "/api", StratumHarnessWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:stratum_harness, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: StratumHarnessWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
