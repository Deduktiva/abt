class OverdueInvoicesMailer < ApplicationMailer
  def overdue_report
    @invoices = params[:invoices]
    @today = Date.current

    recipient = @issuer.reporting_email.presence
    return if recipient.blank?

    I18n.with_locale(I18n.default_locale) do
      mail(
        to: recipient,
        subject: I18n.t("mailers.overdue_invoices.subject",
                        issuer_name: sanitize_header_value(@issuer.short_name),
                        count: @invoices.size)
      )
    end
  end
end
