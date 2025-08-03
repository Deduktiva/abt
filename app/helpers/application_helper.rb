module ApplicationHelper

  def display_base_errors resource
    return '' if (resource.errors.empty?) or (resource.errors[:base].empty?)
    messages = resource.errors[:base].map { |msg| content_tag(:p, msg) }.join
    html = <<-HTML
    <div class="alert alert-error alert-block">
      <button type="button" class="close" data-dismiss="alert">&#215;</button>
      #{messages}
    </div>
    HTML
    html.html_safe
  end

  def current_currency
    @current_currency ||= IssuerCompany.get_the_issuer!&.currency || 'EUR'
  end

  def format_currency(amount)
    return '' if amount.nil?
    case current_currency
    when 'EUR'
      "€#{sprintf('%.2f', amount)}"
    when 'USD'
      "$#{sprintf('%.2f', amount)}"
    when 'GBP'
      "£#{sprintf('%.2f', amount)}"
    else
      "#{current_currency} #{sprintf('%.2f', amount)}"
    end
  end

  def page_header_with_new_button(title, new_path)
    content_tag :div, class: 'd-flex justify-content-between align-items-center mb-3' do
      content_tag(:h1, title, class: 'page-header mb-0') +
      link_to('+ New', new_path, class: 'btn btn-info')
    end
  end

  def list_action_link(text, path, type = :default, options = {})
    css_classes = case type
    when :show
      'btn btn-sm btn-outline-primary py-0'
    when :edit
      'btn btn-sm btn-outline-secondary py-0'
    when :destroy
      'btn btn-sm btn-outline-danger py-0'
    else
      'btn btn-sm btn-outline-primary py-0'
    end

    link_to(text, path, options.merge(class: css_classes))
  end

  def destroy_link(resource, confirm_text = nil)
    confirm_text ||= "Are you sure you want to delete this #{resource.class.name.downcase}?"
    list_action_link('🗑', resource, :destroy, {
      data: {
        'turbo-method': 'delete',
        'turbo-confirm': confirm_text
      }
    })
  end

end
