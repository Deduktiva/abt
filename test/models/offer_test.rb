require "test_helper"

class OfferTest < ActiveSupport::TestCase
  test "project is required" do
    offer = Offer.new(customer: customers(:good_eu))
    assert_not offer.valid?
    assert offer.errors[:project].any?
  end

  test "validity_days falls back from customer to issuer" do
    offer = offers(:draft_offer)
    offer.customer.update!(offer_validity_days: nil)
    assert_equal IssuerCompany.get_the_issuer!.offer_validity_days, offer.validity_days
    offer.customer.update!(offer_validity_days: 14)
    assert_equal 14, offer.validity_days
  end

  test "send_problems requires a draft version with at least one milestone" do
    offer = offers(:draft_offer)
    offer.draft_version.milestones.destroy_all
    assert_includes offer.send_problems.join, "milestone"
  end

  test "accept from sent stores order data and discards the draft version" do
    offer = offers(:sent_offer)
    draft_id = offer.draft_version.id
    offer.accept!(order_number: "PO-100", ordered_on: Date.new(2026, 7, 1))
    assert offer.accepted?
    assert_equal "PO-100", offer.order_number
    assert_equal offer.versions.where.not(sent_at: nil).order(:version_number).last.id,
                 offer.accepted_version_id
    assert_nil OfferVersion.find_by(id: draft_id)
  end

  test "accept refused unless sent" do
    assert_raises(Offer::InvalidTransition) { offers(:draft_offer).accept!(order_number: "x", ordered_on: Date.current) }
  end

  test "accept requires an order date" do
    assert_raises(Offer::InvalidTransition) { offers(:sent_offer).accept!(order_number: "x", ordered_on: nil) }
    assert offers(:sent_offer).reload.sent?
  end

  test "reject stamps rejected_at" do
    offer = offers(:sent_offer)
    offer.reject!
    assert offer.rejected?
    assert_not_nil offer.rejected_at
  end

  test "reopen from rejected returns to sent" do
    offer = offers(:sent_offer)
    offer.reject!
    offer.reopen!
    assert offer.sent?
    assert_nil offer.rejected_at
  end

  test "reopen clears a stale reported_expired_at from a prior auto-expiry" do
    offer = offers(:sent_offer)
    # Mirror what ExpiringOffersReportJob does to an overdue sent offer.
    offer.update!(state: "expired", reported_expired_at: Time.current)
    offer.reject!
    offer.reopen!
    assert offer.sent?
    assert_nil offer.reported_expired_at
  end

  test "reopen from accepted branches a draft from the accepted version" do
    offer = offers(:sent_offer)
    offer.accept!(order_number: "PO-1", ordered_on: Date.current)
    accepted_subject = offer.reload.accepted_version.subject
    offer.reopen!
    assert offer.sent?
    assert_nil offer.accepted_version_id
    assert_equal accepted_subject, offer.draft_version.subject
  end

  test "customer with offers cannot be deleted" do
    customer = offers(:draft_offer).customer
    assert_not customer.destroy
    assert_includes customer.errors[:base].join, "offers"
  end

  test "deleting the addressed contact nullifies the reference" do
    offer = offers(:draft_offer)
    contact = CustomerContact.create!(
      customer: offer.customer,
      name: "Test Contact to Delete",
      email: "delete-me@example.com"
    )
    offer.update!(customer_contact: contact)
    contact.destroy
    assert_nil offer.reload.customer_contact_id
  end

  test "customer_contact must belong to the offer's customer" do
    offer = offers(:draft_offer)
    contact_from_different_customer = customer_contacts(:eu_contact) # belongs to good_eu, not offer_only_customer
    offer.customer_contact = contact_from_different_customer
    assert_not offer.valid?
    assert_includes offer.errors[:customer_contact], "must belong to the offer's customer"
  end

  test "customer_contact can be assigned if it belongs to the offer's customer" do
    offer = offers(:draft_offer)
    contact = CustomerContact.create!(
      customer: offer.customer,
      name: "Test Contact",
      email: "test@example.com"
    )
    offer.customer_contact = contact
    assert offer.valid?
    assert_empty offer.errors[:customer_contact]
  end

  test "new offer preselects the tax class when the customer has exactly one" do
    offer = create_draft_offer
    assert_equal sales_tax_product_classes(:standard), offer.draft_version.sales_tax_product_class
  end

  test "new offer preselects no tax class when the customer has several" do
    customer = customers(:good_eu)
    reduced = SalesTaxProductClass.create!(name: "Reduced Goods", indicator_code: "RED")
    SalesTaxRate.create!(sales_tax_customer_class: customer.sales_tax_customer_class,
                         sales_tax_product_class: reduced, rate: 10)
    offer = create_draft_offer(customer: customer)
    assert_nil offer.draft_version.sales_tax_product_class_id
  end
  test "rich text preludes lose leading and trailing blank lines on save" do
    version = offers(:draft_offer).draft_version
    version.update!(prelude: "<div><br></div><div><br>First line<br>Second<br><br></div><div><br></div>")
    assert_equal "<div>First line<br>Second</div>", version.reload.prelude.body.to_html
  end

  test "internal notes keep interior breaks while edges are stripped" do
    offer = offers(:draft_offer)
    offer.update!(internal_notes: "<div>keep<br><br>this</div><p><br></p>")
    assert_equal "<div>keep<br><br>this</div>", offer.reload.internal_notes.body.to_html
  end
end
