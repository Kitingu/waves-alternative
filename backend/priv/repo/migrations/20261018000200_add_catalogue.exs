defmodule Waves.Repo.Migrations.AddCatalogue do
  use Ecto.Migration
  def change do
    alter table(:invoices) do
      add :accent_color_override, :text
    end
    create table(:catalogue_items) do
      add :business_id, references(:businesses), null: false
      add :code, :text, null: false
      add :name, :text, null: false
      add :description, :text
      add :category, :text
      add :item_type, :text, null: false, default: "service"
      add :billing_method, :text, null: false, default: "quantity"
      add :unit, :text, null: false, default: "Units"
      add :unit_price, :decimal, precision: 20, scale: 2, null: false
      add :parameters, {:array, :map}, null: false, default: []
      add :is_active, :boolean, null: false, default: true
      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:catalogue_items, [:business_id, :code])
    create constraint(:catalogue_items, :positive_catalogue_price, check: "unit_price > 0")
    create constraint(:catalogue_items, :valid_item_type, check: "item_type IN ('product','service','hire')")
    create constraint(:catalogue_items, :valid_billing_method, check: "billing_method IN ('fixed','quantity','parameters')")
  end
end
