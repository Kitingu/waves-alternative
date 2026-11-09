# Upgrade 0.3 — catalogue and per-line billing

Keep your `.env`, `backend/mix.lock`, local configuration and database. Copy/merge the updated
source. Existing invoice, payment, tax, branding and PDF functionality is retained.
The migration adds a business-owned catalogue and an optional invoice colour override.
It does not recalculate existing invoices or rewrite their saved lines.

From your project root, load your trusted environment file:

```bash
set -a
. ./.env
set +a
cd backend
mix deps.get
mix ecto.migrate
mix assets.build
mix compile --warnings-as-errors
mix test
mix phx.server
```

Do not reset the database or rerun seeds. The previously reported toolbar test assertion is fixed
in this source. Your Chrome installation/configuration is still needed for direct PDF downloads.

## Create saved items

Open Products & services. Enter a unique business-specific code, name, type (product/service/hire),
category, description, rate and unit/rate description. Choose a billing method:

- Quantity × rate: the original quantity/unit-price workflow.
- Fixed charge: one agreed amount; quantity is treated as one.
- Line parameters × rate: multiply all declared charge multipliers by the rate.

Parameters have a label, purpose, default value and optional unit. Purpose is one of:

- Charge multiplier: positive decimal, up to four decimal places, contributes to the amount.
- Text detail: venue, equipment model, destination, instructions; does not affect price.
- Date detail: service/hire/check-in date; does not affect price or calculate duration automatically.

For a microphone hire item, set rate 10, billing method parameters, and defaults Microphones = 1,
Days = 1 (both charge multipliers). Save. You can edit or deactivate items; existing invoices keep
copies of their original values. Catalogue item codes are unique within each business.

## Declare parameters on each invoice line

Select a saved item or leave One-off line selected. Item selection copies its defaults to that
line only. Change its description/rate/method, and add or remove parameters independently:

| Line | Parameters | Rate | Amount |
| --- | --- | ---: | ---: |
| Microphone hire | Microphones 4 × Days 3 | 10 | 120 |
| Speaker hire | Speakers 2 × Days 3 | 40 | 240 |
| Delivery | Fixed charge | 30 | 30 |
| Tour | Days 3 | 150 | 450 |

The line amount updates while editing. Add Venue and Hire date as text/date details if required.
Those fields appear beneath the description in the downloaded invoice without affecting the amount.
To change a line to fixed or quantity billing, first remove any charge multipliers (or change them
to text/date details). The server rejects ambiguous billing rather than ignoring charge factors.

The invoice displays the individual factors in its Billing column, the rate separately, and
the calculated line amount. It does not flatten the document display to an unexplained quantity.
Line amounts are rounded half-up to two decimals after all factors are multiplied. Existing
invoice-level tax treatment applies after the line totals are added together.

## Invoice colours

Business settings retains the default Brand colour. The invoice form now also includes an
Invoice colour picker for a document-specific override. It is snapshotted on issue. Updating the
business colour later does not recolour that issued invoice. Stamp PNG colours are not recoloured.

## Scope and verification

This update retains business-currency billing (currently KES); choosing USD and exchange-rate
accounting are not implemented. The formulas are defined billing methods, not executable user
formulas. Up to 12 parameters per line and 100 lines per invoice are accepted. Tax remains
invoice-wide; item-specific/per-line tax and stock/asset availability tracking are separate work.
Dates are descriptive; enter the agreed chargeable duration explicitly.

New tests cover the tour calculation, independently priced hire lines, fixed charges, fractional
durations, invalid factors, catalogue ownership, copied defaults, inactive items, colour snapshots
and LiveView item selection. These new tests have not been run here: Elixir/PostgreSQL are unavailable.
Source/template/JavaScript/archive checks are not substitutes for the server's `mix test` result.
