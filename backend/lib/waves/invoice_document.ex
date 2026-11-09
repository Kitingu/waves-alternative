defmodule Waves.InvoiceDocument do
  require EEx
  alias Waves.{Repo, Business, Customer, Settings}
  @template Path.expand("invoice_document/invoice.html.eex", __DIR__)
  @external_resource @template
  EEx.function_from_file(:defp, :render_template, @template, [:data])
  def render(invoice, opts \\ []) do
    business = Repo.get!(Business, invoice.business_id)
    customer = Repo.get_by!(Customer, id: invoice.customer_id, business_id: invoice.business_id)
    company = invoice.business_snapshot || Settings.snapshot(business)
    recipient = invoice.customer_snapshot || Map.new([:name, :email, :address, :phone, :tax_id], &{Atom.to_string(&1), Map.get(customer, &1)})
    history = Waves.Finance.payment_history(invoice.business_id, invoice.id)
    invoice = Waves.Finance.decorate_invoice(invoice, history)
    opts = Keyword.put(opts, :payments, if(Keyword.get(opts, :include_payments, false), do: history, else: []))
    render_data(invoice, company, recipient, opts)
  end
  # Also used for deterministic document rendering tests without a database.
  def render_data(invoice, company, recipient, opts \\ []) do
    color = company["accent_color"] || "#174f47"
    template = company["invoice_template"] || "modern"
    position = company["stamp_position"] || "right"
    data = %{invoice: invoice, company: company, customer: recipient,
      include_payments: Keyword.get(opts, :include_payments, false), payments: Keyword.get(opts, :payments, []),
      preview: Keyword.get(opts, :preview, true),
      color: if(Regex.match?(~r/\A#[0-9a-fA-F]{6}\z/, color), do: color, else: "#174f47"),
      template: if(template in ["modern", "classic", "minimal"], do: template, else: "modern"),
      position: if(position in ["left", "center", "right"], do: position, else: "right"),
      stamp_width: if(is_integer(company["stamp_width"]), do: min(220, max(60, company["stamp_width"])), else: 120),
      css: File.read!(Application.app_dir(:waves, "priv/static/assets/invoice.css"))}
    render_template(data)
  end
  def filename(invoice), do: (invoice.number || "Draft-" <> String.slice(invoice.id, 0, 8)) <> ".pdf"
  defp e(nil), do: ""
  defp e(value), do: value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  defp present?(value), do: not is_nil(value) and String.trim(to_string(value)) != ""
  defp money(nil), do: "0.00"
  defp money(value) do
    decimal = if match?(%Decimal{}, value), do: value, else: Decimal.new(value)
    [whole | fraction] = decimal |> Decimal.round(2, :half_up) |> Decimal.to_string(:normal) |> String.split(".")
    grouped = Regex.replace(~r/\B(?=(\d{3})+(?!\d))/, whole, ",")
    grouped <> "." <> String.pad_trailing(List.first(fraction) || "", 2, "0")
  end
  defp image(value), do: if(Waves.BrandAsset.valid_data_uri?(value), do: value, else: nil)
end
