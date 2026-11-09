defmodule Waves.ApiKey do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :business_id, :token_hash, :name]}
  schema "api_keys" do
    field :business_id, :binary_id
    field :token_hash, :string
    field :name, :string
    timestamps(type: :utc_datetime_usec)
  end
end
