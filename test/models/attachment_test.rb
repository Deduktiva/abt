require 'test_helper'

class AttachmentTest < ActiveSupport::TestCase
  test 'valid attachment with pdf content type saves' do
    attachment = Attachment.new(title: 'OK', filename: 'a.pdf',
                                 content_type: 'application/pdf', data: 'pdf')
    assert attachment.valid?
  end

  test 'rejects content type outside safelist' do
    attachment = Attachment.new(title: 'XSS', filename: 'a.html',
                                 content_type: 'text/html', data: '<script>')
    assert_not attachment.valid?
    assert_includes attachment.errors[:content_type].first, 'must be one of'
  end

  test 'rejects data larger than MAX_SIZE_BYTES' do
    attachment = Attachment.new(title: 'big', filename: 'a.pdf',
                                 content_type: 'application/pdf',
                                 data: 'x' * (Attachment::MAX_SIZE_BYTES + 1))
    assert_not attachment.valid?
    assert_includes attachment.errors[:data].first, 'too large'
  end

  test 'safe_content_type returns whitelisted content type for safe values' do
    attachment = Attachment.new(content_type: 'application/pdf')
    assert_equal 'application/pdf', attachment.safe_content_type
  end

  test 'safe_content_type returns octet-stream for unsafe values' do
    attachment = attachments(:invoice_pdf)
    attachment.update_column(:content_type, 'text/html')
    assert_equal 'application/octet-stream', attachment.reload.safe_content_type
  end
end
