defmodule WavesWeb.AccountPage do
  use Phoenix.Component

  def html(assigns) do
    assigns = Map.merge(%{error: nil, notice: nil, email: "", token: "", businesses: [], usage: nil, business: nil, support: nil}, assigns)
    body = render(assigns) |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
    WavesWeb.Layouts.root(%{inner_content: Phoenix.HTML.raw(body)}) |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
  end

  def render(assigns) do
    ~H"""
    <main class="account-page">
      <a href="/" class="brand account-brand">W / Finance</a>
      <section>
        <h1>{@title}</h1><p class="muted">{@description}</p>
        <p :if={@notice} class="flash" role="status">{@notice}</p>
        <p :if={@error} class="error" role="alert">{@error}</p>
        <form :if={@page in [:login, :register, :forgot, :reset]} action={@action} method="post" class="account-form">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <label :if={@page == :register}>Your name<input name="name" required maxlength="200" autocomplete="name" /></label>
          <label :if={@page != :reset}>Email<input name="email" type="email" value={@email} required autocomplete="email" maxlength="254" /></label>
          <label :if={@page != :forgot}>Password<input name="password" type="password" required minlength={if @page != :login, do: 12} maxlength="72" autocomplete={if @page == :login, do: "current-password", else: "new-password"} /></label>
          <label :if={@page in [:register, :reset]}>Confirm password<input name="password_confirmation" type="password" required minlength="12" maxlength="72" autocomplete="new-password" /></label>
          <button class="primary">{case @page do :login -> "Log in"; :register -> "Create account"; :forgot -> "Send reset link"; :reset -> "Save password" end}</button>
        </form>
        <div :if={@page == :login} class="account-links"><a href="/register">Create an account</a><a href="/forgot-password">Forgot password?</a></div>
        <p :if={@page in [:register, :forgot, :reset, :notice]} class="subtle"><a href="/login">Back to login</a></p>
        <form :if={@page == :notice} method="post" action="/verification-email" class="account-form">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <label>Email<input name="email" type="email" value={@email} required autocomplete="email" /></label><button>Resend verification email</button>
        </form>
        <form :if={@page == :verify} method="post" action={"/verify/#{@token}"}><input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} /><button class="primary">Verify my email</button></form>
        <form :if={@page == :onboard} action="/onboarding" method="post" class="account-form">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <label>Business name<input name="name" required maxlength="200" autocomplete="organization" /></label>
          <div class="form-grid"><label>Country<input name="country" value="Kenya" required maxlength="100" /></label><label>Business currency<select name="currency"><option :for={currency <- ["KES", "USD", "EUR", "GBP"]} value={currency}>{currency}</option></select></label></div>
          <details id="onboarding-tax" class="account-options"><summary>Tax settings (optional)</summary><div class="form-grid"><label>Tax treatment<select name="tax_mode"><option value="none">No tax</option><option value="exclusive">Add tax to prices</option><option value="inclusive">Prices include tax</option></select></label><label>Tax label<input name="tax_name" value="Tax" maxlength="100" /></label><label>Rate (%)<input name="tax_rate" value="0" inputmode="decimal" /></label></div></details>
          <p class="subtle">You can add your logo, stamp and company details later. Your first five issued invoices are free.</p><button class="primary">Create business & start invoicing</button>
        </form>
        <div :if={@page == :businesses}>
          <form :for={business <- @businesses} method="post" action="/business/switch" class="business-choice"><input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} /><input type="hidden" name="business_id" value={business.id} /><span>{business.name}</span><button>Open</button></form>
          <a href="/onboarding">Set up another business</a>
        </div>
        <div :if={@page == :billing}>
          <div class="usage-summary"><strong>{@usage.issued}</strong> invoices issued · {if @usage.active, do: "Active subscription", else: "5 free invoices included"}</div>
          <p :if={!@usage.active} class="muted">You can continue creating drafts, recording payments and downloading existing invoices. An active subscription is needed after your five free invoices.</p>
          <p :if={!@usage.active && @support}>Contact <a href={"mailto:#{@support}"}>{@support}</a> to activate your subscription.</p>
          <p :if={!@usage.active && !@support} class="muted">Contact your service administrator to activate a subscription.</p>
          <a href="/" class="button">Back to invoices</a>
        </div>
      </section>
    </main>
    """
  end
end
