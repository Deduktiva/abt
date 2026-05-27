class ViesVerifier
  # Swappable for tests. Production default uses valvat (SOAP).
  # The lambda is called with the normalised VAT id and a `requester:` kwarg
  # and must return a Hash with any of the following keys:
  #   valid_response:     true|false|nil  (nil = transient/unavailable)
  #   request_identifier: String
  #   request_date:       Date
  #   trader_name:        String
  #   trader_address:     String
  #   country_iso2:       String  (defaults to the first two chars of the VAT id)
  #   error_code:         String
  #   raw:                Object (will be JSON-encoded into raw_response)
  cattr_accessor :lookup_strategy, default: ->(vat_id, requester:) {
    response = Valvat.new(vat_id).exists?(detail: true, requester: requester, raise_error: true)
    if response == false
      { valid_response: false, error_code: "INVALID", raw: { valid: false } }
    else
      {
        valid_response: true,
        request_identifier: response[:request_identifier],
        request_date: response[:request_date],
        trader_name: response[:name],
        trader_address: response[:address],
        country_iso2: response[:country_code],
        raw: response
      }
    end
  }

  # valvat raises subclasses of LookupError for transient failures. We
  # treat the maintenance/timeout/HTTP/rate-limit families as retryable.
  TRANSIENT_ERRORS = [
    Valvat::HTTPError,
    Valvat::MaintenanceError,
    Valvat::Timeout,
    Valvat::RateLimitError
  ].freeze

  def initialize(customer, actor: nil)
    @customer = customer
    @actor = actor
  end

  # Always creates a CustomerVatVerification row.
  # Updates customer.vat_id_verified_at only on valid_response == true.
  # Returns the created record.
  # On transient errors, records a row with valid_response: nil + error_code
  # from the exception, and re-raises so callers (jobs) can retry.
  def run!
    requester = IssuerCompany.get_the_issuer!.vat_id
    result = self.class.lookup_strategy.call(normalised_vat_id, requester: requester)
    record_verification(result)
  rescue *TRANSIENT_ERRORS => e
    record_verification(valid_response: nil, error_code: e.class.name)
    raise
  end

  private

  def normalised_vat_id
    @customer.vat_id.to_s.upcase.gsub(/[\s.\-]/, "")
  end

  def record_verification(result)
    verification = @customer.vat_verifications.create!(
      vat_id: normalised_vat_id,
      country_iso2: result[:country_iso2] || normalised_vat_id[0, 2],
      valid_response: result[:valid_response],
      request_identifier: result[:request_identifier],
      request_date: result[:request_date],
      trader_name: result[:trader_name],
      trader_address: result[:trader_address],
      raw_response: (result[:raw] || result.except(:raw)).to_json,
      error_code: result[:error_code],
      performed_by_user: @actor
    )
    if result[:valid_response] == true
      @customer.update_column(:vat_id_verified_at, verification.created_at)
    end
    verification
  end
end
