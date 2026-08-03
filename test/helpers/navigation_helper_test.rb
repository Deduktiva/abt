require "test_helper"

class NavigationHelperTest < ActionView::TestCase
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

  test "nav_section_active? matches a namespaced controller via its namespace token" do
    params[:controller] = "account/profiles"
    assert nav_section_active?("account")
    refute nav_section_active?("accounts")
  end
end
