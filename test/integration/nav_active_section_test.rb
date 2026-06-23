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
end
