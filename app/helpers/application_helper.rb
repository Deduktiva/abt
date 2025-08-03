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

end
