defmodule Waves.Business do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :name, :currency, :invoice_sequence, :legal_name, :address, :email, :phone, :website, :tax_id, :registration_number, :payment_details, :invoice_title, :invoice_prefix, :default_due_days, :invoice_notes, :invoice_terms, :invoice_footer, :accent_color, :invoice_template, :tax_name, :tax_rate, :tax_mode, :show_stamp, :show_signature, :stamp_width, :stamp_position, :signatory_name, :signatory_title]}
  schema "businesses" do
    field :name, :string
    field :currency, :string
    field :invoice_sequence, :integer, default: 0
    field :legal_name, :string
    field :address, :string
    field :email, :string
    field :phone, :string
    field :website, :string
    field :tax_id, :string
    field :registration_number, :string
    field :payment_details, :string
    field :invoice_title, :string, default: "INVOICE"
    field :invoice_prefix, :string, default: "INV-"
    field :default_due_days, :integer, default: 14
    field :invoice_notes, :string
    field :invoice_terms, :string
    field :invoice_footer, :string
    field :accent_color, :string, default: "#174f47"
    field :invoice_template, :string, default: "modern"
    field :tax_name, :string, default: "Tax"
    field :tax_rate, :decimal, default: Decimal.new(0)
    field :tax_mode, :string, default: "none"
    field :logo_data, :string
    field :stamp_data, :string
    field :signature_data, :string
    field :show_stamp, :boolean, default: true
    field :show_signature, :boolean, default: true
    field :stamp_width, :integer, default: 120
    field :stamp_position, :string, default: "right"
    field :signatory_name, :string
    field :signatory_title, :string
    field :country, :string, default: "Kenya"
    field :subscription_status, :string, default: "trial"
    field :subscription_expires_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)
  end
end
