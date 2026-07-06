class UpcomingOfferDeliveriesMailer < ApplicationMailer
  def upcoming_report
    @entries = params[:entries]
    @today = Date.current

    I18n.with_locale(I18n.default_locale) do
      mail(
        to: @issuer.reporting_email,
        subject: I18n.t("mailers.upcoming_offer_deliveries.subject",
                        issuer_name: sanitize_header_value(@issuer.short_name),
                        count: @entries.size)
      )
    end
  end
end
