class AttachmentsController < ApplicationController
  INLINE_CONTENT_TYPES = %w[application/pdf].freeze

  def show
    @attachment = Attachment.find(params[:id])
    served_type = @attachment.safe_content_type
    disposition = INLINE_CONTENT_TYPES.include?(served_type) ? "inline" : "attachment"
    response.set_header("X-Content-Type-Options", "nosniff")
    send_data @attachment.data,
              filename: @attachment.filename,
              type: served_type,
              disposition: disposition
  end
end
