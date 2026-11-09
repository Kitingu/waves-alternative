# Product specification and build plan

## Objective

A self-hosted financial platform, usable directly through LiveView and reusable through its JSON API.
Wave is the functional benchmark. Equivalent workflows will have an original interface and implementation.
Full parity remains a roadmap, not a claim about this starter.

## Architecture decisions

- One Phoenix application, LiveView interface, PostgreSQL and Ecto.
- Shared business contexts serve the browser and integration API.
- A person may belong to multiple businesses. Applications connect to specific businesses.
- Financial records carry business_id. Ownership must be checked at every query and command.
- Store decimal amounts; accept monetary API values as decimal strings.
- Store a historical snapshot of document lines, prices, taxes and customer details when issued.
- Post financial events transactionally, correct issued records through credit/reversal workflows.
- Store files in object storage later; queue email, schedules and webhook delivery in background jobs.
- Start as a modular monolith. Do not split into microservices at this stage.

## Implemented in 0.1, awaiting runtime verification

Business and API-key schemas; customer creation; draft invoices; serial invoice numbering;
issue and payment transactions; partial/full settlement; payment-reference replay protection;
minimal ledger entries; tenant-scoped API; LiveView customer/invoice/payment/ledger screens.

## Implemented in 0.2, awaiting server verification

Business details, document text and style settings; PNG logo/stamp/signature uploads;
three document layouts; invoice preview and PDF routes; tax inclusive/exclusive calculations;
tax payable journal entries; multi-line LiveView editor; customer billing details; issued snapshots.
Read UPGRADE-0.2.md before applying the new migration.

## Next milestone: production access and business setup

1. Generate Phoenix individual-user authentication, password reset, verified sessions and logout.
2. Add business memberships, invitations and owner/accountant/operator/read-only roles.
3. Replace the development credential login; API keys remain integration credentials only.
4. Enforce authorization in a shared scope object used by contexts and LiveView mounts/events.
5. Add business details, address, timezone, fiscal year, branding and tax configuration.
6. Add integration-key scopes, revocation, rotation and audit attribution.
7. Validate migrations, tests, WebSocket access and a restored backup on the development server.

Acceptance: a user can access only assigned businesses; permission changes take effect;
revoked credentials fail; business switching cannot leak financial records.

## Milestone: usable invoicing release

Customer detail screens and addresses; catalogue; multi-line editor; explicit issue date;
configurable numbering; tax/discount rounding policy; draft updates and cancellation;
issued customer snapshots; PDF output; customer statement; credit notes and refunds;
payment history; search/filter/pagination; receivables ageing; configurable ledger accounts;
trial balance and immutable journal controls.

Acceptance: a customer statement reconciles to the ledger; draft edits do not post;
issued records cannot be silently rewritten; reversals remain visible; monetary totals match PDFs.

## Milestone: first project integration

Choose a real project, then implement external references and payload-bound idempotency keys;
customer upsert; invoice creation/status; payment registration; signed, retryable webhooks;
transactional outbox; delivery history; documented versioned API and integration tests.

Acceptance: retrying a request creates one document; retries with different payloads conflict;
webhooks can be safely processed more than once; the originating project can reconcile balances.

## Milestone: Wave migration

Obtain representative exports. Build staging, mappings, duplicate detection, preview, validation,
transaction-to-document linking and reconciliation. Preserve source IDs and original source files.
No notification, collection, recurring schedule or fiscalisation side effects during import.

Acceptance: agreed source totals and document counts match; every rejected row is explained;
rerunning does not duplicate records; no invoice revenue is posted twice.

## Remaining full-product roadmap

- Estimates, approval/acceptance and invoice conversion.
- Recurring invoicing, reminders, customer payment pages and configurable branding.
- Supplier bills, expenses, recurring bills, purchases and supplier statements.
- Bank statement import, matching, splits, reconciliation and categorisation rules.
- Receipt upload, extraction, review, matching and duplicate detection.
- Profit and loss, balance sheet, general ledger, trial balance, cash flow and tax summaries.
- Payment-provider adapters, refunds, fees, settlements and payout reconciliation.
- Country-specific tax/fiscal integration and payroll as separately validated modules.
- Mobile-friendly workflows, data exports, operational administration and observability.

Banking, payment services and payroll filing require providers and country-specific work.
No delivery date is committed before the first deployment and scope audit.

## Evidence needed from Benedict

Development-server access or runtime error output; first integration project;
representative Wave accounting and invoice exports; business branding; intended countries/currencies.
Work on the foundation does not depend on those being provided immediately.


## Implemented in 0.3, awaiting server verification

Business-scoped saved catalogue, product/service/hire types, configurable default parameters,
per-line item selection and overrides, fixed/quantity/multiplier calculations, descriptive text/date
fields, printed billing breakdowns, inactive-item handling and per-invoice accent colours.
See UPGRADE-0.3.md. Foreign-currency accounting remains a separate milestone.
