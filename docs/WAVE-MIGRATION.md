# Wave migration design — not yet implemented

## Source collection

Export Accounting and Receipts from each business separately. Obtain invoice, catalogue and
chart-of-accounts detail using Wave Connect or supported API access where available.
Retain source reports for the same cutoff date and currency basis.
Inspect the actual files before promising field coverage; exports are not a complete account backup.

## Import stages

1. Record the source business, source files, file hashes and an import-batch ID.
2. Parse into staging records, preserving raw rows and source IDs.
3. Map accounts, customers, suppliers, taxes, currencies and document relationships.
4. Preview record counts, totals, errors and duplicate candidates without changing live records.
5. Validate decimals, dates, referenced entities and source totals.
6. Import using an explicit historical mode without email, payment collection or schedule triggers.
7. Reconcile trial balance, receivables, payables and document counts at the cutoff date.
8. Record an approval/checkpoint, then switch new transactions to the new application.

## Avoid double posting

Choose a documented accounting strategy per imported record: import historical journals as the
ledger authority and link operational documents without posting again, or recreate supported
financial events and omit their duplicate source journals. Never mix these implicitly.
Opening-balance migration is a separate option, not a substitute for full-history migration
when the business needs historical reporting.

## Proposed tables for the migration milestone

import_batches, import_files, import_rows, import_mappings and source_record_links.
Unique source links: business_id + source_system + source_business_id + entity_type + source_id.
Do not use a customer name or invoice number alone as the source identity.

## Not assumed portable

Stored payment credentials, payment authorisations, bank connections, schedules, audit activity,
users and permissions need individual assessment. Preserve original PDFs/files where available;
regenerated output must not pretend to be the original issued document.

## First required sample

One accounting export, invoice detail with unpaid/partial/paid examples, and matching balance reports.
Use a trial database and disabled outbound integrations for the first migration.
