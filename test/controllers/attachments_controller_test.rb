require "test_helper"

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @attachment = attachments(:invoice_pdf)
  end

  test "show serves a PDF inline with nosniff header" do
    get attachment_url(@attachment)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/inline/, response.headers["Content-Disposition"].to_s)
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
  end

  test "show forces attachment disposition and octet-stream for non-safelisted content types" do
    @attachment.update_column(:content_type, "text/html")
    get attachment_url(@attachment)
    assert_response :success
    assert_equal "application/octet-stream", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"].to_s)
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
  end
end
