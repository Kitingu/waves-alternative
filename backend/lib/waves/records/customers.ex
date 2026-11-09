defmodule Waves.Customer do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :business_id, :name, :email, :address, :phone, :tax_id]}
  schema "customers" do
    field :business_id, :binary_id
    field :name, :string
    field :email, :string
    field :address, :string
    field :phone, :string
    field :tax_id, :string
    timestamps(type: :utc_datetime_usec)
  end
end
