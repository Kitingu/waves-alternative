defmodule WavesWeb.CatalogueController do
  use Phoenix.Controller, formats: [:json]
  alias Waves.Catalogue
  def index(conn, _), do: json(conn, %{data: Catalogue.list(conn.assigns.api_key.business_id)})
  def create(conn, attrs) do
    result = if Map.has_key?(attrs, "code"),
      do: Catalogue.save(conn.assigns.api_key.business_id, attrs),
      else: Catalogue.save_simple(conn.assigns.api_key.business_id, attrs)
    respond(conn, result, 201)
  end
  def update(conn, %{"id" => id} = attrs), do: respond(conn, Catalogue.save(conn.assigns.api_key.business_id, attrs, id), 200)
  defp respond(conn, {:ok, item}, status), do: conn |> put_status(status) |> json(%{data: item})
  defp respond(conn, {:error, :not_found}, _), do: conn |> put_status(404) |> json(%{error: %{code: "not_found"}})
  defp respond(conn, {:error, _}, _), do: conn |> put_status(422) |> json(%{error: %{code: "invalid_item", message: "Check the code, price and billing parameters."}})
end
