# Shared guard for user-supplied PDF uploads. The check order is load-bearing:
# a non-upload param 500s on #tempfile and an oversized file raises
# RecordInvalid from Attachment#save! unless caught here first.
module PdfUploadChecks
  # Returns :missing, :too_large, :not_pdf, or nil when the file is an
  # acceptable PDF upload. Callers map the symbol to their own wording.
  def pdf_upload_error(file)
    return :missing if file.blank? || !file.is_a?(ActionDispatch::Http::UploadedFile)
    return :too_large if file.size > Attachment::MAX_SIZE_BYTES
    return :not_pdf if Attachment.detect_content_type(file.tempfile) != "application/pdf"
    nil
  end
end
