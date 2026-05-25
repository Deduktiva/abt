class ExpiringOffersReportJob < ApplicationJob
  queue_as :default

  # Finds offers whose validity window has elapsed and which haven't yet
  # been reported. Marks each one expired + reported_expired_at, then sends
  # one digest email to the issuer's auto-bcc. Same pattern as
  # OverdueInvoicesReportJob.
  def perform
    expiring = Offer.where(state: "sent")
                    .where("expires_at < ?", Time.current)
                    .where(reported_expired_at: nil)
                    .includes(:customer)
                    .order(:expires_at)

    return if expiring.empty?

    now = Time.current
    offers = expiring.to_a
    Offer.where(id: offers.map(&:id))
         .update_all(state: "expired", reported_expired_at: now, updated_at: now)

    ExpiringOffersMailer.with(offers: offers).expiring_report.deliver_now
  end
end
