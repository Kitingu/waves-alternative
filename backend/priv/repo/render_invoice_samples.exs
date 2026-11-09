alias Waves.{Business, Settings, Invoice, InvoiceDocument, Money}

asset = fn name ->
  case System.get_env(name) do
    nil -> nil
    path ->
      case Waves.BrandAsset.from_file(path) do
        {:ok, data} -> data
        _ -> raise "#{name} must point to a valid PNG of at most 500 KB"
      end
  end
end

company = Settings.snapshot(%Business{name: "Example Studio", legal_name: "Example Studio Ltd",
  currency: "KES", address: "Business address\nNairobi, Kenya", email: "accounts@example.com",
  phone: "+254 700 000 000", website: "example.com", tax_id: "Your tax registration number",
  payment_details: "Bank: Your bank name\nAccount: Your account number\nReference: invoice number",
  invoice_footer: "Thank you for your business.", signatory_name: "Authorised signatory",
  signatory_title: "Finance team", logo_data: asset.("SAMPLE_LOGO_PATH"),
  stamp_data: asset.("SAMPLE_STAMP_PATH"), signature_data: asset.("SAMPLE_SIGNATURE_PATH")})

count = if System.get_env("SAMPLE_LONG_INVOICE") == "1", do: 80, else: 3
lines = for i <- 1..count, do: %{"description" => "Consulting services - deliverable #{i}", "quantity" => "1", "unit_price" => "1000.00"}
{:ok, values} = Money.invoice(lines, %{"tax_mode" => "exclusive", "tax_name" => "Example tax", "tax_rate" => "16"})
invoice = struct(Invoice, Map.merge(values, %{id: Ecto.UUID.generate(), currency: "KES", status: "issued",
  number: "SAMPLE-000001", issue_date: Date.utc_today(), due_date: Date.add(Date.utc_today(), 14),
  paid: Decimal.new("500.00"), notes: "DESIGN SAMPLE ONLY - NOT A PAYMENT REQUEST",
  terms: "Payment terms and conditions appear here.\nPlease include the invoice number in your payment reference."}))
recipient = %{"name" => "Example Customer Ltd", "address" => "Customer billing address\nNairobi, Kenya", "email" => "buyer@example.com", "tax_id" => "Customer tax registration"}
directory = Path.expand("tmp/invoice-samples")
File.mkdir_p!(directory)
for style <- ["modern", "classic", "minimal"] do
  html = InvoiceDocument.render_data(invoice, Map.put(company, "invoice_template", style), recipient, preview: false)
  File.write!(Path.join(directory, "#{style}.html"), html)
  if System.get_env("RENDER_SAMPLE_PDFS") == "1" do
    :ok = ChromicPDF.print_to_pdf({:html, html}, output: Path.join(directory, "#{style}.pdf"),
      print_to_pdf: %{printBackground: true, preferCSSPageSize: true})
  end
end
IO.puts("Design samples written to #{directory}. No financial records were created.")
