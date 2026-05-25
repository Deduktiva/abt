class AttachmentsController < ApplicationController
  INLINE_CONTENT_TYPES = %w[application/pdf].freeze

  def show
    @attachment = Attachment.find(params[:id])
    authorize_attachment!(@attachment)

    served_type = @attachment.safe_content_type
    disposition = INLINE_CONTENT_TYPES.include?(served_type) ? "inline" : "attachment"
    response.set_header("X-Content-Type-Options", "nosniff")
    send_data @attachment.data,
              filename: @attachment.filename,
              type: served_type,
              disposition: disposition
  end

  private

  # An Attachment row is reachable only through a parent record (an Invoice
  # PDF or a DeliveryNote acceptance document). Mirror the parent's team
  # visibility so an attacker can't enumerate attachment ids across teams.
  def authorize_attachment!(attachment)
    if Invoice.visible_to(current_user).where(attachment_id: attachment.id).exists?
      return require_permission!("invoices.view")
    end
    if DeliveryNote.visible_to(current_user).where(acceptance_attachment_id: attachment.id).exists?
      return require_permission!("delivery_notes.view")
    end
    raise ApplicationController::PermissionDenied, "attachment##{attachment.id}"
  end
end
