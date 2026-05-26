module ApplicationHelper
  # Permission check helper for views. Uses current_user via the controller
  # (already defined as a helper_method in ApplicationController).
  def can?(key)
    !!Current.user&.permission?(key)
  end

  def current_currency
    @current_currency ||= IssuerCompany.get_the_issuer!&.currency || "EUR"
  end

  def page_title
    issuer = IssuerCompany.get_the_issuer!
    if issuer&.short_name.present?
      "ABT: #{issuer.short_name}"
    else
      "ABT"
    end
  end

  def format_currency(amount)
    return "" if amount.nil?
    case current_currency
    when "EUR"
      "€#{sprintf('%.2f', amount)}"
    when "USD"
      "$#{sprintf('%.2f', amount)}"
    when "GBP"
      "£#{sprintf('%.2f', amount)}"
    else
      "#{current_currency} #{sprintf('%.2f', amount)}"
    end
  end

  # If `permission:` is given, the +New / Edit button is hidden unless the
  # current user holds that key. The header itself always renders so users
  # with .view-only access still see the page heading. Controllers gate the
  # actual action server-side; this just keeps the UI honest.
  def page_header_with_new_button(title, new_path, permission: nil)
    content_tag :div, class: "d-flex justify-content-between align-items-center mb-3" do
      header = content_tag(:h1, title, class: "page-header mb-0")
      button = (permission.nil? || can?(permission)) ? link_to("+ New", new_path, class: "btn btn-info") : "".html_safe
      header + button
    end
  end

  def page_header_with_edit_button(title, edit_path, permission: nil, &status_block)
    content_tag :div, class: "d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2" do
      title_area = content_tag(:div, class: "d-flex align-items-center flex-wrap gap-2") do
        header = content_tag(:h1, title, class: "page-header mb-0")
        status = status_block ? capture(&status_block) : "".html_safe
        header + status
      end
      button = (permission.nil? || can?(permission)) ? link_to("Edit", edit_path, class: "btn btn-primary") : "".html_safe
      title_area + button
    end
  end

  def page_header(title)
    content_tag(:h1, title, class: "page-header mb-3")
  end

  def list_action_link(text, path, type = :default, options = {})
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

  def destroy_link(resource, confirm_text = nil)
    confirm_text ||= "Are you sure you want to delete this #{resource.class.name.downcase}?"

    if action_name == "index"
      # Show trashcan icon on index pages (space-saving)
      list_action_link("🗑", resource, :destroy, {
        data: {
          'turbo-method': "delete",
          'turbo-confirm': confirm_text
        }
      })
    else
      # Show "Delete" text on detail pages with proper action button styling
      link_to("Delete", resource, {
        data: {
          'turbo-method': "delete",
          'turbo-confirm': confirm_text
        },
        class: "btn btn-danger"
      })
    end
  end

  def action_buttons_wrapper(&block)
    content_tag :div, class: "d-flex gap-2 mb-3 mt-3", &block
  end

  def action_button(text, path, type = :primary, options = {})
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

    link_to(text, path, options.merge(class: css_class))
  end

  def cancel_button(resource)
    # Determine the appropriate cancel destination based on action
    cancel_path = case action_name
    when "edit", "update"
      # When editing, go back to list page
      polymorphic_path(resource.class)
    when "new", "create"
      # When creating new, go back to list page
      polymorphic_path(resource.class)
    else
      # Default to show page
      resource
    end

    action_button("Cancel", cancel_path, :secondary)
  end

  def app_version
    Rails.application.config.x.app_version
  end
end
