defmodule Waves.Repo.Migrations.SimplifyItemDefaults do
  use Ecto.Migration

  def change do
    alter table(:catalogue_items) do
      add :simple_billing, :boolean, default: false, null: false
      add :uses_duration, :boolean, default: false, null: false
      add :duration_unit, :text, default: "Days", null: false
      add :default_notes, :text
    end
  end
end
