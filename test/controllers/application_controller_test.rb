require "test_helper"
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "app routes 404 on the customer portal host" do
    host! Settings.customer_portal.host
    get delivery_notes_url
    assert_response :not_found
  end
end
