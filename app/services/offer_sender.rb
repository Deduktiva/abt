class OfferSender
  attr_reader :log

  def initialize(offer, issuer)
    @offer = offer
    @issuer = issuer
    @log = ""
  end

  def send!
    @offer.with_lock { send_locked! }
  end

  private

  def send_locked!
    problems = @offer.send_problems
    if problems.any?
      problems.each { |p| @log += "E: #{p}\n" }
      return false
    end

    version = @offer.draft_version
    today = Date.current
    customer = @offer.customer

    @offer.document_number ||= DocumentNumber.get_next_for("offer", today)

    version.assign_attributes(
      date: today,
      sent_at: Time.current,
      customer_name: customer.name,
      customer_address: customer.address,
      customer_country_iso2: customer.country_iso2,
      customer_supplier_number: customer.supplier_number,
      payment_terms_days: customer.payment_terms_days
    )
    version.boilerplate = customer.offer_boilerplate.body if customer.offer_boilerplate.present?
    version.save!

    # expires_at must land on @offer before rendering: OfferRenderer reads
    # frozen-version valid-until from @offer.expires_at once the version is
    # frozen (sent_at present), which it already is by this point. Rendering
    # first would hand the XSL a nil expires_at and crash. If rendering below
    # raises, the whole with_lock transaction (including this assignment)
    # rolls back, so an offer never surfaces as "sent" without a PDF.
    @offer.assign_attributes(
      state: "sent",
      date: today,
      sent_at: Time.current,
      expires_at: today + @offer.validity_days,
      reported_expired_at: nil
    )
    @offer.save!

    pdf = OfferRenderer.new(version, @issuer).render
    version.attachment ||= Attachment.new
    version.attachment.set_data(pdf, "application/pdf")
    version.attachment.filename = "#{@issuer.short_name}-Offer-#{@offer.document_number}-v#{version.version_number}.pdf"
    version.attachment.title = "#{@issuer.short_name} Offer #{@offer.document_number} (version #{version.version_number})"
    version.attachment.save!
    version.save!

    version.branch_draft!
    @log += "I: sent version #{version.version_number} as #{@offer.document_number}\n"
    true
  end
end
