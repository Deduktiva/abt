# Shared guard for user-supplied file uploads. The check order is load-bearing:
# a non-upload param 500s on #tempfile and an oversized file raises
# RecordInvalid from Attachment#save! unless caught here first.
module UploadChecks
  # Returns :missing, :too_large, :wrong_type, or nil when the file is an
  # acceptable upload of expected_type. Callers map the symbol to their own wording.
  def upload_error(file, expected_type:, max_bytes: Attachment::MAX_SIZE_BYTES)
    return :missing if file.blank? || !file.is_a?(ActionDispatch::Http::UploadedFile)
    return :too_large if file.size > max_bytes
    return :wrong_type if Attachment.detect_content_type(file.tempfile) != expected_type
    nil
  end

  def pdf_upload_error(file) = upload_error(file, expected_type: "application/pdf")
end
