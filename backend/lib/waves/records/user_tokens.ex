defmodule Waves.UserToken do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "user_tokens" do
    field :user_id, :binary_id
    field :token_hash, :string
    field :purpose, :string
    field :expires_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)
  end
end
