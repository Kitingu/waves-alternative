# Waves Alternative — LiveView 0.3

Phoenix + LiveView + PostgreSQL, with a JSON API for other applications.
Existing customer, invoice, payment and ledger flows are retained.

## Upgrading your running starter

Read **docs/UPGRADE-0.3.md** first (and UPGRADE-0.2.md if upgrading from 0.1). Keep your own `.env`, `mix.lock` and database.
There is one new migration per upgrade milestone. Do not drop the database or rerun setup to apply this upgrade.

## New in 0.3

Saved products/services/hire catalogue; independent parameters on each invoice line;
fixed, quantity and multiplier billing; descriptive text/date parameters; live line amounts;
billing breakdowns in previews/PDFs; and an invoice-specific colour picker.
See docs/UPGRADE-0.3.md for usage and examples.

## Included from 0.2

- Business settings at `/settings`: display/legal name, contact/address, tax registration,
  company registration, payment instructions and invoice text.
- Number prefix, due-day defaults, document title, brand colour and Modern/Classic/Minimal styles.
- PNG logo, company stamp and signature uploads; image removal; signatory name and role;
  stamp visibility, width and left/centre/right placement.
- Tax name and rate, no-tax / tax-exclusive / tax-inclusive modes, with invoice overrides.
- Multi-line LiveView invoice editor, customer billing address, phone and tax registration.
- Issued invoice branding and recipient snapshots; later settings changes do not restyle old invoices.
- Invoice preview, direct PDF download, and browser Print / Save as PDF fallback.
- Net sales and tax payable posted separately, preserving balanced entries.

## First-time setup

Requirements: Elixir 1.17+ compatible 1.x, Erlang/OTP compatible with your Elixir,
PostgreSQL 16, and Hex/esbuild download access. Chrome or Chromium is needed for direct PDFs.
Node/npm are not required. See `.env.example`; quote values containing spaces.

```bash
cp -n .env.example .env
```

Edit `.env` and provide a random bootstrap key (`openssl rand -hex 32`). Load your trusted file:

```bash
set -a
. ./.env
set +a
```

Use your PostgreSQL installation, or optionally `docker compose up -d postgres`.
The database account must be able to create the development/test databases.

```bash
cd backend
mix local.hex --force
mix local.rebar --force
mix setup
mix assets.setup
mix assets.build
mix format
mix compile --warnings-as-errors
mix test
mix phx.server
```

Open http://localhost:4000/connect and use your local bootstrap key. Start with Business settings,
add a customer, create/issue an invoice, then use View or PDF. Verify a partial and full payment.
`mix setup` only reuses a business when its bootstrap key matches; it is not a key-rotation command.

## PDF renderer

ChromicPDF starts in on-demand, offline mode with document JavaScript disabled.
The HTML embeds PNG images and uses local system fonts; no remote asset URLs are rendered.
Install Chrome/Chromium for your operating system. If auto-discovery fails, set its binary path
in CHROME_EXECUTABLE before starting Phoenix. Example for an existing Mac Chrome installation:

```bash
export CHROME_EXECUTABLE="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
```

The application can still start without Chrome. A missing renderer returns a useful 503 response;
View invoice > Print / Save as PDF remains available. No sandbox-disable flag is added.

[Renderer documentation](https://hexdocs.pm/chromic_pdf/ChromicPDF.html)

## Verification status

JavaScript syntax, source/template structure, PNG fixture validation, archive integrity and
upgrade preservation checks were run in the creation environment. Elixir/Erlang, PostgreSQL
and Chrome were unavailable there. New ExUnit checks for 0.3 are included but have NOT been executed. The user compiled and migrated 0.2 and reported 20/21 passing tests; the remaining toolbar assertion is corrected in this source.
The new LiveView/settings/upload flows and actual PDF rendering require verification on your
server. Existing 0.1 screens were confirmed working by the user; that does not verify this update.

## Financial and product boundaries

- KES/two-decimal amounts remain the starting currency. Currency conversion is not implemented.
- One configurable percentage tax applies to the whole invoice. Multiple/compound/withholding
  and per-line tax rules, exemptions and fiscal reporting are separate future work.
- No tax rate or statutory treatment is assumed or automatically updated.
- Tax is rounded once on the sum of individually rounded line amounts, using decimal half-up.
- Existing drafts keep their saved tax/amounts; settings changes never silently reprice them.
- Pre-upgrade issued invoices use the identity available during migration, marked legacy_upgrade;
  the old starter did not retain the original historical identity or exact issue date.
- Payment status/balance in a new PDF reflects current payments, while issued identity and totals stay fixed.
- PNG assets are stored in the database and copied into document snapshots (500 KB each maximum).
  This keeps historical assets independent of settings changes; include database storage in capacity planning.
- Initial accounts: 1000 Bank, 1100 Receivables, 2100 Tax payable, 4000 Sales.
- The ledger view is capped at 500 rows, invoices at 200. Pagination and full reports remain pending.
- Individual users/roles and production browser access are still pending. Bootstrap login is development-only.
- Posted records are protected by application flows; full database immutability controls are pending.
- There are no credit notes, refunds, estimates, email sending, reminders, gateways or Wave importer yet.

See docs/BUILD-PLAN.md, docs/API.md and docs/WAVE-MIGRATION.md for the broader roadmap.
