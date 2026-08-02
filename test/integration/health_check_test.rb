require "test_helper"

# /up must answer on any host and without auth — the LB probes it directly.
class HealthCheckTest < ActionDispatch::IntegrationTest
  test "health check resolves on the app host" do
    host! Settings.app.host
    get "/up"
    assert_response :success
  end

  test "health check resolves on the customer portal host" do
    host! Settings.customer_portal.host
    get "/up"
    assert_response :success
  end

  test "health check resolves without authentication" do
    get "/up"
    assert_response :success
  end
end
