defmodule Waves.Journal do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :business_id, :source_id, :kind, :posted_on]}
  schema "journals" do
    field :business_id, :binary_id
    field :source_id, :binary_id
    field :kind, :string
    field :posted_on, :date
    timestamps(type: :utc_datetime_usec)
  end
end
