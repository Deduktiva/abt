class UpcomingOfferDeliveriesReportJob < ApplicationJob
  queue_as :default

  DELIVERY_WINDOW = 5.days

  def perform
    offers = Offer.where(state: "accepted")
                  .joins(:accepted_version)
                  .where(offer_versions: { delivery_date: ..(Date.current + DELIVERY_WINDOW) })
                  .includes(:customer, accepted_version: { milestones: :invoice })
                  .order("offer_versions.delivery_date")

    entries = offers.filter_map do |offer|
      missing = missing_statuses(offer)
      { offer: offer, missing: missing } if missing.any?
    end
    return if entries.empty?

    UpcomingOfferDeliveriesMailer.with(entries: entries).upcoming_report.deliver_now
  end

  private

  # What still stands between this offer's milestones and fully booked, sent
  # invoices — empty when invoicing is complete and the offer needs no nagging.
  def missing_statuses(offer)
    milestones = offer.accepted_version.milestones
    unconverted = milestones.count { |m| m.invoice.nil? }
    unbooked = milestones.count { |m| m.invoice && !m.invoice.published? }
    unsent = milestones.count { |m| m.invoice&.published? && m.invoice.email_sent_at.nil? }

    { unconverted: unconverted, unbooked: unbooked, unsent: unsent }
      .filter_map do |key, count|
        I18n.t("mailers.upcoming_offer_deliveries.status.#{key}", count: count) if count > 0
      end
  end
end
