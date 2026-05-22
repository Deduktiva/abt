require 'test_helper'

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @attachment = attachments(:invoice_pdf)
  end

  test 'show serves a PDF inline with nosniff header' do
    get attachment_url(@attachment)
    assert_response :success
    assert_equal 'application/pdf', response.media_type
    assert_match(/inline/, response.headers['Content-Disposition'].to_s)
    assert_equal 'nosniff', response.headers['X-Content-Type-Options']
  end

  test 'show forces attachment disposition and octet-stream for non-safelisted content types' do
    @attachment.update_column(:content_type, 'text/html')
    get attachment_url(@attachment)
    assert_response :success
    assert_equal 'application/octet-stream', response.media_type
    assert_match(/attachment/, response.headers['Content-Disposition'].to_s)
    assert_equal 'nosniff', response.headers['X-Content-Type-Options']
  end

  test 'create rejects oversized uploads' do
    big = Rack::Test::UploadedFile.new(
      StringIO.new('x' * (Attachment::MAX_SIZE_BYTES + 1)),
      'application/pdf',
      original_filename: 'big.pdf'
    )
    assert_no_difference -> { Attachment.count } do
      post attachments_url, params: { attachment: { attachment: big, title: 'big' } }
    end
    assert_match(/too large/, flash[:error])
  end

  test 'create rejects disallowed content types' do
    bad = Rack::Test::UploadedFile.new(
      StringIO.new('<script>alert(1)</script>'),
      'text/html',
      original_filename: 'evil.html'
    )
    assert_no_difference -> { Attachment.count } do
      post attachments_url, params: { attachment: { attachment: bad, title: 'evil' } }
    end
    assert_match(/Content type/, flash[:error])
  end
end
