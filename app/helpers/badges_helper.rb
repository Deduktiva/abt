module BadgesHelper
  # Semantic level => Bootstrap background class. Views never interpolate a
  # level into a class string: brakeman flags it, and it lets a caller's
  # vocabulary drift from what actually renders (45819f8d quietly remapped a
  # :danger badge to grey inside one helper, so the model's own word for the
  # state stopped describing the page).
  #
  #   :neutral - inert fact, no action implied (Inactive, built-in, counts)
  #   :info    - informational, not actionable (This is you, This session)
  #   :success - healthy or complete (Booked, Paid, Confirmed, Ready)
  #   :warning - needs attention (Unsent, Pending, Not verified)
  #   :danger  - broken or overdue (Overdue, Blocked, Stale)
  #   :accent  - current step in a flow (Ordered)
  BADGE_LEVELS = {
    neutral: "bg-secondary",
    info: "bg-info",
    success: "bg-success",
    warning: "bg-warning",
    danger: "bg-danger",
    accent: "bg-primary"
  }.freeze

  # Renders one status badge. Whether a badge belongs on the page at all is the
  # caller's decision (see docs/code-style.md) - this only renders what it is
  # given, and fetch raises on an unknown level rather than emitting an
  # unstyled pill.
  def badge_tag(level, text, css: nil)
    content_tag(:span, text, class: [ "badge", BADGE_LEVELS.fetch(level), css ].compact.join(" "))
  end
end
