# Code Style

The canonical style reference for this repo. Project structure, architecture, models, and tooling commands live in `CLAUDE.md`.

## Tests
- One scenario per `test "..." do` block — minimal setup, focused assertions, no leading comment (the name is the explanation).
- Use `assert_select` and response assertions. Never `assigns()`.
- Skip pixel-position / `getBoundingClientRect` system tests for CSS class tweaks.
- A shared one-line fix across `Invoice`/`DeliveryNote` gets its regression test in one place, not both.
- When adding or refactoring code, delete now-redundant nearby tests in the same change.
- System tests wait with Capybara matchers (`assert_selector`, `assert_text`) — never `sleep`.

## Stimulus / JavaScript
- ES modules; `import Controller from "controllers/..."` — importmap paths, never relative.
- Bind handlers once in `connect()` (`this.boundX = this.x.bind(this)`); remove the same reference in `disconnect()`. Re-attaching to dynamic elements? Remove existing listeners first to prevent duplicates.
- Bootstrap modals / dropdowns / collapses / popovers need a Stimulus controller — toggle `d-none`/`show` manually. Bootstrap JS isn't bundled; `data-bs-toggle` does nothing on its own.
- Never hardcode URL paths in JS — pass them in via data attributes from Rails URL helpers.

## Views (HAML + Bootstrap 5)
- HAML for every template (`.html.haml`). No `.erb`.
- No inline `style="..."` — strict CSP. Put rules in `app/assets/stylesheets/*.scss`, apply by class. Mail templates are the only exception.
- Non-dashboard / non-account pages use `breadcrumbs(...)` as the page header — no separate `<h1>`. Edit/new pages put the primary submit in `action:` via `save_button`. No Cancel button — the parent crumb is the way back.
- Page titles: rely on `breadcrumbs` / `page_header` auto-deriving `content_for :title` from the active crumb. Override with an explicit `- content_for :title, "..."` only when the crumb is too generic for a browser tab (Edit/New pages; invoice/delivery-note show pages where the bare number isn't a useful label — use `display_name` for the prefixed form).

## Status badges
- Show only deviation from the healthy default. Active/normal renders no badge in headers and as plain text in tables.
- Lifecycle states (Draft, Booked, Published, Sent, Paid, Overdue) all get header badges — no state is implicitly "good".
- Hide superseded badges: Invoice header drops "Booked" once Sent/Paid/Overdue applies. Sent stacks with Paid/Overdue (email and payment are independent).
- Hide a list's Status column when filtered to a single state (column would be redundant).
- Empty optional fields render nothing — no blank labels in detail grids or PDFs.

## Status-row action buttons (show pages)
- "Act on this status" controls (Send E-Mail, Mark Paid…, Mark Unpaid, Convert to Invoice) sit at the right edge of their status row's `.col-sm-8.d-flex.align-items-center.gap-2`.
- `ms-auto` goes on the actual flex child:
  - Plain `%button` → on the button itself.
  - Disabled-tooltip variant (`%span` wrapping a disabled `%button`) → on the wrapping `%span`.
  - `button_to` → on the generated `<form>`: `button_to ..., form: { class: 'button_to ms-auto' }`. Keep `button_to` — `bootstrap_and_overrides.css.scss` styles it.

## Action button glyphs
Three tiers:
- **Text only** when the label is short and universally clear (`Edit`, `+ New`, `Save`, `Reset passkeys`) — no glyph prefix.
- **Glyph + text** for less-familiar workflow actions (`🚀 Publish`, `📥 Upload PDF`, `🚫 Block`).
- **Glyph only** for universally-understood verbs. Always pass `title:` (sets tooltip + `aria-label`): `🗑` Delete, `📄` PDF, `👁` Preview.

When the glyph carries the verb, drop the leading verb from the label: `Mark Paid` → `✅ Paid`, `Mark Unpaid` → `↩ Unpaid`. Keep verb+object when the glyph alone isn't enough.

Reuse glyphs for the same archetype — don't invent new ones:
- 🚀 promote forward (Publish, Create invoice from delivery note)
- ✅ positive state change (Paid, Unblock)
- ↩ / ↩️ revert state (Unpaid, Unpublish) — Unicode-distinct but visually similar; never coexist on the same page

Established mapping — extend it, don't invent new glyphs for existing verbs:

| Verb | Render | Helper |
|---|---|---|
| Edit | `Edit` | `action_button` |
| + New | `+ New` | `action_button` |
| Save | `Save` | `save_button` |
| Reset passkeys | `Reset passkeys` | `reset_passkeys_button` |
| Delete | `🗑` | `delete_button` |
| PDF | `📄` | `pdf_button` |
| Preview | `👁` | `preview_button` |
| Mark Paid | `✅ Paid` | (status-row, inline) |
| Mark Unpaid | `↩ Unpaid` | (status-row, inline) |
| Send e-mail | `✉️ Send` | (status-row, inline) |
| Publish | `🚀 Publish` | `publish_button` |
| Unpublish | `↩️ Unpublish` | `unpublish_button` |
| Convert to Invoice | `🚀 Create…` | (status-row, inline) |
| Upload PDF | `📥 Upload PDF` | (form, inline) |
| Block | `🚫 Block` | (form-with-reason, inline) |
| Unblock | `✅ Unblock` | `unblock_button` |
| Audit log | `📋 Audit log` | `audit_log_button` |

For cross-resource navigation in a breadcrumb action cluster, use `nav_button` (outline-secondary). Don't reach for filled variants for nav.

## Controllers
- Permission gates: `before_action -> { require_permission!("scope.verb") }, only: [...]`.
- Read through tenant scopes (`Model.visible_to(current_user)`).
- On validation failure: `render :new`/`:edit, status: :unprocessable_content`. On success: `redirect_to`, optionally with `notice:`.
- Production absolute URLs go through `AbsoluteUrl`. Don't set `default_url_options`.

## Errors & UX
- Never `window.location.reload()` / meta-refresh / JS redirect when the server rejects a form/XHR (CSRF, session, auth). Surface the server's `error` field; the user clicks Reload.
- CSRF rescue lives in `ApplicationController#handle_invalid_authenticity_token` — don't replace it with a redirect.

## Formatting
- Dates: `DD.MM.YYYY` via `l(date)`; datetimes `DD.MM.YYYY HH:MM` via `l(time)`. Use `l(value.to_date)` to render a datetime as date-only. `DD.MM` (short) when the year is implied. Never American formats.
- Currency: never hardcode `$` / `€` / `EUR`. Use `format_currency(amount)`; symbol comes from `IssuerCompany.currency`.

## Layout judgment
- Don't call a multi-column card layout imbalanced by card count — judge by realistic per-column rendered height. List-bound cards (sessions, audit events, line items) grow with data and naturally fill a column.

## Comments
- Default to none. Add a one-liner only when the *why* isn't obvious from the code (workaround, invariant, hidden constraint).
- Don't reference the current PR/task in comments — that belongs in the PR description.
- Describe the present, not the history. Say what the code does now and why; don't note what it "previously" did, what a change "replaces", or contrast against an earlier version — that belongs in the commit message.

## Code quality
- DRY when refactoring or fixing, but don't overdo it. Prefer clarity and maintainability over excessive abstraction.

## Commit messages
- Subject: concise, direct (e.g. "Auto-resize textareas").
- Body: one functional sentence, plus short factual bullets if needed. No verbose explanations.
