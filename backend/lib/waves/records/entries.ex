defmodule Waves.Entry do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :business_id, :journal_id, :account, :debit, :credit]}
  schema "entries" do
    field :business_id, :binary_id
    field :journal_id, :binary_id
    field :account, :string
    field :debit, :decimal
    field :credit, :decimal
    timestamps(type: :utc_datetime_usec)
  end
end
