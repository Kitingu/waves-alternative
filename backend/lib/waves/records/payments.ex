defmodule Waves.Payment do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :business_id, :invoice_id, :amount, :reference, :received_on, :method, :notes]}
  schema "payments" do
    field :business_id, :binary_id
    field :invoice_id, :binary_id
    field :amount, :decimal
    field :reference, :string
    field :received_on, :date
    field :method, :string, default: "unknown"
    field :notes, :string
    timestamps(type: :utc_datetime_usec)
  end
end
