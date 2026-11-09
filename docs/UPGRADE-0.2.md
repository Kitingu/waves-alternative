# Upgrade your running 0.1 project

This is an additive database upgrade. Existing customers, invoices, payments, journal entries,
business credentials and numbering sequences are retained. Back up your development database first.

## Apply the code

Copy the updated source over your project. Keep your local `.env`, `backend/mix.lock` and any local
configuration changes. The archive contains no environment secrets, compiled assets, deps or database.
If you modified source files, merge the changes rather than replacing your work blindly.

New key paths:

- backend/priv/repo/migrations/20261018000100_add_invoice_customization.exs
- backend/lib/waves/settings.ex and brand_asset.ex
- backend/lib/waves/invoice_document.ex and invoice_document/invoice.html.eex
- backend/lib/waves/invoice_pdf.ex
- backend/lib/waves_web/settings_live.ex and settings_live/index.html.heex
- backend/lib/waves_web/invoice_controller.ex
- backend/priv/static/assets/invoice.css

Existing schemas, finance context, LiveView, API controller, router, application, Mix dependencies,
configuration and app.css also have changes. The original foundation migration is unchanged.

## Load environment and upgrade

From your project root:

```bash
set -a
. ./.env
set +a
cd backend
mix deps.get
mix ecto.migrate
mix assets.build
mix format
mix compile --warnings-as-errors
mix test
mix phx.server
```

If esbuild was never installed, run `mix assets.setup` before `mix assets.build`.
Do not run `mix ecto.reset`, delete records, or rerun seeds for this upgrade.
Retain and commit the resolved mix.lock after dependency resolution.

## Chrome / PDF

Install Chrome or Chromium on the machine running Phoenix. If needed, set CHROME_EXECUTABLE
in the shell or `.env` (quote paths containing spaces). The executable is optional for starting
Phoenix, but required for the direct PDF download button. Browser Print / Save as PDF is a fallback.

## First use

1. Restart Phoenix, reload the page and open Business settings.
2. Enter legal/display names, address, contact, registration and tax details.
3. Enter your tax label/rate and choose whether unit prices include tax.
4. Choose a layout and accent colour; enter payment instructions, notes, terms and footer.
5. Upload a PNG logo, transparent stamp and optional signature. Set size, position and signatory.
6. Save. Create a new multi-line invoice and check taxes before issuing.
7. Open View, download a PDF and compare its totals with the invoice and ledger.

Settings changes apply to new document defaults. Already-issued documents retain their saved
branding. Existing drafts keep their existing amounts and tax settings; recreate a draft if you
want different tax treatment (draft editing is not yet available).

## Legacy records

The migration fills subtotal = existing total and tax = 0. It does not rewrite old payments or journals.
For already-issued invoices it captures the company/customer details known at upgrade time and
marks the snapshot legacy_upgrade. Its issue date is approximated from the old creation date,
because 0.1 did not store an actual issue date. It cannot recover historical branding that was never saved.

## Server acceptance checks

- `mix test` covers original invoice/payment behaviour, tax maths, snapshot preservation,
  settings validation, PNG upload, and cross-business preview/download access.
- Test an exclusive tax invoice and an inclusive tax invoice using a rate appropriate for your business.
- Change company details/logo/stamp after issue; confirm the old document is unchanged.
- Remove a saved stamp; confirm old invoices retain it and new invoices do not.
- Print a long address, multiline terms and a long invoice; inspect every PDF page for wrapping.
- Confirm tax payable + sales credits equal the receivables debit.
- Verify missing Chrome produces a useful response and the browser print fallback works.

These checks have not been run in the creation environment because its Elixir/database/browser
runtimes are unavailable. Do not treat source-only checks as a passing server test run.


## Generate design samples without posting invoices

From `backend`, `mix run priv/repo/render_invoice_samples.exs` creates three HTML samples under
`tmp/invoice-samples`. They use the same document renderer and styles as the application.
Open each HTML file in your browser and use Print to inspect pagination.

Optional environment variables: SAMPLE_LOGO_PATH, SAMPLE_STAMP_PATH and SAMPLE_SIGNATURE_PATH
accept local PNG files. Set SAMPLE_LONG_INVOICE=1 for an 80-line invoice.
Set RENDER_SAMPLE_PDFS=1 to also render actual PDFs through Chrome. These are clearly labelled
design samples; the script does not insert customers, invoices, payments or journal entries.
