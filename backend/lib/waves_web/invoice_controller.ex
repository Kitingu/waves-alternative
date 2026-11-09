defmodule WavesWeb.InvoiceController do
  use Phoenix.Controller, formats: [:html, :json]
  import Plug.Conn
  alias Waves.{Finance, InvoiceDocument, InvoicePDF}
  def show(conn, %{"id" => id} = params) do
    with key when not is_nil(key) <- session_key(conn),
         %Waves.Invoice{} = invoice <- Finance.invoice(key.business_id, id) do
      conn |> put_resp_header("cache-control", "private, no-store") |> html(InvoiceDocument.render(invoice, include_payments: params["payments"] == "1"))
    else
      nil -> if(session_key(conn), do: send_resp(conn, 404, "Invoice not found"), else: redirect(conn, to: "/login"))
    end
  end
  def download(conn, %{"id" => id} = params) do
    if key = session_key(conn), do: serve_pdf(conn, key, id, params["payments"] == "1"), else: redirect(conn, to: "/login")
  end
  def api_download(conn, %{"id" => id} = params), do: serve_pdf(conn, conn.assigns.api_key, id, params["payments"] == "1")
  defp serve_pdf(conn, key, id, include_payments) do
    case Finance.invoice(key.business_id, id) do
      nil -> send_resp(conn, 404, "Invoice not found")
      invoice ->
        case InvoicePDF.generate(invoice, include_payments: include_payments) do
          {:ok, pdf} ->
            conn |> put_resp_header("cache-control", "private, no-store")
            |> send_download({:binary, pdf}, filename: InvoiceDocument.filename(invoice), content_type: "application/pdf")
          {:error, _} ->
            conn |> put_status(503) |> html("<h1>PDF renderer unavailable</h1><p>Check the Chrome / Chromium configuration on the server.</p><p>You can still use Print / Save as PDF from the invoice preview.</p>")
        end
    end
  end
  defp session_key(conn), do: WavesWeb.BrowserAuth.scope_conn(conn)
end
