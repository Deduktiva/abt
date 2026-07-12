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

## Cards
- Every distinct block of content on a show/dashboard page belongs in a `.card` — the page should read as one consistent stack of cards, not a mix of bare label/value rows and boxed cards. If a page has any card on it, put everything else on it in cards too (see `docs/card-table-restyle.md` for the invoice/offer/delivery-note top info grid and the dashboard stat tiles, both retrofitted for exactly this reason) — a bare block reads as unfinished once its neighbors are card-wrapped.
- Cards are borderless with a 2px teal rule under the header (`bootstrap_and_overrides.css.scss`) — that rule is the only boundary needed against the app's tinted page background. Don't add `border`/`border-*` back for an ordinary card.
- Headerless card (`.card` wrapping only a `.card-body`, no `.card-header`) for a single-purpose block whose context is already labeled elsewhere — a lone prelude/boilerplate rich-text field (label sits above it, outside the card), a lone paragraph. `.card-body`'s top padding is already collapsed for this case and only restored to the full amount when a `.card-header` precedes it — don't add a header just to "fill" the space.
- Solid-fill headers (`.card-header.bg-danger.text-white`, e.g. "Danger zone" / "Block user") drop the teal rule automatically since the fill itself is the boundary — don't add one back.
- `.border-{color}` utilities (e.g. flagging the dashboard's cashflow tile or a failed-jobs count) only set `border-color`; pair them with the base `.border` utility (`.card.border.border-success`) — `.border-{color}` alone is silently invisible now that `.card` defaults to `border: 0`.
- `rich_text_area` fields always sit inside a card — the Trix toolbar looks like an app-native bordered component, not plain text, so it can't float bare on the page. Wrap just the editor, not the field's own label.
- Tables are **not** card-wrapped (a separate, deliberate decision — see `docs/card-table-restyle.md`); a line-items table, milestones table, or totals summary sits bare in its container. Don't wrap a table in a card to "fix" perceived inconsistency.
- Index pages (list + filter toolbar) don't use cards at all — a distinct, consistent convention across every `index.html.haml`. Don't introduce cards there.
- Multi-column card grids: `.row > .col-md-6 > .card.mb-3`. Stack full-width cards with `.mb-4` — without it, adjacent borderless cards touch and visually fuse into one.
- Don't call a multi-column card layout imbalanced by card count — judge by realistic per-column rendered height. List-bound cards (sessions, audit events, line items) grow with data and naturally fill a column.
- Card header text is Title Case, and a primary "show the whole record" card is named `"{Entity} Information"` (`Customer Information`, `Company Information`, `Team Information`) — not a bare `Information` or `Basic Information` that drops the entity name. A card for one specific sub-topic just names that topic (`Notes`, `Members`, `Offer Settings`) rather than forcing the `{Entity} Information` pattern onto it.

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

## Action button icons
Three tiers:
- **Text only** when the label is short and universally clear (`Edit`, `+ New`, `Save`, `Reset passkeys`) — no icon prefix.
- **Icon + text** for less-familiar workflow actions (`Publish`, `Upload PDF`, `Block`).
- **Icon only** for universally-understood verbs. Always pass `title:` (sets tooltip + `aria-label`): Delete, PDF, Preview.

Icons are inline monochrome SVG via `action_icon(:name)` (`app/helpers/application_helper.rb`), backed by the `bootstrap-icons` gem — not emoji. `action_icon` takes the gem's icon name (underscores are converted to hyphens, so `:"eye-fill"` or `:eye_fill` both map to the `eye-fill` icon). Build an icon + text label with `icon_label(:name, "Text")` (`app/helpers/action_buttons_helper.rb`) — it wraps the text in a `<span>` so `.btn svg.bi:not(:last-child)` in `bootstrap_and_overrides.css.scss` only adds the icon/text gap where there's text to gap against, keeping icon-only buttons symmetrically centered. `<input type="submit">` can't hold an SVG — use `f.button(...) do ... end` instead of `f.submit` wherever the label needs an icon.

When the icon carries the verb, drop the leading verb from the label: `Mark Paid` → `Paid…`, `Mark Unpaid` → `Unpaid`. Keep verb+object when the icon alone isn't enough.

Reuse icons for the same archetype — don't invent new ones:
- `send` (paper plane) promote forward (Publish — invoice/delivery-note/offer, Convert to Invoice, Convert milestone)
- `check-circle-fill` / `shield-check` positive state change (Paid, Unblock)
- `arrow-counterclockwise` revert state (Unpaid, Unpublish)
- `trash3` delete (Delete, and the inline "remove line" buttons on invoice/delivery-note/offer-milestone edit forms)
- `shield-slash` restrict access (Block)

Established mapping — extend it, don't invent new icons for existing verbs:

| Verb | Icon | Render | Helper |
|---|---|---|---|
| Edit | — | `Edit` | `action_button` |
| + New | — | `+ New` | `action_button` |
| Save | — | `Save` | `save_button` |
| Reset passkeys | — | `Reset passkeys` | `reset_passkeys_button` |
| Delete | `trash3` | icon only | `delete_button` |
| PDF | `file-earmark-pdf-fill` | icon only | `pdf_button` |
| Preview | `eye-fill` | icon only | `preview_button` |
| Mark Paid | `check-circle-fill` | icon + `Paid…` | (status-row, inline) |
| Mark Unpaid | `arrow-counterclockwise` | icon + `Unpaid` | (status-row, inline) |
| Send e-mail | `envelope` | icon + `Send` | (status-row, inline) |
| Publish | `send` | icon + `Publish` | (status-row, inline) |
| Unpublish | `arrow-counterclockwise` | icon + `Unpublish` | `unpublish_button` |
| Convert to Invoice | `send` | icon + `Create` | (status-row, inline) |
| Upload PDF | `upload` | icon + `Upload PDF` | (form, inline) |
| Block | `shield-slash` | icon + `Block` | (form-with-reason, inline) |
| Unblock | `shield-check` | icon + `Unblock` | `unblock_button` |
| Audit log | `journal-check` | icon + `Audit log` | `audit_log_button` |

For cross-resource navigation in a breadcrumb action cluster, use `nav_button` (outline-secondary). Don't reach for filled variants for nav.

Out of scope for this convention — deliberately left as emoji, don't convert without a separate decision: Configuration hub tiles (`app/views/configurations/index.html.haml`, page content rather than a workflow action), the "Reusable" badge in the searchable dropdown, and the `✓`/`▲`/`▼` symbols in the invoice/delivery-note/offer-milestone edit-form line toolbars (unlabeled by design, matching their siblings).

## Navigation icons
A separate convention from the action-button icons above — these mark navbar chrome (Configuration, the account link, Sign out), not workflow actions:
- Inline monochrome SVG via `nav_icon(:name)` — same underlying `bootstrap-icons` lookup as `action_icon`, just a different default size (15px vs 14px) and semantic name for the call site.
- Configuration and the account link show their icon only below the `sm` breakpoint (`d-inline d-sm-none`) — on desktop they're plain text like every other top-level nav item; the icon exists to break up an otherwise-identical run of text rows once the navbar collapses to its mobile stacked list.
- Sign out is the exception: icon-only on desktop (`nav_icon(:box_arrow_right)`), icon + text once collapsed — it's the one control that isn't paired with adjacent context, so a lone icon reads fine on desktop but would be the only unlabeled row in the mobile list.
- Configuration hub tiles (`app/views/configurations/index.html.haml`) use the existing emoji convention, not `nav_icon` — that page isn't chrome, it's page content, so the action-button icon rules apply there instead (and are themselves out of scope for now, see above).

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

## Comments
- Default to none. Add a one-liner only when the *why* isn't obvious from the code (workaround, invariant, hidden constraint).
- Don't reference the current PR/task in comments — that belongs in the PR description.
- Describe the present, not the history. Say what the code does now and why; don't note what it "previously" did, what a change "replaces", or contrast against an earlier version — that belongs in the commit message.

## Code quality
- DRY when refactoring or fixing, but don't overdo it. Prefer clarity and maintainability over excessive abstraction.

## Commit messages
- Subject: concise, direct (e.g. "Auto-resize textareas").
- Body: one functional sentence, plus short factual bullets if needed. No verbose explanations.
