defmodule Waves.Invoice do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :business_id, :customer_id, :number, :currency, :status, :due_date, :lines, :total, :paid, :issue_date, :subtotal, :tax_total, :tax_name, :tax_rate, :tax_mode, :accent_color_override, :notes, :terms, :lock_version, :payment_count, :last_payment_method, :last_payment_date]}
  schema "invoices" do
    field :business_id, :binary_id
    field :customer_id, :binary_id
    field :number, :string
    field :currency, :string
    field :status, :string, default: "draft"
    field :due_date, :date
    field :lines, {:array, :map}
    field :total, :decimal
    field :paid, :decimal, default: Decimal.new("0")
    field :issue_date, :date
    field :subtotal, :decimal
    field :tax_total, :decimal, default: Decimal.new(0)
    field :tax_name, :string, default: "Tax"
    field :tax_rate, :decimal, default: Decimal.new(0)
    field :tax_mode, :string, default: "none"
    field :accent_color_override, :string
    field :notes, :string
    field :terms, :string
    field :business_snapshot, :map
    field :customer_snapshot, :map
    field :lock_version, :integer, default: 1
    field :payment_count, :integer, virtual: true
    field :last_payment_method, :string, virtual: true
    field :last_payment_date, :date, virtual: true
    timestamps(type: :utc_datetime_usec)
  end
end
