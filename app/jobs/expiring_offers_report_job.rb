class ExpiringOffersReportJob < ApplicationJob
  queue_as :default

  def perform
    expiring = Offer.where(state: "sent", reported_expired_at: nil)
                    .where(expires_at: ...Date.current)
                    .includes(:customer)
                    .order(:expires_at)
                    .to_a

    return if expiring.empty?

    Offer.where(id: expiring.map(&:id), state: "sent").update_all(state: "expired", reported_expired_at: Time.current)
    ExpiringOffersMailer.with(offers: expiring).expiring_report.deliver_now
  end
end
