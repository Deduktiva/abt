# Multi Issuer Company Support — Investigation & Plan

Status: **proposal — decisions pending**. This documents the investigation into
removing the `IssuerCompany` singleton, the design options with tradeoffs, and
a phased migration plan. Nothing here is implemented yet.

## Goal

- Users can create and work with multiple `IssuerCompany` records.
- In a browser tab, one issuer company is picked and stays selected for that
  tab ("global context per tab").
- Almost all existing business objects are assigned to exactly one issuer
  company.

## Current state

`IssuerCompany.get_the_issuer!` returns `where(active: true).first`. The
singleton is enforced by a unique index on `issuer_companies.active` and by
convention (`CLAUDE_WORKFLOW.md`: "Single IssuerCompany per installation").

The issuer row carries three distinct kinds of state, which is why it leaks
everywhere:

1. **Legal/branding identity** — legal name, address, VAT ID, bank account,
   logos, accent color, document footers, contact lines.
2. **Money conventions** — `currency`, `money_decimal_places`.
3. **Operational policy** — `offer_validity_days`, `vat_id_recheck_days`,
   `document_email_from/reply_to/auto_bcc`, `reporting_email`.

### Call-site inventory (23 app call sites of `get_the_issuer!`)

| Category | Sites | Notes |
|---|---|---|
| Request context | `layouts/application.html.haml`, `ApplicationHelper#current_currency` / `#current_money_decimal_places`, `HomeController`, `ConfigurationsController` (via view), `IssuerCompaniesController` | Resolve per request; becomes `Current.issuer_company` |
| Document pipeline | `InvoicesController#publish/#preview`, `DeliveryNotesController#publish/#preview`, `OffersController#preview/#send_offer` | Good news: `InvoicePublisher`, `OfferSender`, all renderers **already take the issuer as a constructor argument** — only the controllers resolve it globally |
| Model-level lookups | `Invoice#money_decimal_places`, `Invoice#publish_warnings`, `Offer#default_validity_days`, `OfferMilestoneScaffolder`, views (`customers/_form`, `customers/show`) | Must derive from the record's own issuer, not ambient state |
| Mailers | `ApplicationMailer#setup_issuer` (from/bcc/reply-to + layout branding) | Resolved in `initialize` — must become per-message |
| Background jobs | `RefreshStaleVatVerificationsJob`, report jobs via mailers (`reporting_email`) | Must iterate issuers |
| Customer portal | `CustomerPortal::BaseController#set_issuer` | Token identifies a delivery note → issuer derivable |
| VIES | `ViesVerifier#run!` (requester VAT ID) | Derive from the customer's issuer |

### Existing patterns to build on

- **Team scoping** (`TeamOwned`, `ScopedThroughCustomer`) is the in-repo
  precedent for row scoping: explicit `visible_to(user)` scopes plus
  validations that read `Current.user`, so a new controller cannot "forget"
  to authorize. No `default_scope` magic.
- **`Current`** (`ActiveSupport::CurrentAttributes`) already exists with
  `user` and `session`.
- Documents already **snapshot** customer data at publish time; adding a
  denormalized `issuer_company_id` on documents fits that philosophy.

## Target data model

### Tables that get `issuer_company_id` (NOT NULL FK after backfill)

| Table | Why direct (not derived) |
|---|---|
| `customers` | Primary tenant anchor; matchcode uniqueness becomes per-issuer |
| `projects` | Team-scoped today, needs issuer to constrain pickers |
| `products` | Catalog is issuer-specific (pricing, tax class references) |
| `sales_tax_customer_classes`, `sales_tax_product_classes`, `sales_tax_rates` | Tax config is a function of the issuer's country/registration |
| `document_numbers` | Numbering ranges are per legal entity — legally required separation |
| `invoices`, `delivery_notes`, `offers` | Legal documents: issuer must be frozen on the row, not derived through a mutable customer association |

### Derived through parent (no column)

`invoice_lines`, `invoice_tax_classes`, `delivery_note_lines`,
`offer_versions`, `offer_milestones`, `customer_contacts`,
`customer_contact_projects`, `customer_vat_verifications`,
`acceptance_submissions`, `attachments` (reachable only through parent
documents; `AttachmentsController#authorize_attachment!` already authorizes
through the parent).

### Stays global

`users`, `user_*`, `groups`, `group_permissions`, `teams`,
`team_memberships`, `languages`, framework tables. (See Decision C.)

### Uniqueness that must move from global to per-issuer

- `invoices.document_number`, `delivery_notes.document_number`,
  `offers.document_number` → unique on `[issuer_company_id, document_number]`
- `document_numbers.code` (implicit today) → unique `[issuer_company_id, code]`
- `customers` / `projects` `LOWER(matchcode)` → unique per issuer
  (raw SQL index, as today)
- `sales_tax_product_classes` partial unique `is_default` → per issuer
- `issuer_companies.active` unique index → **dropped**; `active` becomes an
  ordinary archive flag

### Cross-tenant integrity

New `IssuerScoped` model concern mirroring `TeamOwned`:

- `belongs_to :issuer_company`
- `scope :for_issuer, ->(issuer) { where(issuer_company: issuer) }`
- Validation on write: referenced records (customer, project, product,
  sales-tax classes, converted invoice/delivery-note) must belong to the same
  issuer. Reads `Current.issuer_company` where appropriate; skips in system
  contexts, same as `TeamOwned#validate_team_assignment`.

`DocumentNumber.get_next_for(code, date)` →
`DocumentNumber.get_next_for(issuer, code, date)` (row lock unchanged, now on
the per-issuer row).

## Decision A — how the selected company travels (the per-tab requirement)

### Option A1: URL path scoping (recommended)

Mount the issuer-scoped app surface under a path segment, e.g.
`/c/:issuer_company_id/...`:

```ruby
constraints(AppHostConstraint.new) do
  # unscoped: session, invites, account/*, users, groups, teams,
  # user_invites, jobs_status, issuer company management, root picker
  scope "c/:issuer_company_id" do
    root "home#index", as: :company_root
    resources :customers ... # invoices, offers, products, sales_tax_*, etc.
  end
end
```

- `ApplicationController` gains `set_current_issuer` (before_action on scoped
  controllers): loads the issuer from `params[:issuer_company_id]`, 404s on
  unknown/archived, sets `Current.issuer_company`.
- `default_url_options` injects `issuer_company_id: Current.issuer_company`
  so existing `*_path` helpers keep working — the bulk of views need **no**
  changes.
- Root `/` redirects to the last-used company (plain cookie) or shows a
  picker; navbar gets a company switcher (plain links, so middle-click /
  "open in new tab" naturally starts a tab in another company).

Tradeoffs:
- **Pro:** The URL *is* the tab state — the only mechanism that genuinely
  satisfies "per browser tab". Bookmarkable, sharable, no hidden state, no
  tab desync, Turbo-safe, zero JS.
- **Pro:** Fits the existing explicit-over-implicit style (host-constrained
  routes, explicit permission checks).
- **Con:** Largest routing diff; every scoped controller must consistently
  scope finds through `Current.issuer_company` (mitigated by the
  `IssuerScoped` guard validations and controller-level `for_issuer` usage).
- **Con:** Old bookmarks break → mitigate with redirect shims from legacy
  paths to the default company during a transition release.

### Option A2: session-stored selection + switcher

Store `selected_issuer_company_id` in the Rails session; navbar dropdown to
switch.

- **Pro:** Tiny diff; no route changes.
- **Con:** **Fails the stated requirement.** Sessions are per-browser, not
  per-tab: switching company in tab 1 silently retargets tab 2 — the next
  "Create invoice" in tab 2 lands in the wrong company's books. For an
  accounting app this is a correctness hazard, not a UX nit.

### Option A3: subdomain per company

- **Pro:** Per-tab for free; hard isolation.
- **Con:** Conflicts with the deployment model: `config.hosts` from
  `Settings.app.host`, `AppHostConstraint`/customer-portal host pair, Apache
  vhost + cert per company, and WebAuthn `rp_id` is host-scoped (passkeys
  would need the registrable-domain rp_id, plus per-host origins). Heavy
  operational cost for a self-hosted app. Rejected.

**Recommendation: A1.** A2 is only acceptable if the per-tab requirement is
dropped.

## Decision B — scoping mechanism

### Option B1: explicit scopes, hand-rolled (recommended)

`IssuerScoped` concern + explicit `.for_issuer(Current.issuer_company)` in
controllers, exactly parallel to `TeamOwned.visible_to` — visibility becomes
`Model.for_issuer(issuer).visible_to(user)`.

- **Pro:** Matches the codebase's existing team-scoping idiom; no hidden
  query mutation; easy to audit; write-side validations catch forgotten
  scoping at request time (same trick as `verify_permission_check_performed`).
- **Con:** Each controller/query site must be touched (~15 controllers);
  a forgotten `for_issuer` on a read is a data leak between companies —
  mitigated by tests with two fixtures companies.

### Option B2: `acts_as_tenant` (or default_scope keyed on Current)

- **Pro:** Automatic filtering; hard to forget on reads.
- **Con:** Default-scope magic fights the codebase style, complicates jobs/
  console/seeds (must wrap everything in `ActsAsTenant.with_tenant`),
  interacts badly with the existing hand-rolled team scoping and with
  cross-tenant admin surfaces. New dependency.

**Recommendation: B1** — consistency with team scoping beats the safety-net
argument, and the write-side validations plus two-company test fixtures give
most of the same protection.

## Decision C — are users, teams, groups, permissions per company?

### Option C1: shared/global (recommended for phase 1)

One user base, one group/permission set, one team list; a user who may see
company A's invoices may see company B's (subject to team scoping, which
stays orthogonal).

- **Pro:** Small diff; matches "same operators run several of their own
  legal entities" — the likely deployment reality.
- **Con:** No per-company access control (can't give an accountant access to
  company A only).

### Option C2: per-company access grants

Either scope teams to companies, or add a `user_issuer_companies` join
(membership = may select that company), with `bypass` for admins.

- **Pro:** Real isolation; the switcher only offers permitted companies.
- **Con:** Another authorization axis interacting with groups *and* teams;
  permission UI growth; more test surface.

**Recommendation: C1 now, leaving room for C2** — `set_current_issuer` is the
single choke point where a membership check would later slot in.

## Decision D — branding for unscoped surfaces

Login page, account/user-admin pages, auth emails (`UserMailer`), and the
customer-portal root page (no token → no delivery note → no issuer) currently
use the singleton's branding.

- **D1 (recommended):** neutral "ABT" branding for auth/admin surfaces; the
  customer portal root is already a generic "nothing here" page; acceptance
  pages derive the issuer from the token's delivery note.
- **D2:** a `primary` flag on one issuer company used for otherwise
  ambiguous surfaces. Adds a concept and a footgun (what happens when the
  primary is archived?) for marginal aesthetic gain.

## Rejected wholesale: database-per-company

Rails horizontal sharding would isolate perfectly but breaks the shared user
base, the cross-company dashboard, single-process Solid Queue, and the
SQLite-dev/PostgreSQL-prod story. Massive operational cost for an app of this
size.

## Migration plan (phased; each phase green and shippable)

### Phase 0 — decouple call sites (no schema change)

1. Add `Current.issuer_company` attribute.
2. Replace ambient lookups with explicit issuer arguments where a record
   already implies one: `Invoice#money_decimal_places`,
   `Invoice#publish_warnings`, `Offer#default_validity_days`,
   `OfferMilestoneScaffolder`, `ViesVerifier` (issuer via customer — after
   Phase 1; until then keep `get_the_issuer!` behind one shim).
3. `ApplicationMailer`: move issuer resolution from `initialize` into
   `document_mail(issuer:, ...)` / per-mailer setup, deriving from the
   document being mailed.

### Phase 1 — schema

4. Migration: drop unique index on `issuer_companies.active`; add
   `issuer_company_id` (nullable) to the ten tables above; backfill from the
   single existing active issuer; add NOT NULL + FKs; swap the global unique
   indexes for the per-issuer composites (document numbers, matchcodes,
   `document_numbers.code`, tax-class default).
5. Add `IssuerScoped` concern with same-issuer reference validations;
   `DocumentNumber.get_next_for(issuer, code, date)`.
6. Fixtures: add a second issuer company plus minimal second-company records;
   `db/seeds.rb` assigns everything to the seeded issuer.

### Phase 2 — request context and routes (the user-visible switch)

7. Route scope `c/:issuer_company_id` around business resources;
   `set_current_issuer` + `default_url_options` in `ApplicationController`;
   legacy-path redirects to the default company.
8. Scope every controller read through
   `Model.for_issuer(Current.issuer_company)` (chained before `visible_to`);
   creation paths set `issuer_company` from `Current`.
9. Root picker + navbar switcher + last-used cookie.
10. Layout branding/accent/currency helpers read `Current.issuer_company`;
    neutral branding on unscoped surfaces (Decision D1).

### Phase 3 — company management + system contexts

11. `IssuerCompaniesController` → full `resources` (index/new/create/archive)
    under an unscoped admin path; new company bootstraps its
    `document_numbers` rows (invoice/delivery_note/offer) and default tax
    scaffolding; permission stays `issuer_company.view/edit` (rename to
    `issuer_companies.*`).
12. Jobs iterate `IssuerCompany.where(active: true)`: report jobs send one
    report per issuer to that issuer's `reporting_email`;
    `RefreshStaleVatVerificationsJob` uses each issuer's `vat_id_recheck_days`
    and requester VAT ID over that issuer's customers.
13. Customer portal: derive `@issuer` from the token's delivery note.
14. `DashboardConsistencyChecks` and the home dashboard become per-company.
15. Update `CLAUDE_WORKFLOW.md` (remove the singleton rule), `CLAUDE.md`,
    seeds, and docs.

### Test impact

Every fixture-based test touching customers/invoices/offers gets an implicit
`issuer_company` via fixtures; the important *new* tests are cross-tenant:
listing, showing, publishing, converting, attachment access, and document
numbering must all be proven company-local with the two-company fixture set.
Expect broad-but-shallow churn (~40 test files reference the issuer today).

## Creating additional companies (rake task first, web UI later)

Creating the *record* is trivial; what actually needs building is the
per-company bootstrap and a hard ordering constraint.

### Ordering constraint (correctness, not convenience)

A second `active` company must not exist until Phases 0–1 are complete:

- The unique index on `issuer_companies.active` physically rejects a second
  `active: true` row today, and dropping it early would make
  `get_the_issuer!` (`where(active: true).first`) **nondeterministic** —
  invoices could publish, and mail could send, under the wrong legal entity.
  Every `get_the_issuer!` call site must already be issuer-aware
  (Phase 0) and rows must be scoped (Phase 1) before the first extra
  company is created.
- The creation task therefore lands **after Phase 1**; it does not require
  Phase 2 (URL scoping/UI) — a second company can exist headless until the
  switcher ships, invisible to users because all reads are scoped to the
  companies surfaced in the UI.

### `IssuerCompanyBootstrap` service (shared by rake task and later UI)

One transaction that produces a *publishable* company, not just a row:

1. **Issuer row** with all validated fields. The schema defaults for
   `document_email_from` / `document_email_auto_bcc` / `reporting_email` are
   `*@example.com` placeholders — the service must require real values
   rather than inherit them, or the first published invoice mails a
   placeholder address.
2. **`document_numbers` rows** for `invoice`, `delivery_note`, `offer` —
   without them the first publish raises `NoDocumentNumberRangeError`.
   Formats/start sequences default to copies of an existing company's rows
   (with `sequence: 0`, `last_date: nil`), overridable.
3. **Tax scaffolding** (choose per creation): clone
   `sales_tax_customer_classes` / `sales_tax_product_classes` (incl. the
   one `is_default`) / `sales_tax_rates` from a template company, or start
   empty and rely on the per-company "setup not done" dashboard state.
   Cloning is the right default when the new entity is in the same country;
   empty is right otherwise (rates/indicator codes are country-specific).
4. **Logos** optional — renderers are nil-safe (`pdf_logo.present?` guards);
   the task accepts file paths, the UI can add them later.

Not part of the service, but required operationally: the new
`document_email_from` sender domain must be valid in Mailgun before the
first send.

### Rake tasks (mirroring `users:invite`)

- `issuer_companies:create` — arguments or ENV for the required fields +
  `TEMPLATE=<id>` for numbering/tax cloning; prints the created id.
- `issuer_companies:list` — id, short_name, active, per-company setup state.

### Consequential tweaks

- `db/seeds.rb` uses `find_or_create_by(active: true)` — must key on
  something stable (e.g. `short_name`) once several active rows are legal.
- `HomeController`'s `is_setup_done` and `DashboardConsistencyChecks` count
  tax config globally; they must count per company or a fully configured
  company A masks an unconfigured company B (already in Phase 3, but the
  bootstrap task is what makes it observable).
- No uniqueness exists on `short_name`/`legal_name`; the task (and later
  UI) should at least warn on duplicates — `short_name` feeds attachment
  filenames and mail From headers. If Decision 5 lands on slugs, the slug
  is minted here.

## Risk register

| Risk | Mitigation |
|---|---|
| Cross-company data leak via unscoped read | Two-company fixtures + explicit leak tests per controller; write-side `IssuerScoped` validations |
| Duplicate/wrong document numbers during index swap | Single transaction migration; per-issuer backfill is a no-op while one issuer exists |
| Wrong-company document creation from a stale tab | URL scoping makes the company explicit in every request; same-issuer validations reject mismatched references |
| Mailer sends with wrong from/bcc | Issuer derived from the document being mailed, never from ambient state |
| `verify_permission_check_performed`-style gap for issuer scoping | Optional follow-up: analogous `verify_issuer_scope_performed` guard on scoped controllers |

## Open decisions (need sign-off before implementation)

1. **A: context carrier** — URL path (recommended) vs session vs subdomain.
2. **B: scoping style** — explicit `for_issuer` (recommended) vs acts_as_tenant.
3. **C: access control** — shared users/teams/groups (recommended) vs
   per-company membership.
4. **D: unscoped branding** — neutral ABT (recommended) vs primary-company flag.
5. URL token: numeric id (`/c/3/...`, simplest) vs a new slug column
   (`/c/acme/...`, nicer, needs uniqueness + immutability rules).
