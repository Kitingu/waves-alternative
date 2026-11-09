defmodule Waves.User do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :name, :string
    field :email, :string
    field :password_hash, :string
    field :confirmed_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)
  end
end
