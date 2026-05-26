# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is "ABT", a Rails 8 application for invoice and delivery-note management. Bootstrap 5 + Turbo UI, passkey auth, Solid Queue background jobs, Apache FOP PDFs.

## Common Commands

### Setup and Dependencies
- `bundle install` - Install Ruby gem dependencies (requires Ruby >= 3.3)
- `bundle exec rails db:migrate` - Run database migrations
- `bundle exec rails db:seed` - Load seed data

### Development
- `bundle exec rails server` - Start the development server
- `bundle exec rails console` - Open Rails console (use for testing helpers and models)
- `bundle exec rails test` - Run the test suite (NEVER use `rails test` - it doesn't handle migrations properly)

### Database
- `bundle exec rails db:create` - Create database
- `bundle exec rails db:setup` - Create database and load schema
- `bundle exec rails db:reset` - Drop, recreate, and reseed database

### PostgreSQL Development Environment
For testing against PostgreSQL (matches production environment):
- `./bin/postgres-dev start` - Start PostgreSQL container
- `./bin/postgres-dev setup` - Create and setup PostgreSQL database
- `./bin/postgres-dev server` - Run Rails server with PostgreSQL
- `./bin/postgres-dev test` - Run tests with PostgreSQL
- See `POSTGRES_DEV.md` for complete documentation

## Architecture Overview

### Core Models
- **Invoice** (`app/models/invoice.rb`) - Central model with customer, project associations and nested invoice lines
- **DeliveryNote** (`app/models/delivery_note.rb`) - Parallel document type to Invoice; shares the line/publish/email pipeline via concerns
- **Customer** (`app/models/customer.rb`) - Customer management with sales tax classes
- **InvoiceLine** / **DeliveryNoteLine** - Line items with types (item, text, subheading)
- **Product** (`app/models/product.rb`) - Product catalog
- **Project** (`app/models/project.rb`) - Project tracking
- **User** + `UserCredential`, `UserEmail`, `UserInvite`, `UserSession`, `UserAuditEvent` - Passkey/WebAuthn auth, invite-only signup, audit log

### Shared Concerns
- `PublishableDocument`, `DocumentWithLines` (controllers) - draft/published guards and line-form plumbing for Invoice + DeliveryNote
- `HasLineItems`, `YearFilterable`, `DigestedToken` (models) - line helpers, date-scoped queries, SHA-256-digested token storage

### Tax System
- **SalesTaxCustomerClass** - Customer tax classification
- **SalesTaxProductClass** - Product tax classification
- **SalesTaxRate** - Tax rates by customer/product class combination
- **InvoiceTaxClass** - Applied tax calculations per invoice

### Invoice Processing Pipeline
1. **InvoicesController** - Standard CRUD + special actions (preview, book, bulk email)
2. **InvoiceBooker** - Business logic for "booking" invoices (calculating taxes, assigning document numbers, publishing)
3. **InvoiceRenderer** - PDF generation using Apache FOP with XML/XSL transformation
4. **Email System** - `DocumentMailer` delivered via `deliver_later` (Solid Queue). Bulk send marks `email_sent_at` for tracking.

### Background Jobs
- Solid Queue (`bin/jobs` worker, `solid_queue` gem). Schedule lives in `config/recurring.yml` — currently `OverdueInvoicesReportJob` (every other day at 08:00) and finished-job cleanup.
- Worker status surfaced under **Configuration → Background Jobs** (`JobsStatusController`).

### Authentication
- WebAuthn-only via the `webauthn` gem. No passwords. Invite-only signup (24h single-use URLs, `users:invite` rake task bootstraps the first user).
- Self-service under `/account/*`; admin under `/users` (block, reset passkeys, manage emails).
- Tokens (invite, session, email confirmation) stored as SHA-256 digests via `DigestedToken`.
- Rate limiting via `rack-attack` on unauthenticated endpoints (`config/initializers/rack_attack.rb`).
- CSRF: `protect_from_forgery with: :exception` is rescued by `ApplicationController#handle_invalid_authenticity_token`. HTML requests render `app/views/errors/csrf_failure.html.haml` (status 422); JSON XHR requests return `{ "error": "..." }` with status 422. Do not replace this with a redirect or `window.location.reload()` — CSRF failures land on stale forms (login, invoice create, etc.) and an auto-reload silently discards whatever the user just typed. The error template prompts the user to click Reload themselves. New JSON XHR controllers must surface the server's `error` field in a visible alert (see `passkey_controller.js#showError`); never swallow it as `Request failed (422)`.

### PDF Generation
- Uses Apache FOP (Formatting Objects Processor) for PDF generation
- XML templates in `lib/foptemplate/`; shared base in `document_base.xsl` uses XSLT 2.0 features (`xsl:function`, `format-date` picture strings) — Saxon-B is mandatory, JDK's built-in XSLTC silently can't process these
- Two launchers, both tracked in this repo and both injecting Saxon-B plus JAXP hardening flags (`jdk.xml.dtd.support=deny`, `accessExternalDTD=`, `accessExternalSchema=`, `accessExternalStylesheet=file`):
  - `bin/abt-fop-container` — wraps `podman run` (or docker) around the abt-fop image and execs `script/abt-fop` inside it. Default for dev/test/CI.
  - `script/abt-fop` — invokes `run_java` directly on the host's `fop` + `libsaxonb-java` packages. Used in production and in environments without a container runtime (e.g. the Claude Code sandbox, which writes a `config/settings/{env}.local.yml` override pointing at it).
- When changing XML handling, keep hardening in `script/abt-fop` — don't introduce a second launcher path.

### Key Workflow
1. Create draft invoice with lines
2. Preview generates temporary PDF without saving
3. "Book" finalizes invoice (assigns document number, calculates final taxes, publishes)
4. Published invoices cannot be modified
5. Email invoices individually or in bulk batches

## Configuration

### Database
- Development: SQLite3
- Production: PostgreSQL 17
- Template files: `config/database.yml.tpl`, `config/secrets.yml.tpl`

### Settings
- Configuration via `config/settings.yml` and environment-specific files
- FOP binary path must be configured for PDF generation
- Payment URL template for invoice tokens

### Deployment
- Production runs Apache + mod_passenger on `*:443` (see `apache2.conf.tpl`). mod_passenger forwards Apache's `HTTPS=on` directly into the Rack env, so `request.ssl?` is honest — no `X-Forwarded-Proto` / `trusted_proxies` plumbing needed. If the topology ever changes (nginx, Caddy, a CDN in front), revisit `config.assume_ssl` / `config.action_dispatch.trusted_proxies` in `config/environments/production.rb`.
- `config.hosts` in production is populated from `Settings.app.host`. Adding a new domain means updating the settings overlay, not editing `production.rb`.
- Absolute URLs in mailers and tokens go through `app/services/absolute_url.rb`, which reads `Settings.app.host` / `Settings.app.protocol` / `Settings.app.script_name` explicitly. `config.action_mailer.default_url_options` is intentionally unset in production — don't reach for it.

## External Dependencies

### Required Software
- Ruby >= 3.3
- Apache FOP 2.10 for PDF generation (Debian trixie package: `fop`)
- Saxon-B as the XSLT 2.0 processor (Debian package: `libsaxonb-java`) — without this, FOP rendering fails because the templates use XSLT 2.0
- OpenJDK 21 (or any JDK ≥ 21 that honours the `jdk.xml.*` JAXP system properties)
- Database (SQLite3 for dev, PostgreSQL for production and in CI)
- Mailgun account for outbound email (`mailgun-ruby`)
- WebAuthn-capable browser/authenticator for sign-in (`webauthn` gem; configured via `webauthn.rp_id` / `webauthn.origin` / `webauthn.rp_name` in settings)

### Font Files
- Open Sans fonts in `lib/foptemplate/open-sans/` for PDF rendering

## Key Files for Modifications
- Invoice business logic: `app/controllers/invoice_book_controller.rb`
- PDF template: `lib/foptemplate/invoice.xsl`
- Invoice model: `app/models/invoice.rb`
- Main invoice controller: `app/controllers/invoices_controller.rb`
- Delivery notes: `app/controllers/delivery_notes_controller.rb`, `app/models/delivery_note.rb`
- Auth flows: `app/controllers/sessions_controller.rb`, `invites_controller.rb`, `account/`, `users_controller.rb`
- UI helpers: `app/helpers/application_helper.rb`

## Development Preferences

### Template Language
- Use HAML (`.html.haml`) for all view templates

### UI Framework
- Bootstrap 5 for responsive design and components
- Turbo for SPA-like interactions without JavaScript complexity
- Stimulus controllers for interactive components (bulk-select, email-preview)
- European-style date/time formatting throughout
- Strict Content Security Policy — no inline styles in views. Put styling in CSS/SCSS files and apply via classes. Inline `style="..."` attributes are only allowed in email templates (rendered HTML email, not subject to the app CSP).
- Bootstrap's JavaScript is NOT bundled — only its CSS. JS-driven components (modals, popovers, dropdowns, collapses, JS tooltips) require a custom Stimulus controller; `data-bs-toggle` / `data-bs-target` attributes do nothing on their own.
- Established pattern: manually toggle `d-none`/`show` classes from a Stimulus controller (see `app/javascript/controllers/generic_email_preview_controller.js` and `app/javascript/controllers/modal_controller.js`).

### Status Badges
- **Show only the deviation from the healthy default.** No badge means "normal."
  - Customer/Project Inactive, User Blocked → badge. Active state → nothing.
  - Invoice/Delivery Note lifecycle (Draft, Booked, Paid, Overdue, Sent) all get header badges — there's no implicit "good" lifecycle, every state is noteworthy.
- **Hide superseded badges.** On invoices, the header drops "Booked" once a more specific state (Sent/Paid/Overdue) applies. Sent stacks with Paid/Overdue (email and payment are independent).
- **In detail grids and list columns, healthy data renders as plain text, not a badge.** Paid (with date), Sent (with timestamp) → plain text. Problem states (Unpaid, Unsent, Overdue, No Recipient) keep their badges.
- **Hide the status column entirely when a list is filtered to a single state.** On the customers and projects lists, the Status column is only rendered when the filter is "All"; when filtered to Active or Inactive the column would be redundant (every row identical or empty), so the header and cells are omitted.
- Header badges sit inline with the active breadcrumb crumb (via the `breadcrumbs(...)` status block) at the default badge size — no `fs-` modifier needed.

### Status-row Action Buttons
- On document show pages, "act on this status" controls (Send E-Mail, Mark Paid…, Mark Unpaid) sit inline at the right edge of their status row's `col-sm-8`, separating the status text/badge on the left from the action on the right. The row container is `.col-sm-8.d-flex.align-items-center.gap-2`.
- `ms-auto` must go on the actual flex child:
  - Direct `%button` → put `ms-auto` on the button.
  - Disabled-tooltip variant (a `%span` wrapping a disabled `%button`) → put `ms-auto` on the wrapping `%span`.
  - `button_to` → the generated `<form class="button_to">` is the flex child, so `ms-auto` on the inner button has no effect. Pass it on the form instead: `button_to ..., form: { class: 'button_to ms-auto' }` (keep the `button_to` class — `bootstrap_and_overrides.css.scss` styles it).

## Development Best Practices

### Running rails
- Always use `bundle exec rails` to run `rails`

### Testing Guidelines
- Write simple unit tests when implementing new features
- Test database auto-migrates via `ActiveRecord::Migration.maintain_test_schema!` in test_helper.rb
- **NEVER use `assigns()` in tests** - use `assert_select` or other response testing methods instead
- **Run UI tests headless by default before declaring frontend/UI tasks complete** when making frontend/UI changes
- **NEVER use `sleep` in system tests** - use Capybara's waiting methods instead (`assert_selector`, `assert_text`, `assert_no_text` with `wait:` option)

### UI Testing Commands
- Run all system tests: `bundle exec rails test test/system/`
- Run specific system test file: `bundle exec rails test test/system/filename_test.rb`
- Run specific test method: `bundle exec rails test test/system/filename_test.rb -n test_method_name`
- System tests use Cuprite (headless Chrome) driver configured in ApplicationSystemTestCase
- Screenshots saved to `tmp/capybara/` on test failures for debugging

### Multi-Region Compatibility
- This app supports multiple regions - NEVER hardcode currency symbols like $ or USD
- Use IssuerCompany.currency field for currency configuration (defaults to EUR)
- Currency formatting handled by ApplicationHelper#format_currency
- Date/datetime formatting: use Rails' `l(date)` / `l(time)` in views (or `I18n.l(...)` in controllers/models). Defaults are configured in `config/locales/en.yml` under `date.formats.default` (`%d.%m.%Y`) and `time.formats.default` (`%d.%m.%Y %H:%M`).

### Formatting Standards
- ALWAYS use European date formats: DD.MM.YYYY for dates, DD.MM.YYYY HH:MM for datetimes
- Use DD.MM for short dates when year is implied
- NEVER use American MM/DD/YYYY or MM-DD formats
- To render a `datetime` column as date-only (e.g. `email_sent_at` in compact list rows), call `l(value.to_date)` — `l` on a `Time`/`DateTime` produces the time format.

### UI Helper Methods
- `breadcrumbs(*items, action: nil, &status_block)` - Bootstrap breadcrumb strip that serves as the page header on every index/show/edit/new page (every page except the dashboard, `/account/*`, the sign-in / invite-acceptance flow, and the post-book confirmation). Each item is either `[label, path]` (link) or a plain label (non-link). The last item is always the active crumb with `aria-current="page"` (rendered `fw-semibold`), and it is the page identifier — there is no separate H1. The optional block yields inline status badges next to the active crumb; the optional `action:` is right-aligned on the same row (built with `action_button(...)`, which returns nil when its permission check fails — that renders as no action area).
  - Top-level resources start with the navbar label linked to its index: `['Customers', customers_path]`, `['Projects', projects_path]`, `['Delivery Notes', delivery_notes_path]`, `['Invoices', invoices_path]`.
  - Configuration resources start with a non-link `'Configuration'` crumb (the dropdown has no destination) followed by the resource's navbar label, e.g. `breadcrumbs 'Configuration', ['Sales Tax', sales_tax_rates_path], 'Edit'`.
  - On edit pages append `'Edit'` as the active crumb; on new pages append `'New'`. On show pages the resource's identifier (matchcode / document number / name) is the active crumb.
  - The bottom `action_buttons_wrapper` no longer contains a `Back` button — the breadcrumb is the navigation anchor. `action_buttons_wrapper` is reserved for workflow verbs (PDF, Send, Publish, Delete, Mark Paid, etc.). `cancel_button(resource)` on edit/new forms stays — it pairs with Submit, not navigation.
- `page_header(title, action: nil, &status_block)` - Page-header row with an H1 title, optional inline status badges via the block, and optional right-aligned action. Only used on pages without breadcrumbs: dashboard (`home/index`), `/account/*`, the sign-in / invite-acceptance / "Book invoice" / "Invite generated" pages.
- `action_button(text, path, type = :primary, permission: nil, target: nil, data: nil)` - Styled buttons (primary, secondary, success, info, warning, danger). Returns `nil` when `permission:` is given and the current user lacks it.
- `action_buttons_wrapper` - Container for the bottom-of-page workflow action row (Back, PDF, Send E-Mail, Publish, Delete, etc.).
- `destroy_link(resource, confirm_text)` - Smart delete links (trashcan on index, "Delete" on detail pages).
- `list_action_link(text, path, type)` - Compact buttons for in-table row actions.

### JavaScript/Stimulus Controllers
- **ALWAYS implement `disconnect()` method** in Stimulus controllers that add event listeners
- Store bound function references (e.g., `this.boundHandler = this.method.bind(this)`) for proper cleanup
- Remove event listeners in `disconnect()` using the same bound reference used in `addEventListener`
- When re-attaching listeners to dynamically created elements, remove existing listeners first to prevent duplicates
- Document event listeners are particularly important to clean up to prevent memory leaks
- **Run `npm run lint` after writing Stimulus controllers** to check for event listener memory leaks
- **NEVER use relative imports** like `import Controller from "./other_controller"` - use importmap paths like `import Controller from "controllers/other_controller"` to ensure proper resolution in production
- **NEVER hardcode absolute URL paths** in JavaScript - use Rails URL helpers passed via data attributes to ensure proper subdirectory deployment compatibility

### Communication Style
- Use direct, technical language in all communications
- Avoid management/business buzzwords and corporate speak
- Be concise and specific rather than verbose or promotional
- Focus on technical implementation details rather than high-level benefits
- Use imperative mood for instructions (e.g. "Run the test" not "We should run the test")
- Avoid phrases like "let's", "we need to", "going forward", "best practices", "leverage", "stakeholders"
- Be factual and precise rather than enthusiastic or salesy

### Code Quality
- Follow DRY when refactoring or fixing bugs, but don't overdo it
- Prefer clarity and maintainability over excessive abstraction

### Git Commit Message Style
- Use concise, direct subject lines (e.g. "Auto-resize textareas")
- Brief functional description in body (one sentence explaining main functionality)
- Key implementation details as short, factual bullet points
- Include practical context when relevant (demo content, examples)
- Maintain Claude Code attribution footer
- Avoid verbose technical explanations or excessive detail in commit messages

### System Administration
- **NEVER run `sudo` commands**
- If system packages need to be installed, explain what is needed and ask the user to install them

### Git and Version Control
- **NEVER check in screenshots or temporary image files**
- Use `.gitignore` to exclude temporary files and screenshots from commits

### Development Commands
- **ALWAYS run `pre-commit run --all-files` before committing** to ensure code formatting and linting
- **Use `pkill -f puma` to kill running `rails server`** when needed to stop development server
