defmodule WavesWeb.BillingFields do
  use Phoenix.Component
  attr :data, :map, required: true
  attr :prefix, :string, required: true
  attr :line, :string, required: true
  def fields(assigns) do
    ~H"""
    <div class="form-grid">
      <label>Billing method<select name={@prefix <> "[billing_method]"}><option :for={{label, value} <- [{"Quantity × rate", "quantity"}, {"Fixed charge", "fixed"}, {"Line parameters × rate", "parameters"}]} value={value} selected={Map.get(@data, "billing_method", "quantity") == value}>{label}</option></select></label>
      <label :if={Map.get(@data, "billing_method", "quantity") == "quantity"}>Quantity<input name={@prefix <> "[quantity]"} value={Map.get(@data, "quantity", "1")} inputmode="decimal" required /></label>
      <label>Unit / rate description<input name={@prefix <> "[unit]"} value={Map.get(@data, "unit", "Units")} maxlength="60" placeholder="Days, microphones per day, hours…" /></label>
    </div>
    <p class="subtle">Each “Charge multiplier” multiplies this line's rate. Text and dates appear as details only. Fixed/quantity billing cannot contain charge multipliers.</p>
    <div :for={{p, id} <- rows(@data)} class="parameter-row">
      <label>Parameter label<input name={@prefix <> "[parameters][#{id}][label]"} value={p["label"]} required maxlength="60" placeholder="Microphones, Days, Venue…" /></label>
      <label>Purpose<select name={@prefix <> "[parameters][#{id}][kind]"}><option :for={{label, value} <- [{"Charge multiplier", "multiplier"}, {"Text detail", "text"}, {"Date detail", "date"}]} value={value} selected={p["kind"] == value}>{label}</option></select></label>
      <label>Value<input type={if p["kind"] == "date", do: "date", else: "text"} name={@prefix <> "[parameters][#{id}][value]"} value={p["value"]} required={p["kind"] == "multiplier"} maxlength="500" /></label>
      <label>Unit (optional)<input name={@prefix <> "[parameters][#{id}][unit]"} value={p["unit"]} maxlength="60" placeholder="days, persons…" /></label>
      <button type="button" phx-click="remove-parameter" phx-value-line={@line} phx-value-id={id}>Remove</button>
    </div>
    <button :if={length(rows(@data)) < 12} type="button" phx-click="add-parameter" phx-value-line={@line}>Add parameter</button>
    """
  end
  def rows(data) do
    case Map.get(data, "parameters", %{}) do
      list when is_list(list) -> list |> Enum.with_index() |> Enum.map(fn {p, i} -> {p, to_string(i)} end)
      map when is_map(map) -> map |> Enum.sort_by(fn {id, _} -> String.to_integer(id) end) |> Enum.map(fn {id, p} -> {p, id} end)
      _ -> []
    end
  end
  def parameter_map(params) when is_list(params), do: params |> Enum.with_index() |> Map.new(fn {p, i} -> {to_string(i), p} end)
  def parameter_map(params) when is_map(params), do: params
  def parameter_map(_), do: %{}
  def parameter_list(data), do: data |> rows() |> Enum.map(&elem(&1, 0))
  def add(data) do
    params = parameter_map(data["parameters"])
    id = params |> Map.keys() |> Enum.map(&String.to_integer/1) |> Enum.max(fn -> -1 end) |> Kernel.+(1) |> to_string()
    Map.put(data, "parameters", Map.put(params, id, %{"label" => "", "kind" => "text", "value" => "", "unit" => ""}))
  end
  def remove(data, id), do: Map.put(data, "parameters", Map.delete(parameter_map(data["parameters"]), id))
end
