require "test_helper"

class PageTitleTest < ActionDispatch::IntegrationTest
  test "dashboard title is auto-derived from page_header" do
    get root_path
    assert_response :success
    assert_select "title", text: "Business Dashboard"
  end

  test "index page title is auto-derived from the active breadcrumb" do
    get customers_path
    assert_response :success
    assert_select "title", text: "Customers"
  end
end
