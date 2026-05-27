class RefreshStaleVatVerificationsJob < ApplicationJob
  queue_as :default

  # Spread per-customer lookups across a window proportional to the cohort
  # size to avoid hammering the VIES service with simultaneous SOAP calls.
  SPREAD_SECONDS_PER_CUSTOMER = 30

  def perform
    recheck_days = IssuerCompany.get_the_issuer!.vat_id_recheck_days
    eligible = Customer.vat_verification_required.select { |c| eligible?(c, recheck_days) }
    window = eligible.size * SPREAD_SECONDS_PER_CUSTOMER

    eligible.each do |customer|
      VerifyCustomerVatIdJob.set(wait: rand(0..window).seconds).perform_later(customer)
    end
  end

  private

  def eligible?(customer, recheck_days)
    latest = customer.vat_verifications.latest_first.first
    return true if latest.nil?

    case latest.valid_response
    when true, false then latest.created_at < recheck_days.days.ago
    when nil then latest.created_at < 24.hours.ago
    end
  end
end
