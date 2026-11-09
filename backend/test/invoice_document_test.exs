defmodule Waves.InvoiceDocumentTest do
  use ExUnit.Case, async: true
  alias Waves.{Invoice, InvoiceDocument}
  test "all layouts escape business, recipient and document text" do
    invoice = %Invoice{id: Ecto.UUID.generate(), currency: "KES", status: "issued", number: "T-000001", issue_date: ~D[2026-10-18], due_date: ~D[2026-11-01], lines: [%{"description" => "<img onerror=alert(1)>", "quantity" => "1", "unit_price" => "100", "total" => "100"}], subtotal: Decimal.new(100), tax_total: Decimal.new(16), tax_rate: Decimal.new(16), tax_mode: "exclusive", tax_name: "VAT", total: Decimal.new(116), paid: Decimal.new(40), notes: "<script>bad()</script>"}
    for style <- ["modern", "classic", "minimal"] do
      html = InvoiceDocument.render_data(invoice, %{"name" => "A & B", "invoice_template" => style, "accent_color" => "#174f47"}, %{"name" => "Buyer <script>"}, preview: false)
      assert html =~ "invoice-sheet #{style}"
      assert html =~ "A &amp; B"
      assert html =~ "&lt;script&gt;"
      assert html =~ "76.00"
      refute html =~ "<script>"
      refute html =~ "<img onerror="
      refute html =~ ~s(class="document-toolbar")
    end
  end
  test "renders every row for long invoices and clamps style inputs" do
    lines = for i <- 1..100, do: %{"description" => "Row #{i}", "quantity" => "1", "unit_price" => "1", "total" => "1"}
    invoice = %Invoice{id: Ecto.UUID.generate(), lines: lines, total: Decimal.new(100), paid: Decimal.new(0)}
    html = InvoiceDocument.render_data(invoice, %{"name" => "Business", "accent_color" => "red; bad", "invoice_template" => "unknown", "stamp_width" => 9999}, %{"name" => "Buyer"})
    assert html =~ "Row 100"
    assert html =~ "--accent:#174f47"
    assert html =~ "invoice-sheet modern"
    refute html =~ "red; bad"
  end
end
