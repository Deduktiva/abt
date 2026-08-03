module BadgesHelper
  # Semantic level => Bootstrap background class. Levels name what a state
  # means; this table is the only place that decides how it looks. See
  # docs/code-style.md for what each level covers and how to pick one.
  BADGE_LEVELS = {
    neutral: "bg-secondary",
    info: "bg-info",
    active: "bg-primary",
    warning: "bg-warning",
    danger: "bg-danger",
    success: "bg-success"
  }.freeze

  # Renders one status badge. Whether a badge belongs on the page at all is the
  # caller's decision - this only renders what it is given.
  def badge_tag(level, text, css: nil)
    content_tag(:span, text, class: [ "badge", BADGE_LEVELS.fetch(level), css ].compact.join(" "))
  end

  # Renders a model's { level:, text: } status badge, or nothing when the model
  # returns nil for a state that warrants no badge. Takes the badge rather than
  # the record because Invoice exposes two of them.
  def status_badge_tag(badge)
    return unless badge

    badge_tag(badge[:level], badge[:text])
  end
end
