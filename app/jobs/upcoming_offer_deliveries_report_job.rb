class UpcomingOfferDeliveriesReportJob < ApplicationJob
  queue_as :default

  FAR_FUTURE = Date.new(9999, 1, 1)

  def perform
    offers = Offer.where(state: "accepted")
                  .includes(:customer, accepted_version: { milestones: :invoice })
                  .to_a
                  .select { |offer| report?(offer) }
                  .sort_by { |offer| offer.accepted_version.delivery_date || FAR_FUTURE }

    entries = offers.filter_map do |offer|
      missing = missing_statuses(offer)
      { offer: offer, missing: missing } if missing.any?
    end
    return if entries.empty?

    UpcomingOfferDeliveriesMailer.with(entries: entries).upcoming_report.deliver_now
  end

  private

  # An accepted offer needs attention when its delivery date is near or past, or
  # when an on-order milestone (billable the moment the order lands) still has no
  # booked invoice — the latter regardless of how far off delivery is.
  def report?(offer)
    delivery_soon?(offer) || on_order_awaiting_invoice?(offer)
  end

  def delivery_soon?(offer)
    date = offer.accepted_version.delivery_date
    date.present? && date <= Date.current + Offer::DELIVERY_SOON_WINDOW
  end

  def on_order_awaiting_invoice?(offer)
    offer.accepted_version.milestones.any? do |milestone|
      milestone.trigger == "on_order" && !milestone.invoice&.published?
    end
  end

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
