# Card and table visual identity

This documents the design decisions behind the `.card` and line-item table
styling in `bootstrap_and_overrides.css.scss` / `documents.css.scss`, so
future changes stay consistent instead of drifting back toward stock
Bootstrap. Edit forms are intentionally out of scope here; they will get
their own pass separately.

## Page background

The app body background is a soft tint rather than plain white/near-black,
so cards read as a distinct surface without needing a border:

- Light: `#f4f6f6`
- Dark: `#17191a`

Cards keep their own surface color (`#fff` light / `#212529` dark,
Bootstrap's stock dark surface) independent of the page background.

## Cards

- No border, no box-shadow on `.card`.
- `.card-header`, when present, drops its background/border in favor of a
  2px solid teal rule (`$primary`, tinted 40% in dark mode) — the same
  weight/color already used under `.table thead th`. Header text stays a
  normal heading, no uppercase/eyebrow treatment.
- `.card-body` immediately following a `.card-header` keeps normal top
  padding; a `.card-body` with no preceding header (e.g. the plain
  boilerplate card on `offers/show`) gets a reduced top padding instead of
  reserving space for a header that isn't there.
- Layout (grid of `.card`s in `.row > .col-md-*`) is unchanged — this is a
  CSS-only restyle.

## Tables

`table.document-lines-table` and the offer-milestones table both drop their
own header/border treatment and inherit the generic `.table` rules (2px
teal header rule, faint teal zebra stripe, teal hover) instead of each
having a slightly different look:

- `document-lines-table` no longer paints its own gray header or its own
  `nth-child(even)` stripe; only column-width rules and the
  section/free-text row treatments remain bespoke.
- The offer-milestones table drops `table-bordered` (no more full grid) and
  gets a `.table-total-row` modifier for its totals row (2px teal top rule,
  no boxed borders) instead of relying on Bootstrap's default cell borders.
- No table is wrapped in a card shell — tables stay directly in their
  existing containers.
- `document-lines-table`'s cell horizontal padding is `1rem`, matching
  `.card-body`'s inset (`--bs-card-spacer-x`) — a bare table sits directly
  below/above cards on the same page (invoice/delivery-note show), so its
  text needs to line up with theirs rather than sitting closer to the edge
  at Bootstrap's default `0.5rem` table padding.
- A `.table` sitting *inside* a `.card-body` (offer milestones, sales-tax
  rate lists, jobs-status worker tables) hits the opposite problem: its own
  `0.5rem` cell padding stacks on top of the card-body's `1rem` inset
  instead of matching it, so the first/last column sits further in than any
  label text above it in the same card. `.card-body table` zeroes the
  outer-edge cell padding (`th:first-child`/`td:first-child` left,
  `th:last-child`/`td:last-child` right) so the table's edge lines up with
  the card's own inset instead of double-indenting.
