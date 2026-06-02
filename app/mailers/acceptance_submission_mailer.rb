class AcceptanceSubmissionMailer < ApplicationMailer
  def submitted
    @delivery_note = params[:delivery_note]
    @url = AbsoluteUrl.delivery_note(@delivery_note)
    mail(to: @issuer.reporting_email,
         subject: I18n.t("mailers.acceptance_submission.subject",
                         document_number: sanitize_header_value(@delivery_note.document_number)))
  end
end
