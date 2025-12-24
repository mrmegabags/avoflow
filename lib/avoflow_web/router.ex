defmodule AvoflowWeb.Router do
  use AvoflowWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AvoflowWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :snoop
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  def snoop(conn, _opts) do
    answer = ~w(Yes No Maybe) |> Enum.random()

    conn = assign(conn, :answer, answer)

    # IO.inspect(conn)

    conn
  end

  scope "/", AvoflowWeb do
    pipe_through :browser

    # lib/avoflow_web/router.ex (inside the appropriate scope/pipeline)
    live_session :app,
      on_mount: [{AvoflowWeb.Live.AppShell, :default}],
      layout: {AvoflowWeb.Layouts, :app} do
      # Add all your other LiveViews here to inherit Sidebar + TopBar automatically.
      # live "/batches", AvoflowWeb.BatchesLive, :index
      live "/dashboard", DashboardLive
      live "/suppliers", SuppliersLive
      live "/suppliers/:id", SupplierDetailLive
      live "/batches", BatchesLive
      live "/batches/new", BatchIntakeLive
      live "/batches/:id", BatchesDetailLive
      live "/inventory", InventoryLive
      live "/production", ProductionLive
    end

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", AvoflowWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:avoflow, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AvoflowWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
