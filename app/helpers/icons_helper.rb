module IconsHelper
  # Inline monochrome SVG icons, sourced from the bootstrap-icons gem rather
  # than copied path data, so icon geometry stays correct and updatable via
  # bundle update. The two entry points differ only in default size and in the
  # context they document.

  # Navbar chrome — Configuration, the account link, Sign out. See
  # docs/code-style.md's "Navigation icons" section.
  def nav_icon(name, size: 15)
    bootstrap_icon_svg(name, size)
  end

  # Inline use inside action-button labels (Delete, Publish, Mark Paid, ...).
  # See docs/code-style.md's "Action button icons" section.
  def action_icon(name, size: 14)
    bootstrap_icon_svg(name, size)
  end

  private

  def bootstrap_icon_svg(name, size)
    BootstrapIcons::BootstrapIcon.new(name.to_s.tr("_", "-"), width: size, height: size).to_svg.html_safe
  end
end
