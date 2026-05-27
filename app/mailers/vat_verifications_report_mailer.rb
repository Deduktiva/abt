class VatVerificationsReportMailer < ApplicationMailer
  def daily_report
    @newly_invalid = params[:newly_invalid] || []
    @stuck_unavailable = params[:stuck_unavailable] || []
    @today = Date.current

    recipient = @issuer.reporting_email.presence
    return if recipient.blank?
    return if @newly_invalid.empty? && @stuck_unavailable.empty?

    @prior_states = compute_prior_states(@newly_invalid)

    I18n.with_locale(I18n.default_locale) do
      mail(
        to: recipient,
        subject: I18n.t("mailers.vat_verifications_report.subject",
                        issuer_name: sanitize_header_value(@issuer.short_name),
                        count: @newly_invalid.size + @stuck_unavailable.size)
      )
    end
  end

  private

  # For each newly-invalid verification, find the immediately-prior verification
  # for the same customer to label the row as either "was valid until <date>"
  # or "first confirmed invalid result". Returns a Hash keyed by verification id.
  def compute_prior_states(verifications)
    verifications.each_with_object({}) do |v, h|
      prior = CustomerVatVerification
                .where(customer_id: v.customer_id)
                .where("created_at < ?", v.created_at)
                .order(created_at: :desc)
                .first
      h[v.id] = if prior&.valid_response == true
        { kind: :was_valid, date: prior.created_at.to_date }
      else
        { kind: :first_ever }
      end
    end
  end
end
