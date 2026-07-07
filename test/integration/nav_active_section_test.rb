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

  test "Configuration link highlights on a config section" do
    get "/products"
    assert_response :success
    assert_select "a.nav-link.active[aria-current=page]", text: /Configuration/
  end

  test "account link highlights across the account namespace" do
    get "/account/emails"
    assert_response :success
    assert_select "a.nav-link.active[aria-current=page]", text: /#{users(:alice).username}/
  end
end
