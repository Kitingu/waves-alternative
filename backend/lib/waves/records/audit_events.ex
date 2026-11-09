defmodule Waves.Audit do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :business_id, :api_key_id, :action, :record_id]}
  schema "audit_events" do
    field :business_id, :binary_id
    field :api_key_id, :binary_id
    field :user_id, :binary_id
    field :action, :string
    field :record_id, :binary_id
    timestamps(type: :utc_datetime_usec)
  end
end
