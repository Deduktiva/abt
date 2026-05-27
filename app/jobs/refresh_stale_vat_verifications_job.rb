class RefreshStaleVatVerificationsJob < ApplicationJob
  queue_as :default

  # Spread per-customer lookups across a window proportional to the cohort
  # size to avoid hammering the VIES service with simultaneous SOAP calls,
  # capped so the spread never exceeds the daily scheduler cadence.
  SPREAD_SECONDS_PER_CUSTOMER = 30
  MAX_SPREAD_SECONDS = 6 * 60 * 60

  def perform
    recheck_threshold = IssuerCompany.get_the_issuer!.vat_id_recheck_days.days.ago
    transient_threshold = 24.hours.ago

    eligible = Customer.vat_verification_required
      .where(<<~SQL.squish, recheck_threshold: recheck_threshold)
        NOT EXISTS (
          SELECT 1 FROM customer_vat_verifications v
          WHERE v.customer_id = customers.id
            AND v.valid_response IS NOT NULL
            AND v.created_at >= :recheck_threshold
        )
      SQL
      .where(<<~SQL.squish, transient_threshold: transient_threshold)
        NOT EXISTS (
          SELECT 1 FROM customer_vat_verifications v
          WHERE v.customer_id = customers.id
            AND v.valid_response IS NULL
            AND v.created_at >= :transient_threshold
        )
      SQL

    count = eligible.count
    window = [ count * SPREAD_SECONDS_PER_CUSTOMER, MAX_SPREAD_SECONDS ].min

    eligible.find_each do |customer|
      VerifyCustomerVatIdJob.set(wait: rand(0..window).seconds).perform_later(customer)
    end
  end
end
