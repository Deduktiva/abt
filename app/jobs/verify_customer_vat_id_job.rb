class VerifyCustomerVatIdJob < ApplicationJob
  queue_as :default

  retry_on(*ViesVerifier::TRANSIENT_ERRORS, attempts: 5, wait: :polynomially_longer)

  def perform(customer, actor: nil)
    return if customer.nil? || !customer.active? || customer.vat_id.blank?

    ViesVerifier.new(customer, actor: actor).run!
  end
end
