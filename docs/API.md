# API contract — implemented slice

Base: /api/v1. Header: Authorization: Bearer <business-key>.
Content-Type: application/json. Success: {"data": ...}.
Error: {"error":{"code":"...","message":"..."}}.
Money and quantity inputs must be strings. Clients must not use binary floating-point for accounting.

| Method | Path | Behaviour |
| --- | --- | --- |
| GET | /business | Current business |
| GET | /customers | Business customers |
| POST | /customers | Create customer |
| GET | /invoices | Latest 200 invoices |
| POST | /invoices | Create draft, no journal |
| POST | /invoices/:id/issue | Assign number and post receivable/sales |
| POST | /invoices/:id/payments | Record/allocate manual payment and post bank/receivable |
| GET | /ledger/entries | Latest 500 entries |

Customer:
```json
{"name":"Example Customer","email":"accounts@example.com"}
```
Draft invoice (customer_id comes from the customer response):
```json
{"customer_id":"<customer UUID>","due_date":"2026-11-17","lines":[{"description":"Development services","quantity":"1","unit_price":"10000.00"}]}
```
Payment:
```json
{"amount":"4000.00","reference":"BANK-20261017-001","received_on":"2026-10-17"}
```

Replay rule: the same business/reference/invoice/amount/date returns the existing payment.
Reusing the reference with a different payload returns reference_conflict (409).
Overpayments return overpayment (422); draft or already settled invoices reject new payments (409).
Foreign-business invoice commands return not_found (404).
Issue replay returns already_issued (409), without an additional journal.
Draft/customer creation has no idempotency guarantee yet.

Currency, business_id, status and discounts are not client-controlled fields in this slice.
The server computes totals and resolves business currency. Additional payload fields are ignored.
The issue date is currently the UTC posting date; configurable business date handling is pending.


## Added in 0.2

PATCH /api/v1/business updates the current business's settings. Allowed fields include company
identity/contact, invoice title/prefix, due-day defaults, tax_name/tax_rate/tax_mode, payment_details,
invoice_notes/invoice_terms/invoice_footer, accent_color/invoice_template, stamp display/size/position
and signatory text. Currency, invoice sequence, tenant ID and uploaded image bytes cannot be set here.
Images are managed through the LiveView upload form. GET /business excludes image bytes.

Invoice creation additionally accepts tax_name, tax_rate (decimal string), tax_mode
(none/exclusive/inclusive), notes and terms. Missing fields use the business defaults.
Settings changes do not recalculate previously created drafts.

```json
{"customer_id":"<customer UUID>","due_date":"2026-11-17","tax_name":"VAT","tax_rate":"16","tax_mode":"exclusive","notes":"Thank you for your business.","lines":[{"description":"Services","quantity":"1","unit_price":"10000.00"}]}
```

This is a hypothetical rate example, not a statutory rate recommendation.
Responses include subtotal, tax_total, tax_name, tax_rate, tax_mode and issue_date.
GET /api/v1/invoices/:id/pdf accepts a Bearer credential and returns application/pdf,
404 for a missing/foreign-business document, or 503 if rendering is unavailable.

Browser routes: /settings, /invoices/:id and /invoices/:id/pdf require the business session.


## Added in 0.3: catalogue and line parameters

GET/POST /api/v1/items list or create business-scoped items. PATCH /api/v1/items/:id updates an
item, including is_active. Item fields: code, name, description, category, item_type
(product/service/hire), unit_price, unit, billing_method and parameters. There is no hard-delete route.

A new invoice line can provide item_id to copy saved defaults, with explicit per-line overrides.
Foreign/inactive items are rejected. Resolved code, name, parameters and prices are saved on the
invoice; subsequent catalogue edits do not update it.

```json
{
  "description": "Microphone hire",
  "billing_method": "parameters",
  "unit_price": "10.00",
  "unit": "per microphone per day",
  "parameters": [
    {"label": "Microphones", "kind": "multiplier", "value": "4"},
    {"label": "Days", "kind": "multiplier", "value": "3"},
    {"label": "Venue", "kind": "text", "value": "Conference Hall"},
    {"label": "Hire date", "kind": "date", "value": "2026-10-20"}
  ]
}
```

This line totals 120 in the business currency. Quantity mode accepts quantity and unit_price as
before; fixed mode always charges one rate. Parameters mode derives effective quantity from all
multipliers. Total, effective quantity and all taxes are calculated server-side, not trusted from
client-supplied totals. Numeric inputs are decimal strings. Dates do not imply duration.

Invoice creation also accepts accent_color (a six-digit #hex string) as a per-document override.
