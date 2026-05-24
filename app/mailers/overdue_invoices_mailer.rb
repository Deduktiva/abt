class OverdueInvoicesMailer < ApplicationMailer
  def overdue_report
    @invoices = params[:invoices]
    @today = Date.current

    recipient = @issuer.document_email_auto_bcc.presence
    return if recipient.blank?

    I18n.with_locale(I18n.default_locale) do
      mail(
        to: recipient,
        from: "\"#{@issuer.short_name}\" <#{@issuer.document_email_from}>",
        subject: I18n.t("mailers.overdue_invoices.subject",
                        issuer_name: @issuer.short_name,
                        count: @invoices.size)
      )
    end
  end
end
