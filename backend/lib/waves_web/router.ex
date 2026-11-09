defmodule WavesWeb.Router do
  use Phoenix.Router
  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WavesWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end
  scope "/", WavesWeb do
    pipe_through :browser
    get "/connect", AccountController, :legacy
    get "/login", AccountController, :login
    get "/register", AccountController, :register
    post "/register", AccountController, :create_account
    get "/forgot-password", AccountController, :forgot
    post "/forgot-password", AccountController, :send_reset
    get "/reset/:token", AccountController, :reset_form
    post "/reset/:token", AccountController, :reset
    get "/verify/:token", AccountController, :verify_form
    post "/verify/:token", AccountController, :confirm
    post "/verification-email", AccountController, :send_verification
    get "/onboarding", AccountController, :onboarding
    post "/onboarding", AccountController, :create_business
    get "/businesses", AccountController, :businesses
    post "/business/switch", AccountController, :switch
    get "/billing", AccountController, :billing
    post "/session", SessionController, :create
    delete "/session", SessionController, :delete
    live "/catalogue", CatalogueLive
    live "/settings", SettingsLive
    get "/invoices/:id", InvoiceController, :show
    get "/invoices/:id/pdf", InvoiceController, :download
    live "/", FinanceLive
  end
  if Application.compile_env(:waves, :dev_mailbox, false) do
    scope "/dev" do
      pipe_through :browser
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
  pipeline :api do
    plug :accepts, ["json"]
    plug WavesWeb.Auth
  end
  pipeline :api_download do
    plug WavesWeb.Auth
  end
  scope "/api/v1", WavesWeb do
    pipe_through :api_download
    get "/invoices/:id/pdf", InvoiceController, :api_download
  end
  get "/health", WavesWeb.FinanceController, :health
  scope "/api/v1", WavesWeb do
    pipe_through :api
    get "/business", FinanceController, :business
    patch "/business", FinanceController, :update_business
    get "/items", CatalogueController, :index
    post "/items", CatalogueController, :create
    patch "/items/:id", CatalogueController, :update
    get "/customers", FinanceController, :customers
    post "/customers", FinanceController, :create_customer
    get "/invoices", FinanceController, :invoices
    post "/invoices", FinanceController, :create_invoice
    patch "/invoices/:id", FinanceController, :update_invoice
    get "/invoices/:id/payments", FinanceController, :payments
    post "/invoices/:id/issue", FinanceController, :issue
    post "/invoices/:id/payments", FinanceController, :pay
    get "/ledger/entries", FinanceController, :entries
  end
end
