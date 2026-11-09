defmodule Waves.Repo.Migrations.CreateFoundation do
  use Ecto.Migration
  def change do
    create table(:businesses) do
      add :name, :text, null: false
      add :currency, :string, size: 3, null: false
      add :invoice_sequence, :bigint, null: false, default: 0
      timestamps(type: :utc_datetime_usec)
    end
    create table(:api_keys) do
      add :business_id, references(:businesses), null: false
      add :name, :text, null: false
      add :token_hash, :text, null: false
      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:api_keys, [:token_hash])
    create table(:customers) do
      add :business_id, references(:businesses), null: false
      add :name, :text, null: false
      add :email, :text
      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:customers, [:business_id, :id])
    create table(:invoices) do
      add :business_id, references(:businesses), null: false
      add :customer_id, references(:customers, with: [business_id: :business_id]), null: false
      add :number, :text
      add :currency, :string, size: 3, null: false
      add :status, :text, null: false, default: "draft"
      add :due_date, :date, null: false
      add :lines, {:array, :map}, null: false
      add :total, :decimal, precision: 20, scale: 2, null: false
      add :paid, :decimal, precision: 20, scale: 2, null: false, default: 0
      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:invoices, [:business_id, :id])
    create unique_index(:invoices, [:business_id, :number])
    create constraint(:invoices, :valid_invoice_amounts, check: "total > 0 AND paid >= 0 AND paid <= total")
    create constraint(:invoices, :valid_invoice_status, check: "status IN ('draft', 'issued', 'paid')")
    create table(:payments) do
      add :business_id, references(:businesses), null: false
      add :invoice_id, references(:invoices, with: [business_id: :business_id]), null: false
      add :amount, :decimal, precision: 20, scale: 2, null: false
      add :reference, :text, null: false
      add :received_on, :date, null: false
      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:payments, [:business_id, :reference])
    create constraint(:payments, :positive_payment, check: "amount > 0")
    create table(:journals) do
      add :business_id, references(:businesses), null: false
      add :source_id, :uuid, null: false
      add :kind, :text, null: false
      add :posted_on, :date, null: false
      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:journals, [:business_id, :id])
    create unique_index(:journals, [:business_id, :source_id, :kind])
    create table(:entries) do
      add :business_id, references(:businesses), null: false
      add :journal_id, references(:journals, with: [business_id: :business_id]), null: false
      add :account, :text, null: false
      add :debit, :decimal, precision: 20, scale: 2, null: false
      add :credit, :decimal, precision: 20, scale: 2, null: false
      timestamps(type: :utc_datetime_usec)
    end
    create constraint(:entries, :one_positive_side, check: "(debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)")
    create table(:audit_events) do
      add :business_id, references(:businesses), null: false
      add :api_key_id, references(:api_keys), null: false
      add :action, :text, null: false
      add :record_id, :uuid, null: false
      timestamps(type: :utc_datetime_usec)
    end
  end
end
