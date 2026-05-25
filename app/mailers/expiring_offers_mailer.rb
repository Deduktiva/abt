class ExpiringOffersMailer < ApplicationMailer
  def expiring_report
    @offers = params[:offers]
    @today = Date.current

    recipient = @issuer.document_email_auto_bcc.presence
    return if recipient.blank?

    I18n.with_locale(I18n.default_locale) do
      mail(
        to: recipient,
        subject: I18n.t("mailers.expiring_offers.subject",
                        issuer_name: sanitize_header_value(@issuer.short_name),
                        count: @offers.size)
      )
    end
  end
end
