# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is "ABT", a Rails 8 application for invoice and delivery-note management. Bootstrap 5 + Turbo UI, passkey auth, Solid Queue background jobs, Apache FOP PDFs.

## Repository Layout

- All repo-local executables live in `bin/` — Bundler binstubs plus custom scripts (`abt-fop`, `abt-fop-container`, `jobs`, `journal`, `postgres-dev`, `production-update`, `setup`, `setup-fop`).
- Long-form documentation lives in `docs/` and uses lowercase kebab-case filenames (`postgres-dev.md`, `production-update.md`).
- Do not reintroduce a `script/` directory.

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
- See `docs/postgres-dev.md` for complete documentation

## Architecture Overview

### Core Models
- **Invoice** (`app/models/invoice.rb`) - Central model with customer, project associations and nested invoice lines
- **DeliveryNote** (`app/models/delivery_note.rb`) - Parallel document type to Invoice; shares the line/publish/email pipeline via concerns
- **Customer** (`app/models/customer.rb`) - Customer management with sales tax classes
- **InvoiceLine** / **DeliveryNoteLine** - Line items with types (item, text, subheading)
- **Product** (`app/models/product.rb`) - Product catalog
- **Project** (`app/models/project.rb`) - Project tracking
- **Offer** (`app/models/offer.rb`) - Quote/proposal per customer+project; draft → sent → accepted/rejected/expired lifecycle
- **OfferVersion** - Snapshot of offer content; live/editable while draft, frozen once sent
- **OfferMilestone** - Billable line within a version; converts to an invoice or delivery note
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
1. **InvoicesController** - Standard CRUD + special actions (preview, publish, bulk email)
2. **InvoicePublisher** - Business logic for publishing invoices (calculating taxes, assigning document numbers, attaching PDF). Invoice publishing is irreversible; there is no unpublish action.
3. **InvoiceRenderer** - PDF generation using Apache FOP with XML/XSL transformation
4. **Email System** - `DocumentMailer` delivered via `deliver_later` (Solid Queue). Bulk send marks `email_sent_at` for tracking.

### Offer Processing Pipeline
- **OffersController** - Standard CRUD + send/accept/reject/reopen, milestone scaffolding/conversion, order-PDF upload, email
- **OfferSender** - Freezes the current draft `OfferVersion` (assigns document number on first send, snapshots customer data), transitions the offer to `sent`, and branches a fresh draft version for further edits
- **OfferRenderer** - PDF generation for offers using Apache FOP, `lib/foptemplate/offer.xsl`
- Lifecycle: `draft` → `sent` → `accepted` / `rejected` / `expired`; sending an offer never mutates the sent version in place — it freezes that version and opens a new draft alongside it. Milestones convert individually to invoices or delivery notes (`OfferMilestoneConverter`); conversion can be reversed with a reopen link.
- Permissions: `offers.view`, `offers.edit` (create/send/accept/reject/reopen), `offers.convert` (milestone → invoice/delivery-note)

### Background Jobs
- Solid Queue (`bin/jobs` worker, `solid_queue` gem). Schedule lives in `config/recurring.yml` — currently `OverdueInvoicesReportJob` (every other day at 08:00), `ExpiringOffersReportJob` (daily at 07:30), `UpcomingOfferDeliveriesReportJob` (daily at 07:45), `RefreshStaleVatVerificationsJob` (daily at 04:00), `VatVerificationsReportJob` (daily at 11:00), and finished-job cleanup.
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
  - `bin/abt-fop-container` — wraps `podman run` (or docker) around the abt-fop image and execs `bin/abt-fop` inside it. Default for dev/test/CI.
  - `bin/abt-fop` — invokes `run_java` directly on the host's `fop` + `libsaxonb-java` packages. Used in production and in environments without a container runtime (e.g. the Claude Code sandbox, which writes a `config/settings/{env}.local.yml` override pointing at it).
- When changing XML handling, keep hardening in `bin/abt-fop` — don't introduce a second launcher path.

### Key Workflow
1. Create draft invoice with lines
2. Preview generates temporary PDF without saving
3. "Publish" finalizes invoice (assigns document number, calculates final taxes, publishes). The post-publish state is shown as "Booked" — a deliberate accounting-state label.
4. Published invoices cannot be modified
5. Email invoices individually or in bulk batches

## Configuration

### Database
- Development: SQLite3
- Production: PostgreSQL 17
- Template file: `config/database.yml.sample`
- `SECRET_KEY_BASE` is read by Rails directly from `ENV["SECRET_KEY_BASE"]`, falling back to `config/credentials.yml.enc`. There is no `secrets.yml` — `Rails.application.secrets` / `config/secrets.yml` was removed in Rails 7.2.

### Settings
- Configuration via `config/settings.yml` and environment-specific files
- FOP binary path must be configured for PDF generation
- Payment URL template for invoice tokens

### Deployment
- Production runs Apache 2.4 on `*:443` as a TLS-terminating reverse proxy in front of Puma listening on `127.0.0.1:3000`. Apache proxies dynamic requests and serves precompiled assets (`/assets`, root favicons, `robots.txt`) directly from `/srv/abt/public` via explicit `ProxyPass !` exclusions. Both Puma and the Solid Queue jobs worker run as systemd **user** units under the `abt` user. Unit files live in `deploy/systemd/`; the Apache include and vhost template live in `deploy/apache/`. `bin/production-update` installs/refreshes the unit symlinks on every deploy.
- Scheme detection relies on Apache's `RequestHeader set X-Forwarded-Proto "https"` in `deploy/apache/abt-app.conf` and `config.action_dispatch.trusted_proxies = [127.0.0.1, ::1]` in `config/environments/production.rb`. The two are a load-bearing pair — don't edit either in isolation. `assume_ssl` is deliberately not used (it decouples Rails' belief about scheme from reality, which has burned us before).
- `config.hosts` in production is populated from `Settings.app.host`. Adding a new domain means updating the settings overlay, not editing `production.rb`.
- The authenticated app routes (login, invites, WebAuthn, all CRUD) are host-constrained to the app host via `AppHostConstraint` in `config/routes.rb`, so they 404 on the customer portal host; `ApplicationController#reject_customer_portal_host` remains as defense in depth. When no `Settings.customer_portal.host` is set the constraint is a no-op (single-host deployments work everywhere).
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
- Invoice publish logic: `app/services/invoice_publisher.rb`
- PDF template: `lib/foptemplate/invoice.xsl`
- Invoice model: `app/models/invoice.rb`
- Main invoice controller: `app/controllers/invoices_controller.rb`
- Delivery notes: `app/controllers/delivery_notes_controller.rb`, `app/models/delivery_note.rb`
- Offers: `app/controllers/offers_controller.rb`, `app/services/offer_sender.rb`, PDF template `lib/foptemplate/offer.xsl`
- Auth flows: `app/controllers/sessions_controller.rb`, `invites_controller.rb`, `account/`, `users_controller.rb`
- UI helpers: `app/helpers/application_helper.rb`

## Code Style

See [`docs/code-style.md`](docs/code-style.md) for the canonical style reference (HAML, Bootstrap, Stimulus, tests, status badges, action button icons, formatting, comments, commit messages). Read it before writing code.

UI helpers live in `app/helpers/application_helper.rb` (page chrome: `breadcrumbs`, `page_header`, `action_button`, `destroy_link`, `list_action_link`, `action_buttons_wrapper`) and `app/helpers/action_buttons_helper.rb` (per-verb wrappers: `delete_button`, `pdf_button`, `preview_button`, `publish_button`, `unpublish_button`, `unblock_button`, `reset_passkeys_button`, `audit_log_button`, `save_button`, `nav_button`). Read the source for signatures.

## Claude Operational Notes

### Communication
- Direct, technical language. No buzzwords ("leverage", "stakeholders", "going forward", "let's").
- Concise. Imperative mood ("Run the test", not "We should run the test").

### Running rails
- Always `bundle exec rails ...`. Bare `rails test` skips migrations.

### Verifying UI work
- Run system tests headless before declaring frontend tasks done: `bundle exec rails test test/system/`.
- After Stimulus changes, run `npm run lint` (catches event-listener leaks).

### System administration
- NEVER run `sudo`. If a system package is needed, explain what's needed and ask the user to install.

### Git
- NEVER check in screenshots or temporary image files.
- Always run `pre-commit run --all-files` before committing.

### Development server
- `pkill -f puma` to stop a running `rails server`.
