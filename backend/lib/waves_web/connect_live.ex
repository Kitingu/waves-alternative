defmodule WavesWeb.ConnectLive do
  use Phoenix.LiveView, layout: false
  def render(assigns) do
    ~H"""
    <main class="connect">
      <div class="brand">W / Finance</div>
      <h1>Your books, connected.</h1>
      <p>Development access for your business finance workspace.</p>
      <p class="muted">Enter the bootstrap key created during setup. Individual user accounts are the next foundation milestone.</p>
      <p :if={@flash["error"]} role="alert" class="error">{@flash["error"]}</p>
      <form action="/session" method="post">
        <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
        <label>Business API key<input type="password" name="token" required minlength="32" autocomplete="off" /></label>
        <button class="primary">Connect business</button>
      </form>
    </main>
    """
  end
end
