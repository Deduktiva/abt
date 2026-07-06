require "test_helper"

class OfferSenderTest < ActiveSupport::TestCase
  setup do
    @issuer = IssuerCompany.get_the_issuer!
  end

  # Renderer stubbed per test via stub_offer_renderer, mirroring the plain
  # singleton-method technique InvoicePublisher's test uses in
  # with_failing_renderer (Minitest::Mock's `expect`/`stub` API isn't
  # available in this app's pinned minitest, which no longer ships
  # minitest/mock).

  test "first send assigns a document number, freezes the version, and branches a new draft" do
    offer = create_offer_with_milestone
    sender = OfferSender.new(offer, @issuer)
    stub_offer_renderer(render_stub("%PDF-fake")) do
      assert sender.send!, sender.log
    end
    offer.reload
    assert offer.sent?
    assert_equal "#{Date.current.strftime("%Y%m%d")}-01", offer.document_number
    frozen = offer.versions.find_by(version_number: 1)
    assert frozen.frozen?
    assert_equal Date.current, frozen.date
    assert_equal offer.customer.name, frozen.customer_name
    assert_equal offer.customer.payment_terms_days, frozen.payment_terms_days
    assert frozen.attachment&.data&.start_with?("%PDF")
    draft = offer.draft_version
    assert_equal 2, draft.version_number
    assert_equal frozen.milestones.count, draft.milestones.count
    assert_equal Date.current + offer.validity_days, offer.expires_at
  end

  test "second send keeps the document number and supersedes the prior version" do
    offer = create_offer_with_milestone
    numbers = []
    2.times do
      stub_offer_renderer(render_stub("%PDF-fake")) { assert OfferSender.new(offer.reload, @issuer).send! }
      numbers << offer.reload.document_number
    end
    assert_equal numbers.first, numbers.last
    assert_equal 2, offer.versions.where.not(sent_at: nil).count
    assert_equal 3, offer.versions.maximum(:version_number)
  end

  test "send from expired re-enters sent with a fresh validity window" do
    offer = create_offer_with_milestone
    stub_offer_renderer(render_stub("%PDF-fake")) { assert OfferSender.new(offer, @issuer).send! }
    offer.reload.update!(state: "expired", expires_at: 1.week.ago.to_date, reported_expired_at: Time.current)
    stub_offer_renderer(render_stub("%PDF-fake")) { assert OfferSender.new(offer.reload, @issuer).send! }
    offer.reload
    assert offer.sent?
    assert_operator offer.expires_at, :>, Date.current
    assert_nil offer.reported_expired_at
  end

  test "send refused without milestones" do
    offer = create_draft_offer
    sender = OfferSender.new(offer, @issuer)
    assert_not sender.send!
    assert offer.reload.draft?
  end

  test "boilerplate is frozen onto the version at send" do
    offer = create_offer_with_milestone
    offer.customer.update!(offer_boilerplate: "<p>Standing terms</p>")
    stub_offer_renderer(render_stub("%PDF-fake")) { assert OfferSender.new(offer, @issuer).send! }
    frozen = offer.reload.versions.find_by(version_number: 1)
    assert_includes frozen.boilerplate.body.to_html, "Standing terms"
    offer.customer.update!(offer_boilerplate: "<p>Changed later</p>")
    assert_includes frozen.reload.boilerplate.body.to_html, "Standing terms"
  end

  test "nothing persists when PDF rendering fails" do
    offer = create_offer_with_milestone
    sequence_before = DocumentNumber.find_by!(code: "offer").sequence
    failing = Object.new
    def failing.render = raise("FOP exploded")
    stub_offer_renderer(failing) do
      assert_raises(RuntimeError) { OfferSender.new(offer, @issuer).send! }
    end
    offer.reload
    assert offer.draft?
    assert_nil offer.document_number
    assert_nil offer.versions.find_by(version_number: 1).sent_at
    assert_equal sequence_before, DocumentNumber.find_by!(code: "offer").sequence
  end

  private

  def render_stub(pdf_data)
    Object.new.tap { |stub| stub.define_singleton_method(:render) { pdf_data } }
  end

  def stub_offer_renderer(fake)
    OfferRenderer.define_singleton_method(:new) { |*| fake }
    yield
  ensure
    OfferRenderer.singleton_class.send(:remove_method, :new)
  end
end
