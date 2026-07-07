# Proposal: bootstrap-icons for action-button glyphs

`bootstrap-icons` was added to the app for navbar chrome only (`nav_icon`,
`app/helpers/application_helper.rb`) — Configuration, the account link, Sign
out. `docs/code-style.md`'s "Action button glyphs" table still uses emoji for
workflow buttons (Delete, PDF, Publish, Mark Paid, etc.), on the explicit
rationale that emoji's cross-platform rendering inconsistency "matters for
chrome that's on screen at all times; it doesn't matter enough for one-off
action buttons to be worth a second icon mechanism there."

This proposes revisiting that call now that the icon mechanism already
exists in the app. No view or helper code changes are in this branch — it's
options to choose from before any implementation.

## Adoption strategy — pick one

**A. Full replacement** — swap every glyph-table emoji (both the
glyph-only and glyph+text tiers) for a `bootstrap-icons` SVG. One icon
mechanism app-wide; icons inherit the button's text color instead of
carrying their own fixed emoji color. Largest diff — every glyph-table row
gets a helper change, every view using one is touched.

**B. Selective replacement (recommended)** — only replace the glyphs whose
cross-platform rendering has actually been an issue: 🚀 🗑 📄 👁 ✅ ↩ 🚫 📥.
Leave low-risk ones (✉️, 📋) as emoji unless there's a concrete complaint.
Smaller diff, but leaves the glyph table in two visual languages until a
follow-up finishes the job.

**C. Keep emoji, no change** — the existing rationale was a deliberate
call, not an oversight; adding the gem for the navbar doesn't itself change
the tradeoff for one-off action buttons. Zero migration cost, but the new
icon set stays unused outside chrome.

## Per-verb candidates

Icon names are real, verified against the installed `bootstrap-icons`
1.0.15 gem data (`lib/build/data.json`) — not guessed. Recommended pick is
listed first.

| Verb | Current | Candidates (recommended first) |
|---|---|---|
| Delete | 🗑 | `trash`, `trash3` |
| PDF | 📄 | `file-earmark-pdf`, `file-earmark-pdf-fill`, `file-earmark-text` |
| Preview | 👁 | `eye`, `eye-fill`, `eyeglasses` |
| Mark Paid | ✅ Paid | `check-circle`, `check-circle-fill`, `patch-check` |
| Mark Unpaid | ↩ Unpaid | `arrow-counterclockwise`, `x-circle`, `dash-circle` |
| Send e-mail | ✉️ Send | `envelope`, `envelope-fill`, `send` |
| Publish | 🚀 Publish | `rocket`, `rocket-fill`, `rocket-takeoff` |
| Unpublish | ↩️ Unpublish | `arrow-counterclockwise`, `box-arrow-in-left`, `reply` |
| Convert to Invoice | 🚀 Create… | `rocket`, `arrow-right-circle`, `receipt` |
| Upload PDF | 📥 Upload PDF | `cloud-upload`, `upload`, `box-arrow-in-up` |
| Block | 🚫 Block | `slash-circle`, `shield-slash`, `x-octagon` |
| Unblock | ✅ Unblock | `check-circle`, `shield-check`, `check-circle-fill` |
| Audit log | 📋 Audit log | `clock-history`, `journal-check`, `list-check` |

Glyph-reuse pairs from the existing policy carry over to the recommended
icon picks: `rocket` for both Publish and Convert to Invoice ("promote
forward"), `arrow-counterclockwise` for both Mark Unpaid and Unpublish
("revert state"), `check-circle` for both Mark Paid and Unblock ("positive
state change").

## Not in scope here

- The text-only glyph tier (Edit, + New, Save, Reset passkeys) — those never
  had a glyph and this proposal doesn't add one.
- Any actual helper/view changes — pending a decision on the strategy and
  per-verb picks above.
