require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "breadcrumbs auto-sets content_for :title from the last item label" do
    breadcrumbs([ "Customers", "/customers" ], "Acme")
    assert_equal "Acme", content_for(:title)
  end

  test "breadcrumbs does not override an explicit content_for :title" do
    content_for :title, "Custom"
    breadcrumbs([ "Customers", "/customers" ], "Acme")
    assert_equal "Custom", content_for(:title)
  end

  test "page_header auto-sets content_for :title from its title" do
    page_header("Business Dashboard")
    assert_equal "Business Dashboard", content_for(:title)
  end

  test "app_version returns test-version in test environment" do
    assert_equal "test-version", app_version
  end

  test "format_currency uses the issuer's money_decimal_places" do
    issuer_companies(:one).update!(money_decimal_places: 3)
    assert_equal "€12.340", format_currency(12.34)
  end

  test "app_version caches result to avoid repeated calls" do
    # First call should set the instance variable
    first_call = app_version

    # Second call should return cached value
    second_call = app_version

    assert_equal first_call, second_call
    assert_equal "test-version", second_call
  end

  test "breadcrumbs renders a nav with aria-label" do
    html = Nokogiri::HTML.fragment(breadcrumbs([ "Customers", "/customers" ], "Acme"))
    nav = html.at_css("nav")
    assert_not_nil nav
    assert_equal "breadcrumb", nav["aria-label"]
    assert_not_nil nav.at_css("ol.breadcrumb")
  end

  test "breadcrumbs renders link items for [label, path] pairs except the last" do
    html = Nokogiri::HTML.fragment(breadcrumbs([ "Customers", "/customers" ], "Acme"))
    items = html.css("li.breadcrumb-item")
    assert_equal 2, items.length

    first = items[0]
    assert_includes first["class"], "breadcrumb-item"
    refute_includes first["class"].to_s.split, "active"
    link = first.at_css("a")
    assert_not_nil link
    assert_equal "Customers", link.text
    assert_equal "/customers", link["href"]
  end

  test "breadcrumbs renders the last item as active with aria-current=page" do
    html = Nokogiri::HTML.fragment(breadcrumbs([ "Customers", "/customers" ], "Acme"))
    last = html.css("li.breadcrumb-item").last
    assert_includes last["class"].split, "active"
    assert_equal "page", last["aria-current"]
    assert_nil last.at_css("a")
    assert_equal "Acme", last.text.strip
  end

  test "breadcrumbs forces the last item to be active even if a path is given" do
    html = Nokogiri::HTML.fragment(breadcrumbs([ "Customers", "/customers" ], [ "Acme", "/customers/1" ]))
    last = html.css("li.breadcrumb-item").last
    assert_includes last["class"].split, "active"
    assert_equal "page", last["aria-current"]
    assert_nil last.at_css("a")
    assert_equal "Acme", last.text.strip
  end

  test "breadcrumbs sets the flash_rendered_inline sentinel" do
    breadcrumbs([ "Customers", "/customers" ], "Acme")
    assert content_for?(:flash_rendered_inline)
  end

  test "breadcrumbs emits flash messages inline below the breadcrumb" do
    flash[:notice] = "Saved!"
    html = Nokogiri::HTML.fragment(breadcrumbs([ "Customers", "/customers" ], "Acme"))
    alert = html.at_css(".alert.alert-success")
    assert_not_nil alert, "expected flash alert to be rendered inline by breadcrumbs"
    assert_includes alert.text, "Saved!"
  end

  test "page_header sets the flash_rendered_inline sentinel and emits flash inline" do
    flash[:alert] = "Nope"
    html = Nokogiri::HTML.fragment(page_header("Dashboard"))
    assert content_for?(:flash_rendered_inline)
    alert = html.at_css(".alert.alert-danger")
    assert_not_nil alert
    assert_includes alert.text, "Nope"
  end

  test "list_action_link without permission: renders the link" do
    html = Nokogiri::HTML.fragment(list_action_link("Edit", "/customers/1/edit", :edit))
    a = html.at_css("a")
    assert_not_nil a
    assert_equal "Edit", a.text
    assert_equal "/customers/1/edit", a["href"]
  end

  test "list_action_link with permission: returns the link when user has it" do
    Current.user = users(:alice)
    html = Nokogiri::HTML.fragment(list_action_link("Edit", "/customers/1/edit", :edit, permission: "customers.edit").to_s)
    a = html.at_css("a")
    assert_not_nil a
    assert_equal "Edit", a.text
  ensure
    Current.user = nil
  end

  test "list_action_link with permission: returns nil when user lacks it" do
    Current.user = users(:bob)
    assert_nil list_action_link("Edit", "/customers/1/edit", :edit, permission: "customers.edit")
  ensure
    Current.user = nil
  end

  test "list_action_link with permission: returns nil when no current user" do
    Current.user = nil
    assert_nil list_action_link("Edit", "/customers/1/edit", :edit, permission: "customers.edit")
  end

  test "destroy_link without permission: renders the link" do
    customer = customers(:good_eu)
    html = Nokogiri::HTML.fragment(destroy_link(customer).to_s)
    a = html.at_css("a")
    assert_not_nil a
    assert_not_nil a.at_css("svg.bi-trash3")
    assert_equal "Delete", a["title"]
  end

  test "destroy_link with permission: returns the link when user has it" do
    Current.user = users(:alice)
    customer = customers(:good_eu)
    html = Nokogiri::HTML.fragment(destroy_link(customer, nil, permission: "customers.edit").to_s)
    a = html.at_css("a")
    assert_not_nil a
    assert_not_nil a.at_css("svg.bi-trash3")
    assert_equal "Delete", a["title"]
  ensure
    Current.user = nil
  end

  test "destroy_link with permission: returns nil when user lacks it" do
    Current.user = users(:bob)
    customer = customers(:good_eu)
    assert_nil destroy_link(customer, nil, permission: "customers.edit")
  ensure
    Current.user = nil
  end

  test "destroy_link with permission: returns nil when no current user" do
    Current.user = nil
    customer = customers(:good_eu)
    assert_nil destroy_link(customer, nil, permission: "customers.edit")
  end

  test "action_buttons_wrapper wraps non-empty block content in a flex div" do
    html = Nokogiri::HTML.fragment(action_buttons_wrapper { "<a>Go</a>".html_safe })
    div = html.at_css("div")
    assert_not_nil div
    assert_equal "d-flex gap-2 mb-3 mt-3", div["class"]
    assert_not_nil div.at_css("a")
  end

  test "action_buttons_wrapper returns nil when the block is empty" do
    assert_nil action_buttons_wrapper { "" }
  end

  test "currency_symbol maps each currency to its symbol, falling back to the raw code" do
    { "EUR" => "€", "USD" => "$", "GBP" => "£", "CHF" => "CHF" }.each do |currency, symbol|
      @current_currency = currency
      assert_equal symbol, currency_symbol
    end
  end

  test "format_currency prefixes the amount with the currency symbol" do
    @current_currency = "EUR"
    assert_equal "€60.00", format_currency(60)
  end

  test "format_currency returns blank for nil" do
    assert_equal "", format_currency(nil)
  end

  test "breadcrumbs renders plain-label middle crumbs without a link" do
    html = Nokogiri::HTML.fragment(breadcrumbs("Configuration", [ "Sales Tax", "/sales_tax_rates" ], "Edit"))
    items = html.css("li.breadcrumb-item")
    assert_equal 3, items.length

    config = items[0]
    refute_includes config["class"].to_s.split, "active"
    assert_nil config.at_css("a"), "non-link middle item should not contain an <a>"
    assert_equal "Configuration", config.text.strip

    sales = items[1]
    assert_not_nil sales.at_css("a")
    assert_equal "/sales_tax_rates", sales.at_css("a")["href"]

    last = items[2]
    assert_includes last["class"].split, "active"
  end

  test "nav_link_to marks the link active when the current controller matches" do
    params[:controller] = "delivery_notes"
    html = Nokogiri::HTML.fragment(nav_link_to("Deliveries", "/delivery_notes", active_for: "delivery_notes"))
    a = html.at_css("a")
    assert_includes a["class"].split, "active"
    assert_equal "page", a["aria-current"]
  end

  test "nav_link_to leaves the link inactive when the current controller differs" do
    params[:controller] = "projects"
    html = Nokogiri::HTML.fragment(nav_link_to("Customers", "/customers", active_for: "customers"))
    a = html.at_css("a")
    refute_includes a["class"].split, "active"
    assert_nil a["aria-current"]
  end

  test "dropdown_link_to keeps the dropdown-item base class and marks it active when matching" do
    params[:controller] = "products"
    html = Nokogiri::HTML.fragment(dropdown_link_to("Product Catalog", "/products", active_for: "products"))
    a = html.at_css("a")
    assert_includes a["class"].split, "dropdown-item"
    assert_includes a["class"].split, "active"
    assert_equal "page", a["aria-current"]
  end

  test "nav_section_active? matches a namespaced controller via its namespace token" do
    params[:controller] = "account/profiles"
    assert nav_section_active?("account")
    refute nav_section_active?("accounts")
  end
end
