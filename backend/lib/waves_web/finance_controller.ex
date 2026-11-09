defmodule WavesWeb.FinanceController do
  use Phoenix.Controller, formats: [:json]
  alias Waves.{Finance, Repo, Business, Settings}
  def health(conn, _), do: json(conn, %{status: "ok"})
  def business(conn, _), do: json(conn, %{data: Repo.get!(Business, conn.assigns.api_key.business_id)})
  def update_business(conn, attrs), do: respond(conn, Settings.save(conn.assigns.api_key, attrs), 200)
  def customers(conn, _), do: json(conn, %{data: Finance.customers(conn.assigns.api_key.business_id)})
  def invoices(conn, _), do: json(conn, %{data: Finance.invoices(conn.assigns.api_key.business_id)})
  def entries(conn, _), do: json(conn, %{data: Finance.entries(conn.assigns.api_key.business_id)})
  def create_customer(conn, attrs), do: respond(conn, Finance.customer(conn.assigns.api_key.business_id, attrs), 201)
  def create_invoice(conn, attrs), do: respond(conn, Finance.draft(conn.assigns.api_key.business_id, attrs), 201)
  def update_invoice(conn, %{"id" => id} = attrs), do: respond(conn, Finance.update_draft(conn.assigns.api_key, id, attrs), 200)
  def payments(conn, %{"id" => id}) do
    case Finance.invoice(conn.assigns.api_key.business_id, id) do
      nil -> conn |> put_status(404) |> json(%{error: %{code: "not_found"}})
      invoice -> json(conn, %{data: Finance.payment_history(invoice.business_id, invoice.id)})
    end
  end
  def issue(conn, %{"id" => id}), do: respond(conn, Finance.issue(conn.assigns.api_key, id), 200)
  def pay(conn, %{"id" => id} = attrs), do: respond(conn, Finance.pay(conn.assigns.api_key, id, attrs), 200)
  defp respond(conn, {:ok, result}, status), do: conn |> put_status(status) |> json(%{data: result})
  defp respond(conn, {:error, reason}, _) do
    code = if is_atom(reason), do: Atom.to_string(reason), else: "validation_failed"
    status = case reason do
      :not_found -> 404
      :subscription_required -> 402
      error when error in [:already_issued, :reference_conflict, :invoice_not_payable, :issued_invoice_cannot_be_edited, :draft_changed_reload_before_saving] -> 409
      _ -> 422
    end
    conn |> put_status(status) |> json(%{error: %{code: code, message: String.replace(code, "_", " ")}})
  end
end
