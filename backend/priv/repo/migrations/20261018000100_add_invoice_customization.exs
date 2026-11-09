defmodule Waves.Repo.Migrations.AddInvoiceCustomization do
  use Ecto.Migration
  def up do
    alter table(:businesses) do
      add :legal_name, :text
      add :address, :text
      add :email, :text
      add :phone, :text
      add :website, :text
      add :tax_id, :text
      add :registration_number, :text
      add :payment_details, :text
      add :invoice_title, :text, default: "INVOICE", null: false
      add :invoice_prefix, :text, default: "INV-", null: false
      add :default_due_days, :integer, default: 14, null: false
      add :invoice_notes, :text
      add :invoice_terms, :text
      add :invoice_footer, :text
      add :accent_color, :text, default: "#174f47", null: false
      add :invoice_template, :text, default: "modern", null: false
      add :tax_name, :text, default: "Tax", null: false
      add :tax_rate, :decimal, precision: 7, scale: 4, default: 0, null: false
      add :tax_mode, :text, default: "none", null: false
      add :logo_data, :text
      add :stamp_data, :text
      add :signature_data, :text
      add :show_stamp, :boolean, default: true, null: false
      add :show_signature, :boolean, default: true, null: false
      add :stamp_width, :integer, default: 120, null: false
      add :stamp_position, :text, default: "right", null: false
      add :signatory_name, :text
      add :signatory_title, :text
    end
    alter table(:customers) do
      add :address, :text
      add :phone, :text
      add :tax_id, :text
    end
    alter table(:invoices) do
      add :issue_date, :date
      add :subtotal, :decimal, precision: 20, scale: 2
      add :tax_total, :decimal, precision: 20, scale: 2, null: false, default: 0
      add :tax_name, :text, null: false, default: "Tax"
      add :tax_rate, :decimal, precision: 7, scale: 4, null: false, default: 0
      add :tax_mode, :text, null: false, default: "none"
      add :notes, :text
      add :terms, :text
      add :business_snapshot, :map
      add :customer_snapshot, :map
    end
    # The starter had no historical branding. Preserve the details known at upgrade time.
    execute """
    UPDATE invoices i SET subtotal = i.total,
      issue_date = CASE WHEN i.status <> 'draft' THEN i.inserted_at::date ELSE NULL END,
      business_snapshot = CASE WHEN i.status <> 'draft' THEN
        (to_jsonb(b) - 'invoice_sequence') || '{"snapshot_origin":"legacy_upgrade"}'::jsonb ELSE NULL END,
      customer_snapshot = CASE WHEN i.status <> 'draft' THEN to_jsonb(c) ELSE NULL END
    FROM businesses b, customers c WHERE b.id = i.business_id AND c.id = i.customer_id
    """
    alter table(:invoices) do
      modify :subtotal, :decimal, precision: 20, scale: 2, null: false
    end
    create constraint(:invoices, :invoice_totals_match, check: "subtotal >= 0 AND tax_total >= 0 AND subtotal + tax_total = total")
    create constraint(:invoices, :valid_tax_configuration, check: "tax_rate >= 0 AND tax_rate <= 100 AND tax_mode IN ('none', 'exclusive', 'inclusive')")
    create constraint(:businesses, :valid_business_tax, check: "tax_rate >= 0 AND tax_rate <= 100 AND tax_mode IN ('none', 'exclusive', 'inclusive')")
  end
  def down do
    raise "This migration preserves issued invoice history. Restore a verified backup instead of dropping invoice snapshots."
  end
end
