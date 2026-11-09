defmodule Waves.InvoicePDF do
  require Logger
  def generate(invoice, opts \\ []) do
    if Application.get_env(:waves, :pdf_enabled, true) do
      try do
        html = Waves.InvoiceDocument.render(invoice, Keyword.put(opts, :preview, false))
        case ChromicPDF.print_to_pdf({:html, html}, print_to_pdf: %{printBackground: true, preferCSSPageSize: true,
          displayHeaderFooter: true, headerTemplate: "<span></span>",
          footerTemplate: ~s(<div style="width:100%;text-align:center;font:9px Arial;color:#899399">Page <span class="pageNumber"></span> of <span class="totalPages"></span></div>)}) do
          {:ok, encoded} -> Base.decode64(encoded)
          _ -> {:error, :pdf_unavailable}
        end
      rescue
        error ->
          Logger.error("Invoice PDF renderer failed: #{Exception.message(error)}")
          {:error, :pdf_unavailable}
      catch
        :exit, _ -> {:error, :pdf_unavailable}
      end
    else
      {:error, :pdf_unavailable}
    end
  end
end
