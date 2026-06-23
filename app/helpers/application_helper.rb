module ApplicationHelper
  # Permission check helper for views. Uses current_user via the controller
  # (already defined as a helper_method in ApplicationController).
  def can?(key)
    !!Current.user&.permission?(key)
  end

  def current_currency
    @current_currency ||= IssuerCompany.get_the_issuer!&.currency || "EUR"
  end

  def current_money_decimal_places
    @current_money_decimal_places ||= IssuerCompany.get_the_issuer!&.money_decimal_places || 2
  end

  # Symbol for the issuer currency, falling back to the raw code. Single source
  # of truth — the invoice line-total JS reads this via a Stimulus value rather
  # than mapping symbols itself. Never carries a trailing space, so callers
  # always prepend it the same way.
  def currency_symbol
    case current_currency
    when "EUR" then "€"
    when "USD" then "$"
    when "GBP" then "£"
    else current_currency
    end
  end

  def format_currency(amount)
    return "" if amount.nil?
    "#{currency_symbol}#{sprintf("%.#{current_money_decimal_places}f", amount)}"
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
  #       %span.badge.bg-secondary Inactive
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

  # Compact in-row action link (Edit / View / Delete...). When permission: is
  # given and the current user lacks it, returns nil so views can drop their
  # explicit `- if can?('xxx.edit')` wraps and gate inline.
  def list_action_link(text, path, type = :default, options = {}, permission: nil)
    return nil if permission && !can?(permission)
    css_classes = case type
    when :show
      "btn btn-sm btn-outline-primary py-0"
    when :edit
      "btn btn-sm btn-outline-secondary py-0"
    when :destroy
      "btn btn-sm btn-outline-danger py-0"
    else
      "btn btn-sm btn-outline-primary py-0"
    end

    link_to(text, path, options.merge(class: css_classes))
  end

  # Index-context delete link: a small outline trashcan that fits into row
  # actions. Detail-page delete uses `delete_button(resource)` (defined in
  # ActionButtonsHelper) — both render the 🗑 glyph, but the index variant is
  # the small btn-outline-danger sized for table rows.
  # When permission: is given and the current user lacks it, returns nil so
  # views can gate inline without an `- if can?('xxx.edit')` wrap.
  def destroy_link(resource, confirm_text = nil, permission: nil)
    return nil if permission && !can?(permission)
    confirm_text ||= "Are you sure you want to delete this #{resource.class.name.downcase}?"
    list_action_link("🗑", resource, :destroy, {
      data: {
        'turbo-method': "delete",
        'turbo-confirm': confirm_text
      }
    })
  end

  def action_buttons_wrapper(&block)
    content = capture(&block)
    return nil if content.blank?
    content_tag :div, content, class: "d-flex gap-2 mb-3 mt-3"
  end

  def action_button(text, path, type = :primary, permission: nil, target: nil, data: nil, title: nil)
    return nil if permission && !can?(permission)
    css_class = case type
    when :primary
      "btn btn-primary"
    when :secondary
      "btn btn-secondary"
    when :success
      "btn btn-success"
    when :info
      "btn btn-info"
    when :warning
      "btn btn-warning"
    when :danger
      "btn btn-danger"
    else
      "btn btn-primary"
    end

    link_to(text, path, class: css_class, target: target, data: data, title: title, "aria-label": title)
  end

  def app_version
    Rails.application.config.x.app_version
  end

  def country_options
    @country_options ||= ISO3166::Country.all
      .map { |c| [ c.iso_short_name, c.alpha2 ] }
      .sort_by { |name, _| name }
  end

  def country_name(code)
    AddressFormatter.country_name(code, locale: I18n.locale)
  end

  def country_unknown?(code)
    !AddressFormatter.valid_iso2?(code)
  end

  def status_badge_tag(resource)
    badge = resource.status_badge
    return unless badge

    bg = { info: "bg-info", success: "bg-success", warning: "bg-warning", danger: "bg-secondary" }.fetch(badge[:level])
    content_tag(:span, badge[:text], class: "badge #{bg}")
  end

  # Stimulus data attributes that wire an element up to the
  # generic-email-preview controller for a given Invoice or DeliveryNote.
  # Relies on the routes following the {action}_{resource}_path convention.
  def email_preview_data(resource)
    prefix = resource.class.name.underscore
    {
      controller: "generic-email-preview",
      "generic-email-preview-preview-url-value" => send("preview_email_#{prefix}_path", resource),
      "generic-email-preview-html-preview-url-value" => send("preview_email_html_#{prefix}_path", resource),
      "generic-email-preview-send-url-value" => send("send_email_#{prefix}_path", resource)
    }
  end
end
