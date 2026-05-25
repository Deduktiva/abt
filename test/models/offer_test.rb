require "test_helper"

class OfferTest < ActiveSupport::TestCase
  def build_offer(**overrides)
    Offer.new({
      matchcode: "test-offer",
      customer: customers(:good_eu),
      project: projects(:one),
      state: "draft"
    }.merge(overrides))
  end

  def create_offer(**overrides)
    build_offer(**overrides).tap(&:save!)
  end

  test "valid with matchcode + customer" do
    offer = build_offer
    assert offer.valid?, offer.errors.full_messages.inspect
  end

  test "requires matchcode" do
    offer = build_offer(matchcode: nil)
    assert_not offer.valid?
    assert_includes offer.errors[:matchcode], "can't be blank"
  end

  test "matchcode unique per customer (case-insensitive)" do
    create_offer(matchcode: "phase-one")
    duplicate = build_offer(matchcode: "PHASE-ONE")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:matchcode], "has already been taken"
  end

  test "matchcode may collide across different customers" do
    create_offer(matchcode: "shared", customer: customers(:good_eu))
    other = build_offer(matchcode: "shared", customer: customers(:good_national))
    assert other.valid?, other.errors.full_messages.inspect
  end

  test "addressed_to_contact must belong to this offer's customer" do
    foreign_contact = customer_contacts(:good_national_main)
    offer = build_offer(customer: customers(:good_eu), addressed_to_contact: foreign_contact)
    assert_not offer.valid?
    assert_includes offer.errors[:addressed_to_contact_id], "must belong to this offer's customer"
  end

  test "addressed_to_contact may be a contact of this customer" do
    offer = build_offer(
      customer: customers(:good_eu),
      addressed_to_contact: customer_contacts(:good_eu_accounting)
    )
    assert offer.valid?, offer.errors.full_messages.inspect
  end

  test "validity_days uses customer override when present" do
    customers(:good_eu).update!(offer_validity_days: 14)
    offer = create_offer
    assert_equal 14, offer.validity_days
  end

  test "validity_days falls back to issuer default when customer override is blank" do
    customers(:good_eu).update!(offer_validity_days: nil)
    issuer = IssuerCompany.get_the_issuer!
    issuer.update!(offer_validity_days: 45)
    offer = create_offer
    assert_equal 45, offer.validity_days
  end

  test "current_version returns the highest-numbered version" do
    offer = create_offer
    v1 = offer.offer_versions.create!(version_number: 1)
    v2 = offer.offer_versions.create!(version_number: 2)
    assert_equal v2, offer.current_version
  end

  test "latest_sent_version returns the most recent frozen version, skipping drafts" do
    offer = create_offer
    v1 = offer.offer_versions.create!(version_number: 1, state: "sent", sent_at: 2.days.ago)
    v2 = offer.offer_versions.create!(version_number: 2, state: "draft")
    assert_equal v1, offer.latest_sent_version

    v2.update!(state: "sent", sent_at: 1.day.ago)
    v3 = offer.offer_versions.create!(version_number: 3, state: "draft")
    assert_equal v2, offer.latest_sent_version
  end

  test "destroying an offer cascades to versions and milestones" do
    offer = create_offer
    version = offer.offer_versions.create!(version_number: 1)
    milestone = version.offer_milestones.create!(title: "M1", trigger: "on_order", net_amount: 100)

    offer.destroy
    assert_nil OfferVersion.find_by(id: version.id)
    assert_nil OfferMilestone.find_by(id: milestone.id)
  end

  test "email_recipients pulls contacts when auto-email is off" do
    customer = customers(:good_eu)
    customer.customer_contacts.update_all(receives_offer_emails: true)
    offer = create_offer(customer: customer, project: projects(:one))

    assert offer.emailable?
    assert_includes offer.email_recipients, "customer@good-company.co.uk"
  end

  test "email_recipients with auto-email enabled uses customer.offer_email_auto_to" do
    customer = customers(:good_eu)
    customer.update!(offer_email_auto_enabled: true, offer_email_auto_to: "auto@example.com")
    offer = create_offer(customer: customer)
    assert_equal [ "auto@example.com" ], offer.email_recipients
  end

  test "email_cc_recipients respects offer_cc_contacts? mode" do
    customer = customers(:good_eu)
    customer.update!(
      offer_email_auto_enabled: true,
      offer_email_auto_to: "auto@example.com",
      offer_email_auto_contact_mode: "cc_contacts"
    )
    customer.customer_contacts.update_all(receives_offer_emails: true)
    offer = create_offer(customer: customer, project: projects(:one))

    cc = offer.email_cc_recipients
    assert_not_empty cc
    assert_not_includes cc, "auto@example.com"
  end
end
