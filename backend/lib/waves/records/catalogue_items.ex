defmodule Waves.CatalogueItem do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :code, :name, :description, :category, :item_type, :billing_method, :unit, :unit_price, :parameters, :is_active, :simple_billing, :uses_duration, :duration_unit, :default_notes]}
  schema "catalogue_items" do
    field :business_id, :binary_id
    field :code, :string
    field :name, :string
    field :description, :string
    field :category, :string
    field :item_type, :string, default: "service"
    field :billing_method, :string, default: "quantity"
    field :unit, :string, default: "Units"
    field :unit_price, :decimal
    field :parameters, {:array, :map}, default: []
    field :is_active, :boolean, default: true
    field :simple_billing, :boolean, default: false
    field :uses_duration, :boolean, default: false
    field :duration_unit, :string, default: "Days"
    field :default_notes, :string
    timestamps(type: :utc_datetime_usec)
  end
end
