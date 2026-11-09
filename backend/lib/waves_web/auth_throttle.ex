defmodule WavesWeb.AuthThrottle do
  use GenServer
  import Plug.Conn

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def init(state) when is_map(state) do
    Process.send_after(self(), :cleanup, 60_000)
    {:ok, state}
  end
  def init(opts) when is_list(opts), do: opts

  def call(conn, _) do
    if Application.get_env(:waves, :auth_throttle, true) and
       not GenServer.call(__MODULE__, {:allow, conn.remote_ip}) do
      conn |> put_resp_header("retry-after", "300") |> send_resp(429, "Too many attempts. Please try again in a few minutes.") |> halt()
    else
      conn
    end
  end
  def handle_call({:allow, key}, _from, state) do
    now = System.monotonic_time(:second)
    {count, until} = Map.get(state, key, {0, now + 300})
    {count, until} = if until <= now, do: {0, now + 300}, else: {count, until}
    {:reply, count < 30, Map.put(state, key, {count + 1, until})}
  end
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:second)
    Process.send_after(self(), :cleanup, 60_000)
    {:noreply, Map.reject(state, fn {_key, {_count, until}} -> until <= now end)}
  end
end
