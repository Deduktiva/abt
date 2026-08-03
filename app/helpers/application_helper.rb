module ApplicationHelper
  # Permission check helper for views. Uses current_user via the controller
  # (already defined as a helper_method in ApplicationController).
  def can?(key)
    !!Current.user&.permission?(key)
  end

  # Renders the breadcrumb strip that serves as the page header on every
  # index/show/edit/new page. The active (last) crumb is the page identifier;
  # optional status badges (via the block) sit next to it; the right cluster
  # carries optional secondary actions (`actions:`, an array) followed by the
  # primary action (`action:`, single) rightmost.
  #
  # Items are either:
  #   - [label, path]  → rendered as a link
  #   - label          → rendered as plain text (non-link)
  # The last item is always rendered as the active (current) crumb, regardless
  # of whether a path was given.
  #
  # `actions:` accepts an array of pre-built buttons (action_button,
  # delete_button, button_to forms, etc). nil entries are compacted out, so
  # views can rely on permission-gated helpers returning nil.
  #
  #   = breadcrumbs ['Customers', customers_path], @customer.display_name
  #   = breadcrumbs ['Customers', customers_path], @customer.matchcode,
  #       actions: [delete_button(@customer)],
  #       action: action_button('Edit', edit_customer_path(@customer)) do
  #     - unless @customer.active?
  #       = badge_tag(:neutral, 'Inactive')
  def breadcrumbs(*items, action: nil, actions: nil, &status_block)
    active_label, _ = Array(items.last)
    content_for(:title, active_label) if active_label.present? && !content_for?(:title)
    nav = content_tag :nav, "aria-label": "breadcrumb" do
      content_tag :div, class: "d-flex justify-content-between align-items-center flex-wrap gap-2 border-bottom py-1 mb-2" do
        left = content_tag(:div, class: "d-flex align-items-center flex-wrap gap-2 small") do
          ol = content_tag :ol, class: "breadcrumb mb-0" do
            last_index = items.length - 1
            items.each_with_index.map { |item, i|
              label, path = Array(item)
              if i == last_index
                content_tag(:li, label, class: "breadcrumb-item active fw-semibold", "aria-current": "page")
              elsif path
                content_tag(:li, link_to(label, path), class: "breadcrumb-item")
              else
                content_tag(:li, label, class: "breadcrumb-item")
              end
            }.join.html_safe
          end
          ol + (status_block ? capture(&status_block) : "".html_safe)
        end
        action_cluster_html = Array(actions).compact.map { |a| a }.join.html_safe + (action || "".html_safe)
        right = action_cluster_html.empty? ? "".html_safe : content_tag(:div, action_cluster_html, class: "d-flex align-items-center flex-wrap gap-2")
        left + right
      end
    end
    nav + page_header_flash
  end

  # Renders the page header row: title (left), optional inline status badges
  # (left, via the block), optional action button (right).
  #
  # action: a pre-rendered button (use action_button with permission: to get a
  #   nil-when-denied result), or nil for no action area.
  # status_block: yields zero or more inline badges next to the title.
  def page_header(title, action: nil, &status_block)
    content_for(:title, title) if title.present? && !content_for?(:title)
    header_row = content_tag :div, class: "d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2" do
      title_area = content_tag(:div, class: "d-flex align-items-center flex-wrap gap-2") do
        header = content_tag(:h1, title, class: "mb-0")
        status = status_block ? capture(&status_block) : "".html_safe
        header + status
      end
      title_area + (action || "".html_safe)
    end
    header_row + page_header_flash
  end

  # Renders flash messages inline (just below the page header / breadcrumb)
  # and sets a sentinel so the layout suppresses its top-of-content fallback.
  # Keeps the page identifier anchored at the top so flash never pushes it
  # down between visits.
  def page_header_flash
    content_for(:flash_rendered_inline, true)
    render("layouts/messages")
  end

  def app_version
    Rails.application.config.x.app_version
  end

  # Trix editor bound to the rich-text controller, which strips the file tools
  # and blocks attachments. The blank upload URLs are load-bearing: ActionText
  # otherwise defaults them to Active Storage route helpers, and those routes
  # are not drawn (config/application.rb). They must be non-nil — ActionText
  # fills the defaults in with `||=`.
  def rich_text_field(form, method)
    form.rich_text_area method,
      data: { controller: "rich-text", direct_upload_url: "", blob_url_template: "" }
  end
end
