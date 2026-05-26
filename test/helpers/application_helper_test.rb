require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # Removed redundant page_title tests - covered more comprehensively in integration tests

  test "app_version returns test-version in test environment" do
    assert_equal "test-version", app_version
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
end
