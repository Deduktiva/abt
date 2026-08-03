module NavigationHelper
  # Top-level navbar link that highlights the current section. Marks the link
  # active (Bootstrap .active + aria-current) when the request belongs to one of
  # the controllers in `active_for`, so show/edit/new pages of a section stay
  # highlighted, not just its index. Pass a block instead of `label` to render
  # custom content (e.g. a mobile-only icon ahead of the text).
  def nav_link_to(label, path, active_for:, &block)
    active_nav_link("nav-link", label, path, active_for, &block)
  end

  # Whether the current request belongs to one of the given controller sections.
  # A bare name matches that controller exactly and any controller namespaced
  # below it ("account" matches "account/profiles"), so a whole namespace — or a
  # dropdown's worth of sections — can be expressed compactly.
  def nav_section_active?(*controllers)
    current = params[:controller].to_s
    controllers.flatten.any? { |c| current == c || current.start_with?("#{c}/") }
  end

  private

  def active_nav_link(base_class, label, path, active_for, &block)
    active = nav_section_active?(active_for)
    options = { class: "#{base_class}#{' active' if active}" }
    options["aria-current"] = "page" if active
    block ? link_to(path, options, &block) : link_to(label, path, options)
  end
end
