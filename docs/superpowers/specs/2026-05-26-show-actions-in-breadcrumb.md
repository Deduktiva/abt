# Show-page actions in the breadcrumb strip

## Context

PR #378 dropped the H1 row on every index/show/edit/new page and folded the page title + a single right-aligned `action:` button + status badges into the breadcrumb strip. That left a separate bottom row (`action_buttons_wrapper`) on show pages still carrying the secondary workflow buttons (PDF, Preview, Test Booking, Publish, Convert to Invoice, Delete, Block/Unblock, Reset passkeys, Audit log, etc.). The two rows of buttons — top-right and bottom — split the user's attention.

This work folds the bottom row into the breadcrumb strip too, so every show page renders a single header row carrying every workflow action. Along the way it also formalises a glyph policy (using emoji as text-shorteners) and introduces per-verb helper methods so the policy can't drift across views.

Out of scope: status-row action buttons (Send E-Mail, Mark Paid, Mark Unpaid). Those stay inline with their status text — their proximity to the status they act on is load-bearing.

## Decisions already made (during brainstorm)

- **Scope**: every button currently rendered through `action_buttons_wrapper` on a show page moves into the breadcrumb strip, including the destructive Delete.
- **Pre-existing `action:` button keeps its position** (right edge of the strip). New buttons land to its left.
- **No automatic visual emphasis from the helper.** Callers continue to pick `:primary` / `:info` / `:danger` etc. via `action_button`. The "primary action" concept is expressed in code (which keyword the caller uses) but not in the visual styling — the helper does no fw-bold magic.
- **Three-tier glyph policy** (see table below). Emoji is a text-shortener, not decoration; tiers are chosen per verb.
- **Glyph-only buttons require an accessible name** (`title=` and `aria-label=`).
- **Per-verb helpers** for every entry in the glyph table — so view code reads `pdf_button(path)` not `action_button('📄', path, :success, title: 'PDF', target: '_blank', data: { turbo: false })`. Helpers for status-row verbs (`mark_paid_button`, `mark_unpaid_button`, `send_email_button`) are catalogued in the table for the future migration of those rows, but **not created or wired up in this PR** — the table is the policy, the PR only ships helpers for the show-page bottom row it migrates.

## Helper API changes

### `breadcrumbs` gains `actions:`

```ruby
def breadcrumbs(*items, action: nil, actions: nil, &status_block)
```

- `action:` (existing): the single primary action, rightmost in the cluster. Whatever color the caller built it with.
- `actions:` (new): optional array of additional pre-built buttons. `nil` entries are compacted out, so views can pass `actions: [maybe_a, maybe_b, maybe_c]` and let permission-denied helpers return `nil` naturally.
- Render order in the right cluster: `actions[0], actions[1], ..., actions[N], action`.
- All buttons keep `btn-sm` sizing via the existing `nav[aria-label="breadcrumb"] .btn` CSS rule.
- Backward-compatible: every existing call site continues to work.

### `action_button` gains `title:`

```ruby
def action_button(text, path, type = :primary, permission: nil, target: nil, data: nil, title: nil)
```

- When `title:` is given, the helper applies it as both `title=` (hover tooltip) and `aria-label=` (screen-reader name). Required on Tier-3 (glyph-only) buttons.
- When `title:` is omitted, behaviour is unchanged.

### Per-verb helpers

New module `app/helpers/action_buttons_helper.rb` carrying one helper per entry in the glyph table. Each helper bakes in the glyph, color, accessibility text, and (where applicable) the `link_to` vs `button_to` choice and method/confirm details. Callers pass only path, permission, and any per-call data.

Example sketches:

```ruby
module ActionButtonsHelper
  # Glyph-only (Tier 3) — title required.
  def delete_button(resource, confirm: nil)
    confirm ||= "Are you sure you want to delete this #{resource.class.name.downcase}?"
    link_to "🗑", resource,
      class: "btn btn-danger",
      title: "Delete", "aria-label": "Delete",
      data: { 'turbo-method': "delete", 'turbo-confirm': confirm }
  end

  def pdf_button(path, permission: nil)
    return nil if permission && !can?(permission)
    link_to "📄", path,
      class: "btn btn-success",
      title: "PDF", "aria-label": "PDF",
      target: "_blank", data: { turbo: false }
  end

  def preview_button(path, permission: nil)
    return nil if permission && !can?(permission)
    link_to "👁", path,
      class: "btn btn-info",
      title: "Preview", "aria-label": "Preview",
      target: "_blank", data: { turbo: false }
  end

  # Tier 2 — glyph + text, no title needed.
  def publish_button(path, permission: nil, confirm: nil)
    return nil if permission && !can?(permission)
    button_to "🚀 Publish", path,
      method: :post, class: "btn btn-warning",
      data: (confirm ? { 'turbo-confirm': confirm } : {})
  end

  # ...and similar for every entry in the glyph table.
end
```

Two design choices baked in:
- Helpers carry the **Bootstrap color**. `pdf_button` is `btn-success` because that's the established colour on delivery_notes/show. Changing the colour is a one-line change in the helper, applied everywhere.
- Helpers handle **permission gating** the same way `action_button` does — return `nil` when denied so `actions:` array compaction takes care of layout.

### `destroy_link` collapses into `delete_button`

`destroy_link(resource, confirm_text)` currently splits behaviour by action: trashcan on `index`, "Delete" text on others. Going forward:

- Detail pages → `delete_button(resource)` (always `🗑` with `title: "Delete"`).
- Index pages → unchanged behaviour, but renamed or routed through a new index-context helper if it stays divergent.

Simplest path: keep `destroy_link` for index pages (the only remaining caller), unchanged. Detail pages use the new `delete_button`. Each helper does one thing.

## Glyph policy (for CLAUDE.md)

Emoji is a text-shortener, not decoration. Three tiers:

- **Text only** — when the label is already short and universally clear: `Edit`, `+ New`, `Cancel`, `Save`, `Reset passkeys`. Don't prefix with a glyph.
- **Glyph + text** — for less-familiar workflow actions where the glyph aids scanning but the text is still required: `🚀 Publish`, `🚀 Convert to Invoice`, `🧪 Test Booking`, etc.
- **Glyph only with `title:`** — for actions whose glyph is universally understood and whose label is fully replaceable: `🗑` Delete, `📄` PDF, `👁` Preview. Always pass `title:` to set both the hover tooltip and the screen-reader `aria-label`.

Label-shortening rule: when a glyph already carries the verb concept and the remaining noun/state is clear, drop the leading verb in the label. So `Mark Paid` → `✅ Paid` (✅ = the verb, "Paid" = the state). Keep `🚀 Publish` etc. full when the verb/object isn't carried by the glyph alone.

Glyph reuse is intentional when the action archetype is the same:
- 🚀 = "promote forward" (Publish + Convert to Invoice)
- ✅ = "positive state change" (Paid + Unblock)
- ↩/↩️ = "revert state" (Unpaid + Unpublish)

Established mapping — extend this table, don't invent new glyphs for existing verbs:

| Verb | Render | Tier | Helper |
|---|---|---|---|
| Edit | `Edit` | text-only | (use `action_button`) |
| + New | `+ New` | text-only | (use `action_button`) |
| Cancel | `Cancel` | text-only | `cancel_button` (existing) |
| Reset passkeys | `Reset passkeys` | text-only | `reset_passkeys_button` |
| Delete | `🗑` (title: "Delete") | glyph-only | `delete_button` |
| PDF | `📄` (title: "PDF") | glyph-only | `pdf_button` |
| Preview | `👁` (title: "Preview") | glyph-only | `preview_button` |
| Mark Paid | `✅ Paid` | glyph + shortened text | `mark_paid_button` |
| Mark Unpaid | `↩ Unpaid` | glyph + shortened text | `mark_unpaid_button` |
| Send e-mail | `✉️ Send` | glyph + text | `send_email_button` |
| Publish | `🚀 Publish` | glyph + text | `publish_button` |
| Unpublish | `↩️ Unpublish` | glyph + text | `unpublish_button` |
| Convert to Invoice | `🚀 Convert to Invoice` | glyph + text | `convert_to_invoice_button` |
| Upload PDF | (file-upload form — out of scope) | — | — |
| Block / Unblock | `🚫 Block` / `✅ Unblock` | glyph + text | `block_button` / `unblock_button` |
| Audit log | `📋 Audit log` | glyph + text | `audit_log_button` |

## Per-page migration

For each show view: delete its `= action_buttons_wrapper do ... end`, build an `actions:` array from per-verb helpers, pass it to `breadcrumbs`.

> Path helper names (`pdf_invoice_path`, `test_book_invoice_path`, etc.) and permission keys (`'invoices.read'` etc.) in the examples below are illustrative — the implementation should use whatever the routes file and `Permission` model actually define.

### `app/views/invoices/show.html.haml`

After PR #382 lands (this PR is stacked on top of #382), the invoice show bottom row is simpler: **PDF or Preview** (depending on whether the invoice has an attachment) **and Delete** (only when not published). Test Booking is gone — replaced by an inline-validation **Book Invoice** button living inside the **Booking Status** status row (`.col-sm-8.d-flex.align-items-center.gap-2`), which is out of scope per the status-row rule. Edit stays as the breadcrumb `action:`.

```haml
- edit_action = action_button('Edit', edit_invoice_path(@invoice), permission: 'invoices.edit') unless @invoice.published?
- workflow_actions = [
-   (@invoice.attachment ? pdf_button(@invoice.attachment) : preview_button(preview_invoice_path(@invoice))),
-   (delete_button(@invoice, confirm: "Are you sure you want to delete invoice \"#{@invoice.document_number || "##{@invoice.id}"}\"?") if !@invoice.published? && can_edit_invoice),
- ]
= breadcrumbs ['Invoices', invoices_path], (@invoice.document_number || "Draft ##{@invoice.id}"), actions: workflow_actions, action: edit_action do
  -# status badges unchanged
```

Note: the post-booking green `.alert.alert-success` (Download PDF / Send E-Mail from `params[:booked] == '1'`) is its own body banner introduced by #382 — not part of `action_buttons_wrapper`, not in scope.

### `app/views/delivery_notes/show.html.haml`

Today's bottom row branches on `published?`:

- published: PDF, Convert to Invoice (if no invoice exists yet), Unpublish, Delete
- draft: Preview, Publish, Delete

The Acceptance Document upload form (input-group inside the card) stays where it is — it's a body-section UI, not part of the action_buttons_wrapper, and the recent PR #379 just landed its sizing fix.

```haml
- edit_action = action_button('Edit', edit_delivery_note_path(@delivery_note), permission: 'delivery_notes.edit') unless @delivery_note.published?
- workflow_actions = if @delivery_note.published?
-   [
-     pdf_button(pdf_delivery_note_path(@delivery_note)),
-     (convert_to_invoice_button(convert_to_invoice_delivery_note_path(@delivery_note), permission: 'delivery_notes.edit', confirm: 'Create an invoice draft from this delivery note?') unless @delivery_note.invoice),
-     unpublish_button(unpublish_delivery_note_path(@delivery_note), permission: 'delivery_notes.edit', confirm: 'Are you sure you want to revert this delivery note to draft status?'),
-     (delete_button(@delivery_note) if can?('delivery_notes.delete')),
-   ]
- else
-   [
-     preview_button(preview_delivery_note_path(@delivery_note)),
-     publish_button(publish_delivery_note_path(@delivery_note), permission: 'delivery_notes.edit'),
-     (delete_button(@delivery_note) if can?('delivery_notes.delete')),
-   ]
- end
= breadcrumbs ['Delivery Notes', delivery_notes_path], (@delivery_note.document_number || "Draft ##{@delivery_note.id}"), actions: workflow_actions, action: edit_action do
  -# status badges unchanged
```

### `app/views/customers/show.html.haml`

Today's bottom row: Invoices, Delivery Notes, Delete. Edit stays in `action:`. The "Invoices" and "Delivery Notes" buttons are navigational (jump to filtered list scoped to this customer) and have no clear glyph. Default to text labels for now; revisit later if the row feels crowded.

```haml
- workflow_actions = [
-   action_button('Invoices', invoices_path(customer_id: @customer.id), :secondary, permission: 'invoices.read'),
-   action_button('Delivery Notes', delivery_notes_path(customer_id: @customer.id), :secondary, permission: 'delivery_notes.read'),
-   (delete_button(@customer) if can?('customers.delete')),
- ]
= breadcrumbs ['Customers', customers_path], @customer.matchcode, actions: workflow_actions, action: action_button('Edit', edit_customer_path(@customer), permission: 'customers.edit') do
  -# Inactive badge unchanged
```

### `app/views/users/show.html.haml`

Today's bottom row: Block/Unblock, Reset passkeys, Audit log. No `action:` button today (the breadcrumb has only badges). After this PR the breadcrumb gains an `actions:` array.

```haml
- workflow_actions = [
-   (@user.blocked? ? unblock_button(unblock_user_path(@user)) : block_button(block_user_path(@user))),
-   reset_passkeys_button(reset_credentials_user_path(@user)),
-   audit_log_button(audit_user_path(@user)),
- ]
= breadcrumbs 'Configuration', ['Users', users_path], @user.username, actions: workflow_actions do
  -# Blocked / "This is you" badges unchanged
```

### Other show pages

- `products/show`, `groups/show`, `teams/show`, `issuer_companies/show`, `sales_tax_*/show`, `jobs_status/show`, `user_invites/show_invite` — no `action_buttons_wrapper` today. No change.
- `users/audit.html.haml` — no bottom row. No change.

## CSS

No CSS changes needed. The existing `nav[aria-label="breadcrumb"] .btn` rule (btn-sm sizing via Bootstrap CSS variables) already handles a cluster of buttons. The `min-height: 2.5rem` on the row prevents layout jump.

## Tests

- Run the full unit + system test suite. Most existing assertions don't depend on button position; they look for buttons by text (`click_on "Publish"`, `find('button', text: 'Delete')`) which keeps working.
- One known sensitivity: any test that searches for `🗑` text on detail pages may need an update if it previously found `"Delete"` text. Sweep `test/` after the migration.
- Add a single helper-method unit test (one example per Tier) to guard the glyph output — e.g. `assert_dom_equal "<a class='btn btn-danger' title='Delete' ...>🗑</a>", delete_button(@customer)`. Belt-and-suspenders against accidental glyph drift in the helpers themselves.

## CLAUDE.md updates

- Add a new section under "Development Preferences" titled **"Button Glyphs (Show-page Actions)"**, containing the full policy + glyph table verbatim from this spec.
- Extend "UI Helper Methods" with: `breadcrumbs(*items, action:, actions:, &status_block)` (note the new `actions:`); a one-line description of `action_button(...)`'s new `title:` kwarg; and a one-line summary plus pointer for the per-verb helpers ("see Button Glyphs section for the full table").
- Drop the `destroy_link` index/detail behaviour from the helper inventory (now `destroy_link` is index-only; detail uses `delete_button`).

## Verification

1. `bundle exec rails test`
2. `bundle exec rails test test/system/`
3. `pre-commit run --all-files`
4. Eyeball check on the dev server:
   - Invoice show in each lifecycle state (draft / booked / paid / overdue / sent) — confirm all expected buttons in the cluster, correct ordering, Edit on the right.
   - Delivery note show in published vs draft — confirm branch logic produces the right set, the Acceptance Document section is untouched.
   - Customer show active vs inactive — confirm Inactive badge + Invoices/DNs/Delete + Edit.
   - User show self / other / blocked — confirm Block/Unblock/Reset/Audit cluster.

## Files touched (anticipated)

- `app/helpers/application_helper.rb` (extend `breadcrumbs` and `action_button`; remove detail-page branch from `destroy_link`)
- `app/helpers/action_buttons_helper.rb` (new — per-verb helpers)
- `app/views/invoices/show.html.haml`
- `app/views/delivery_notes/show.html.haml`
- `app/views/customers/show.html.haml`
- `app/views/users/show.html.haml`
- `CLAUDE.md`
- `test/helpers/action_buttons_helper_test.rb` (new — tier coverage)
- Possibly `test/system/*.rb` for any sweeps surfaced during migration
