require "test_helper"

# Active Storage exists only as ActionText plumbing — nothing in the app
# attaches files and the editor blocks attachments. Its routes stay undrawn so
# the unauthenticated direct-upload and disk-service endpoints cannot be used
# to write attacker-controlled bytes to the production disk. These endpoints
# inherit from ActiveStorage::BaseController, so neither the host constraints
# in config/routes.rb nor ApplicationController's filters apply to them.
class ActiveStorageRoutesTest < ActionDispatch::IntegrationTest
  BLOB_PARAMS = {
    blob: { filename: "evil.html", byte_size: 6, checksum: "rL0Y20zC+Fzt72VPzMSk2A==",
            content_type: "text/html" }
  }.freeze

  test "direct upload endpoint is not routable on the app host" do
    host! Settings.app.host
    assert_no_difference -> { ActiveStorage::Blob.count } do
      post "/rails/active_storage/direct_uploads", params: BLOB_PARAMS
    end
    assert_response :not_found
  end

  test "direct upload endpoint is not routable on the customer portal host" do
    host! Settings.customer_portal.host
    assert_no_difference -> { ActiveStorage::Blob.count } do
      post "/rails/active_storage/direct_uploads", params: BLOB_PARAMS
    end
    assert_response :not_found
  end

  # Asserted against the route set rather than over HTTP: the disk controller
  # answers an unrecognised token with the same 404 a missing route gives.
  test "disk service upload endpoint is not routable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/rails/active_storage/disk/sometoken", method: :put)
    end
  end
end
