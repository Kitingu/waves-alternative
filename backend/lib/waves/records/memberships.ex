defmodule Waves.Membership do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "memberships" do
    field :user_id, :binary_id
    field :business_id, :binary_id
    field :role, :string, default: "owner"
    timestamps(type: :utc_datetime_usec)
  end
end
