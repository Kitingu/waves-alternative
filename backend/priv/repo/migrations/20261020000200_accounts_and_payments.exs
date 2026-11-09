defmodule Waves.Repo.Migrations.AccountsAndPayments do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :text, null: false
      add :email, :text, null: false
      add :password_hash, :text, null: false
      add :confirmed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:users, [:email])
    create table(:memberships) do
      add :user_id, references(:users), null: false
      add :business_id, references(:businesses), null: false
      add :role, :text, null: false, default: "owner"
      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:memberships, [:user_id, :business_id])
    create constraint(:memberships, :valid_membership_role, check: "role IN ('owner','staff','accountant')")
    create table(:user_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token_hash, :text, null: false
      add :purpose, :text, null: false
      add :expires_at, :utc_datetime_usec, null: false
      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:user_tokens, [:token_hash, :purpose])
    alter table(:businesses) do
      add :country, :text, default: "Kenya", null: false
      add :subscription_status, :text, default: "trial", null: false
      add :subscription_expires_at, :utc_datetime_usec
    end
    create constraint(:businesses, :valid_subscription_status, check: "subscription_status IN ('trial','active','past_due')")
    alter table(:invoices) do
      add :lock_version, :integer, default: 1, null: false
    end
    alter table(:payments) do
      add :method, :text, default: "unknown", null: false
      add :notes, :text
    end
    create constraint(:payments, :valid_payment_method, check: "method IN ('cash','mpesa','bank_transfer','card','cheque','other','unknown')")
    alter table(:audit_events) do
      modify :api_key_id, :uuid, null: true
      add :user_id, references(:users)
    end
  end
end
