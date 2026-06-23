require "test_helper"

class NavActiveSectionTest < ActionDispatch::IntegrationTest
  {
    "/customers" => "Customers",
    "/projects" => "Projects",
    "/delivery_notes" => "Deliveries",
    "/invoices" => "Invoices"
  }.each do |path, label|
    test "navbar highlights only #{label} on its section" do
      get path
      assert_response :success
      assert_select "ul.navbar-nav.me-auto a.nav-link.active[aria-current=page]", text: label, count: 1
      assert_select "ul.navbar-nav.me-auto a.nav-link.active", count: 1
    end
  end

  test "Configuration dropdown highlights its toggle and the matching item on a config section" do
    get "/products"
    assert_response :success
    assert_select "a.nav-link.dropdown-toggle.active", text: "Configuration"
    assert_select "a.dropdown-item.active[aria-current=page]", text: "Product Catalog"
  end

  test "user dropdown highlights its toggle and My account across the account namespace" do
    get "/account/emails"
    assert_response :success
    assert_select "a.nav-link.dropdown-toggle.active", text: users(:alice).username
    assert_select "a.dropdown-item.active[aria-current=page]", text: "My account"
  end
end
