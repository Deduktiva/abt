require "test_helper"

class OfferMilestoneConverterTest < ActiveSupport::TestCase
  setup do
    @offer = offers(:sent_offer)
    @offer.accept!(order_number: "PO-77", ordered_on: Date.new(2026, 6, 15))
  end

  test "converts a milestone into a draft invoice and delivery note" do
    milestone = offer_milestones(:sent_ms_two) # on_acceptance, no skip
    invoice = OfferMilestoneConverter.new(milestone).convert!
    assert_not invoice.published
    assert_equal @offer.customer, invoice.customer
    assert_equal @offer.project, invoice.project
    assert_equal "PO-77", invoice.cust_order
    line = invoice.invoice_lines.first
    assert_equal "item", line.type
    assert_equal @offer.accepted_version.subject, line.title
    assert_equal "#{milestone.title}\nOffer #{@offer.document_number} v#{@offer.accepted_version.version_number}",
                 line.description
    assert_equal 1, line.quantity
    assert_equal milestone.amount, line.rate
    assert_equal @offer.accepted_version.sales_tax_product_class_id, line.sales_tax_product_class_id
    assert_nil invoice.prelude.body
    milestone.reload
    assert_equal invoice.id, milestone.invoice_id
    dn = milestone.delivery_note
    assert dn.present?
    assert_equal invoice, dn.invoice
    line = dn.delivery_note_lines.first
    assert_equal @offer.accepted_version.subject, line.title
    assert_equal "#{milestone.title}\nOffer #{@offer.document_number} v#{@offer.accepted_version.version_number}",
                 line.description
    assert_nil dn.prelude.body
    assert_equal @offer.ordered_on, dn.delivery_start_date
  end

  test "delivery note range runs from order date to the version delivery date" do
    @offer.accepted_version.update!(delivery_date: Date.new(2026, 9, 30))
    dn = OfferMilestoneConverter.new(offer_milestones(:sent_ms_two)).convert!
                                .then { offer_milestones(:sent_ms_two).reload.delivery_note }
    assert_equal @offer.ordered_on, dn.delivery_start_date
    assert_equal Date.new(2026, 9, 30), dn.delivery_end_date
  end

  test "delivery date before the order date leaves the range open-ended" do
    @offer.accepted_version.update!(delivery_date: @offer.ordered_on - 1.day)
    OfferMilestoneConverter.new(offer_milestones(:sent_ms_two)).convert!
    assert_nil offer_milestones(:sent_ms_two).reload.delivery_note.delivery_end_date
  end

  test "skip_delivery_note produces only an invoice" do
    milestone = offer_milestones(:sent_ms_one) # on_order, skip
    OfferMilestoneConverter.new(milestone).convert!
    assert_nil milestone.reload.delivery_note_id
  end

  test "conversion requires an accepted offer" do
    other = offers(:draft_offer)
    milestone = other.draft_version.milestones.first
    assert_raises(OfferMilestoneConverter::NotConvertible) { OfferMilestoneConverter.new(milestone).convert! }
  end

  test "a converted milestone cannot convert twice, and reopen_link! clears it" do
    milestone = offer_milestones(:sent_ms_two)
    OfferMilestoneConverter.new(milestone).convert!
    assert_raises(OfferMilestoneConverter::NotConvertible) { OfferMilestoneConverter.new(milestone.reload).convert! }
    milestone.reopen_link!
    assert_nil milestone.reload.invoice_id
    assert_nil milestone.delivery_note_id
  end

  test "milestone description lands after the reference in the line description" do
    milestone = offer_milestones(:sent_ms_two)
    milestone.update!(description: "Detailed scope")
    invoice = OfferMilestoneConverter.new(milestone).convert!
    expected = "#{milestone.title}\nOffer #{@offer.document_number} v#{@offer.accepted_version.version_number}\nDetailed scope"
    assert_equal expected, invoice.invoice_lines.first.description
    assert_equal expected, milestone.reload.delivery_note.delivery_note_lines.first.description
  end

  test "version prelude becomes the invoice prelude" do
    @offer.accepted_version.update!(prelude: "<p>Original offer prelude</p>")
    invoice = OfferMilestoneConverter.new(offer_milestones(:sent_ms_two)).convert!
    assert_includes invoice.prelude.body.to_html, "Original offer prelude"
  end

  test "conversion refused for a milestone on a non-accepted version" do
    # Create a new non-accepted version on the already-accepted offer
    non_accepted_version = @offer.versions.create!(
      version_number: 99,
      sent_at: Time.current,
      date: Date.current,
      customer_name: "Test Customer",
      customer_address: "Test Address",
      customer_country_iso2: "DE",
      payment_terms_days: 30
    )
    milestone = non_accepted_version.milestones.create!(
      position: 1,
      title: "Non-Accepted Milestone",
      amount: 1000,
      trigger: "on_acceptance"
    )

    assert_raises(OfferMilestoneConverter::NotConvertible) do
      OfferMilestoneConverter.new(milestone).convert!
    end
    assert_nil milestone.reload.invoice_id
  end
  test "internal reference carries over with the milestone ordinal when several milestones exist" do
    @offer.update!(internal_reference: "PROJ-REF")
    first = offer_milestones(:sent_ms_one)
    second = offer_milestones(:sent_ms_two)
    invoice_one = OfferMilestoneConverter.new(first).convert!
    invoice_two = OfferMilestoneConverter.new(second).convert!
    assert_equal "PROJ-REF 1", invoice_one.internal_reference
    assert_equal "PROJ-REF 2", invoice_two.internal_reference
    assert_equal "PROJ-REF 2", second.reload.delivery_note.internal_reference
  end

  test "internal reference carries over without ordinal for a sole milestone" do
    @offer.update!(internal_reference: "PROJ-REF")
    version = @offer.accepted_version
    version.milestones.where.not(id: offer_milestones(:sent_ms_two).id).destroy_all
    invoice = OfferMilestoneConverter.new(offer_milestones(:sent_ms_two)).convert!
    assert_equal "PROJ-REF", invoice.internal_reference
  end

  test "blank internal reference converts with just the ordinal" do
    invoice = OfferMilestoneConverter.new(offer_milestones(:sent_ms_two)).convert!
    assert_equal "2", invoice.internal_reference
  end
  test "converted documents cannot be deleted while the milestone link is set" do
    milestone = offer_milestones(:sent_ms_two)
    invoice = OfferMilestoneConverter.new(milestone).convert!
    dn = milestone.reload.delivery_note
    assert_not invoice.destroy
    assert_includes invoice.errors[:base].join, @offer.display_name
    assert_not dn.destroy
    milestone.reopen_link!
    assert dn.reload.destroy
    assert invoice.reload.destroy
  end
end
