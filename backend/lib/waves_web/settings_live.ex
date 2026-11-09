defmodule WavesWeb.SettingsLive do
  use Phoenix.LiveView, layout: false
  alias Waves.{Repo, Business, Settings, BrandAsset}
  def mount(_, session, socket) do
    key = WavesWeb.BrowserAuth.scope(session)
    if key && WavesWeb.BrowserAuth.owner?(key) do
      business = Repo.get!(Business, key.business_id)
      {:ok, socket |> assign(key: key, browser_session: session, business: business, preview: business)
        |> assign_form(Settings.changeset(business, %{}))
        |> allow_upload(:logo, accept: ~w(.png), max_entries: 1, max_file_size: 512_000)
        |> allow_upload(:stamp, accept: ~w(.png), max_entries: 1, max_file_size: 512_000)
        |> allow_upload(:signature, accept: ~w(.png), max_entries: 1, max_file_size: 512_000)}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end
  def handle_event(event, params, socket) do
    if WavesWeb.BrowserAuth.owner?(WavesWeb.BrowserAuth.scope(socket.assigns.browser_session)), do: dispatch(event, params, socket),
      else: {:noreply, redirect(socket, to: "/login")}
  end
  defp dispatch("validate", %{"settings" => params}, socket) do
    changeset = Settings.changeset(socket.assigns.business, params) |> Map.put(:action, :validate)
    {:noreply, socket |> assign_form(changeset) |> assign(preview: Ecto.Changeset.apply_changes(changeset))}
  end
  defp dispatch("save", %{"settings" => params}, socket) do
    assets = Enum.reduce([{:logo, :logo_data}, {:stamp, :stamp_data}, {:signature, :signature_data}], %{}, fn {upload, field}, assets ->
      results = consume_uploaded_entries(socket, upload, fn %{path: path}, _entry ->
        {:ok, BrandAsset.from_file(path)}
      end)
      case results do
        [{:ok, data}] -> Map.put(assets, field, data)
        [] -> assets
        _ -> Map.put(assets, field, :invalid)
      end
    end)
    case Settings.save(socket.assigns.key, params, assets) do
      {:ok, business} -> {:noreply, socket |> assign(business: business, preview: business) |> assign_form(Settings.changeset(business, %{})) |> put_flash(:info, "Settings saved. New documents use these defaults; issued invoices retain their saved details.")}
      {:error, changeset} -> {:noreply, socket |> assign_form(changeset) |> put_flash(:error, "Please check the fields. Images must be valid PNG files, at most 500 KB and 4096 × 4096 pixels.")}
    end
  end
  defp dispatch("remove-asset", %{"asset" => name}, socket) when name in ["logo", "stamp", "signature"] do
    field = %{"logo" => :logo_data, "stamp" => :stamp_data, "signature" => :signature_data}[name]
    case Settings.save(socket.assigns.key, %{}, %{field => nil}) do
      {:ok, business} -> {:noreply, socket |> assign(business: business, preview: business) |> assign_form(Settings.changeset(business, %{})) |> put_flash(:info, "Image removed from future documents. Issued copies are unchanged.")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "The image could not be removed.")}
    end
  end
  defp dispatch("cancel-upload", %{"name" => name, "ref" => ref}, socket) when name in ["logo", "stamp", "signature"] do
    upload = %{"logo" => :logo, "stamp" => :stamp, "signature" => :signature}[name]
    {:noreply, cancel_upload(socket, upload, ref)}
  end
  defp dispatch(_, _, socket), do: {:noreply, socket}
  defp assign_form(socket, changeset), do: assign(socket, form: to_form(changeset, as: :settings))
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :options, :list, default: []
  def field(assigns) do
    ~H"""
    <label class={if @type == "checkbox", do: "checkbox-field"}>
      <span>{@label}</span>
      <textarea :if={@type == "textarea"} id={@field.id} name={@field.name} rows="3">{@field.value}</textarea>
      <select :if={@type == "select"} id={@field.id} name={@field.name}><option :for={{label, value} <- @options} value={value} selected={to_string(@field.value) == to_string(value)}>{label}</option></select>
      <input :if={@type == "checkbox"} type="hidden" name={@field.name} value="false" />
      <input :if={@type == "checkbox"} type="checkbox" id={@field.id} name={@field.name} value="true" checked={Phoenix.HTML.Form.normalize_value("checkbox", @field.value)} />
      <span :if={@type == "color"} class="color-control">
        <input type="color" id={@field.id} name={@field.name} value={@field.value} />
        <span class="color-swatch" style={"background-color: #{safe_color(@field.value)}"}></span>
        <output for={@field.id}>{safe_color(@field.value)}</output>
      </span>
      <input :if={@type not in ["textarea", "select", "checkbox", "color"]} type={@type} id={@field.id} name={@field.name} value={@field.value} step={if @type == "number", do: "any"} />
      <span :for={{message, _opts} <- @field.errors} class="field-error">{message}</span>
    </label>
    """
  end
  attr :upload, :any, required: true
  attr :kind, :string, required: true
  attr :existing, :any, default: nil
  def asset(assigns) do
    ~H"""
    <div class="asset-box">
      <h3>{String.capitalize(@kind)}</h3>
      <img :if={@existing} src={@existing} alt={@kind} class="asset-image" />
      <details :if={@existing} id={"saved-#{@kind}-preview"} phx-hook="KeepOpen"><summary>View saved {@kind}</summary><img src={@existing} alt={"Saved #{@kind}"} class="asset-large" /></details>
      <button :if={@existing} type="button" phx-click="remove-asset" phx-value-asset={@kind}>Remove saved image</button>
      <.live_file_input upload={@upload} />
      <div :for={entry <- @upload.entries}>
        <.live_img_preview entry={entry} class="asset-image" />
        <span>{entry.client_name} · {entry.progress}%</span>
        <button type="button" phx-click="cancel-upload" phx-value-name={@kind} phx-value-ref={entry.ref}>Cancel</button>
        <p :for={error <- upload_errors(@upload, entry)} class="field-error">{upload_error(error)}</p>
      </div>
      <p :for={error <- upload_errors(@upload)} class="field-error">{upload_error(error)}</p>
      <p class="subtle">PNG, up to 500 KB. Transparent backgrounds work best.</p>
    </div>
    """
  end
  defp safe_color(color) when is_binary(color), do: if(Regex.match?(~r/\A#[0-9a-fA-F]{6}\z/, color), do: color, else: "#174f47")
  defp safe_color(_), do: "#174f47"
  defp contrast_color(color) do
    <<"#", red::binary-size(2), green::binary-size(2), blue::binary-size(2)>> = safe_color(color)
    lightness = String.to_integer(red, 16) * 299 + String.to_integer(green, 16) * 587 + String.to_integer(blue, 16) * 114
    if lightness > 150_000, do: "#172326", else: "#ffffff"
  end
  defp upload_error(:too_large), do: "The image is too large."
  defp upload_error(:not_accepted), do: "Please select a PNG image."
  defp upload_error(:too_many_files), do: "Choose one image."
  defp upload_error(_), do: "The image could not be uploaded."
  def render(assigns), do: index(assigns)
  embed_templates "settings_live/*"
end
