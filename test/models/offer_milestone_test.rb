require "test_helper"

class OfferMilestoneTest < ActiveSupport::TestCase
  def setup
    @offer = Offer.create!(
      matchcode: "ms-test",
      customer: customers(:good_eu),
      project: projects(:one),
      state: "draft"
    )
    @version = @offer.offer_versions.create!
  end

  test "requires title and net_amount" do
    ms = @version.offer_milestones.build(trigger: "on_order")
    assert_not ms.valid?
    assert_includes ms.errors[:title], "can't be blank"
    assert_includes ms.errors[:net_amount], "can't be blank"
  end

  test "trigger_date required when trigger is on_date" do
    ms = @version.offer_milestones.build(title: "M", net_amount: 100, trigger: "on_date")
    assert_not ms.valid?
    assert_includes ms.errors[:trigger_date], "can't be blank"

    ms.trigger_date = Date.current
    assert ms.valid?, ms.errors.full_messages.inspect
  end

  test "default_skip_delivery_note pre-checks on_order milestones only" do
    on_order = @version.offer_milestones.create!(title: "Order", trigger: "on_order", net_amount: 1)
    on_accept = @version.offer_milestones.create!(title: "Accept", trigger: "on_acceptance", net_amount: 1)
    on_date = @version.offer_milestones.create!(title: "Date", trigger: "on_date", trigger_date: Date.current, net_amount: 1)

    assert on_order.skip_delivery_note
    assert_not on_accept.skip_delivery_note
    assert_not on_date.skip_delivery_note
  end

  test "default_skip_delivery_note does not override an explicit value" do
    ms = @version.offer_milestones.create!(
      title: "Explicit", trigger: "on_order", net_amount: 1, skip_delivery_note: false
    )
    assert_not ms.skip_delivery_note
  end

  test "converted? reflects link to invoice or delivery_note" do
    ms = @version.offer_milestones.create!(title: "M", trigger: "on_acceptance", net_amount: 1)
    assert_not ms.converted?

    ms.update!(invoice: invoices(:published_invoice))
    assert ms.converted?
  end

  test "convert! refuses if the offer is not accepted" do
    ms = @version.offer_milestones.create!(title: "M", trigger: "on_order", net_amount: 100)
    assert_raises(RuntimeError) { ms.convert! }
  end

  test "convert! with skip_delivery_note=true creates an invoice only" do
    ms = @version.offer_milestones.create!(title: "Phase 1", trigger: "on_order", net_amount: 100)
    @offer.send_current_version!
    @offer.reload
    @offer.accept!
    @offer.reload

    # After accept, draft is discarded; the milestone we want to convert lives
    # on the now-accepted version.
    accepted_ms = @offer.accepted_version.offer_milestones.find(ms.id)

    assert_difference -> { Invoice.count } => 1, -> { DeliveryNote.count } => 0 do
      invoice = accepted_ms.convert!(skip_delivery_note: true)
      assert_equal "Phase 1", invoice.invoice_lines.first.title
      assert_equal 100.0, invoice.invoice_lines.first.rate
    end
    assert accepted_ms.reload.converted?
    assert_nil accepted_ms.delivery_note_id
  end

  test "convert! with skip_delivery_note=false creates DN + invoice + links both" do
    ms = @version.offer_milestones.create!(title: "Phase 2", trigger: "on_acceptance", net_amount: 200)
    @offer.send_current_version!
    @offer.reload
    @offer.accept!
    @offer.reload

    accepted_ms = @offer.accepted_version.offer_milestones.find(ms.id)

    assert_difference -> { Invoice.count } => 1, -> { DeliveryNote.count } => 1 do
      accepted_ms.convert!(skip_delivery_note: false)
    end
    accepted_ms.reload
    assert_not_nil accepted_ms.invoice_id
    assert_not_nil accepted_ms.delivery_note_id
  end

  test "convert! refuses double-convert" do
    ms = @version.offer_milestones.create!(title: "M", trigger: "on_order", net_amount: 100)
    @offer.send_current_version!
    @offer.reload
    @offer.accept!
    @offer.reload

    accepted_ms = @offer.accepted_version.offer_milestones.find(ms.id)
    accepted_ms.convert!(skip_delivery_note: true)

    assert_raises(RuntimeError) { accepted_ms.convert!(skip_delivery_note: true) }
  end

  test "two milestones cannot link to the same invoice" do
    invoice = invoices(:published_invoice)
    @version.offer_milestones.create!(title: "A", trigger: "on_order", net_amount: 1, invoice: invoice)

    other_offer = Offer.create!(matchcode: "ms-other", customer: customers(:good_eu), project: projects(:one), state: "draft")
    other_version = other_offer.offer_versions.create!
    duplicate = other_version.offer_milestones.build(title: "B", trigger: "on_order", net_amount: 1, invoice: invoice)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:invoice_id], "is already linked to another milestone"
  end
end
