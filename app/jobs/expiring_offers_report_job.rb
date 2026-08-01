class ExpiringOffersReportJob < ApplicationJob
  queue_as :default

  def perform
    expiring = Offer.where(state: "sent", reported_expired_at: nil)
                    .where(expires_at: ...Date.current)
                    .includes(:customer)
                    .order(:expires_at)
                    .to_a

    return if expiring.empty?

    # Deliver before marking so a delivery failure raises and leaves the
    # offers unmarked — the next run picks them up again. Same rationale as
    # VatVerificationsReportJob.
    ExpiringOffersMailer.with(offers: expiring).expiring_report.deliver_now
    Offer.where(id: expiring.map(&:id), state: "sent").update_all(state: "expired", reported_expired_at: Time.current)
  end
end
