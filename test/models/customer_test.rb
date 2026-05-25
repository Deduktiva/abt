require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  def build_customer(**overrides)
    Customer.new({
      matchcode: "TEST",
      name: "Test Customer",
      vat_id: "EU000000000",
      country_iso2: "NL",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: teams(:default),
      active: true
    }.merge(overrides))
  end

  def create_customer(**overrides)
    build_customer(**overrides).tap(&:save!)
  end

  test "requires matchcode" do
    customer = build_customer(matchcode: nil)
    assert_not customer.valid?
    assert_includes customer.errors[:matchcode], "can't be blank"
  end

  test "matchcode rejects whitespace and single character" do
    [ "A", "AB C", " AB", "AB\t" ].each do |bad|
      customer = build_customer(matchcode: bad)
      assert_not customer.valid?, "expected #{bad.inspect} to be invalid"
      assert_includes customer.errors[:matchcode], "is invalid"
    end
  end

  test "matchcode allows mixed case and any length >= 2" do
    customer = build_customer(matchcode: "aB")
    assert customer.valid?, customer.errors.full_messages.inspect
    customer = build_customer(matchcode: "MixedCaseLongMatchcode1234567890")
    assert customer.valid?, customer.errors.full_messages.inspect
  end

  test "requires name" do
    customer = build_customer(name: nil)
    assert_not customer.valid?
    assert_includes customer.errors[:name], "can't be blank"
  end

  test "requires country_iso2" do
    customer = build_customer(country_iso2: nil)
    assert_not customer.valid?
    assert_includes customer.errors[:country_iso2], "can't be blank"
  end

  test "rejects ZZ sentinel and other non-ISO country codes" do
    [ "ZZ", "XX", "GERMANY", "" ].each do |bad|
      customer = build_customer(country_iso2: bad)
      assert_not customer.valid?, "expected #{bad.inspect} to be invalid"
    end
  end

  test "requires vat_id when its sales_tax_customer_class requires one" do
    customer = build_customer(vat_id: nil, sales_tax_customer_class: sales_tax_customer_classes(:eu))
    assert_not customer.valid?
    assert_includes customer.errors[:vat_id], "can't be blank"
  end

  test "allows blank vat_id when its sales_tax_customer_class does not require one" do
    customer = build_customer(vat_id: nil, sales_tax_customer_class: sales_tax_customer_classes(:restoftheworld))
    assert customer.valid?, customer.errors.full_messages.inspect
  end

  test "matchcode must be globally unique across all teams" do
    create_customer(matchcode: "DUPE", team: teams(:default))
    duplicate = build_customer(matchcode: "DUPE", team: teams(:acme))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:matchcode], "has already been taken"
  end

  test "matchcode uniqueness is case-insensitive" do
    create_customer(matchcode: "Dupe", team: teams(:default))
    duplicate = build_customer(matchcode: "DUPE", team: teams(:default))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:matchcode], "has already been taken"
  end

  test "set_default_language assigns English on create when language is not set" do
    customer = build_customer(language: nil)
    customer.valid?
    assert_equal languages(:english), customer.language
  end

  test "set_default_language does not override an explicitly set language" do
    customer = build_customer(language: languages(:german))
    customer.valid?
    assert_equal languages(:german), customer.language
  end

  test "set_default_language only runs on create" do
    customer = create_customer(language: nil)
    customer.language = nil
    customer.valid?
    assert_nil customer.language
  end

  test "used_in_invoices? is true for a customer with invoices" do
    assert customers(:good_eu).used_in_invoices?
  end

  test "used_in_invoices? is false for a customer without invoices" do
    assert_not create_customer.used_in_invoices?
  end

  test "before_destroy rejects destroy when invoices reference the customer" do
    customer = customers(:good_eu)
    assert_not customer.destroy
    assert_includes customer.errors[:base], "Cannot delete customer that has been used in invoices"
  end

  test "destroy succeeds when no invoices reference the customer" do
    assert create_customer.destroy
  end

  test "before_destroy rejects destroy when delivery notes reference the customer" do
    customer = create_customer
    DeliveryNote.create!(customer: customer, project: projects(:reusable_project), delivery_start_date: Date.current)
    assert_not customer.destroy
    assert_includes customer.errors[:base], "Cannot delete customer that has been used in delivery notes"
  end

  test "used_in_delivery_notes? is true for a customer with delivery notes" do
    customer = create_customer
    DeliveryNote.create!(customer: customer, project: projects(:reusable_project), delivery_start_date: Date.current)
    assert customer.used_in_delivery_notes?
  end

  test "database rejects deleting a customer still referenced by an invoice" do
    # no_email_customer has an invoice but no delivery note, so this exercises
    # the invoices FK specifically (not the pre-existing delivery_notes FK).
    assert_raises(ActiveRecord::InvalidForeignKey) { customers(:no_email_customer).delete }
  end

  test "active scope returns only active customers" do
    inactive = create_customer(active: false)
    assert_includes Customer.active, customers(:good_eu)
    assert_not_includes Customer.active, inactive
  end

  # Without this cascade, projects billing to the customer would be left
  # with team_id pointing at the old team — instantly violating
  # Project#team_must_match_customer (no save possible) and invisible to
  # members of the new team because TeamOwned#visible_to filters by team_id.
  test "changing a customer's team cascades to projects billing that customer" do
    customer = create_customer(team: teams(:default))
    project = Project.create!(matchcode: "P1", bill_to_customer: customer, team: teams(:default))

    customer.update!(team: teams(:acme))

    assert_equal teams(:acme).id, project.reload.team_id
  end

  test "changing a customer's team leaves unrelated projects alone" do
    customer = create_customer(team: teams(:default))
    other_customer = create_customer(matchcode: "OTHER", team: teams(:default))
    project = Project.create!(matchcode: "P2", bill_to_customer: other_customer, team: teams(:default))

    customer.update!(team: teams(:acme))

    assert_equal teams(:default).id, project.reload.team_id
  end

  test "inactive scope returns only inactive customers" do
    inactive = create_customer(active: false)
    assert_includes Customer.inactive, inactive
    assert_not_includes Customer.inactive, customers(:good_eu)
  end

  test "destroying a customer cascades to its customer contacts" do
    customer = create_customer
    customer.customer_contacts.create!(name: "X", email: "x@example.com")
    contact_id = customer.customer_contacts.first.id

    assert customer.destroy
    assert_nil CustomerContact.find_by(id: contact_id)
  end

  test "contacts_for_invoice picks up no-project and matching-project contacts" do
    invoice = invoices(:published_invoice)
    contacts = invoice.customer.contacts_for_invoice(invoice)

    assert_includes contacts.map(&:email), "customer@good-company.co.uk"      # no projects
    assert_includes contacts.map(&:email), "proj001-lead@good-company.co.uk"  # project: one
  end

  test "contacts_for_invoice excludes contacts whose projects do not match" do
    project_two_invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:two),
      attachment: attachments(:invoice_pdf),
      date: Date.current,
      due_date: 30.days.from_now
    )
    project_two_invoice.invoice_lines.create!(type: "item", title: "X", quantity: 1.0, rate: 100.0, position: 1)
    project_two_invoice.update!(published: true, document_number: "INV-PROJ2-FILTER", sum_net: 100, sum_total: 121)

    emails = project_two_invoice.customer.contacts_for_invoice(project_two_invoice).map(&:email)
    assert_includes emails, "customer@good-company.co.uk"
    assert_not_includes emails, "proj001-lead@good-company.co.uk"
  end

  test "contacts_for_invoice excludes contacts with receives_invoice_emails=false" do
    customers(:good_eu).customer_contacts.update_all(receives_invoice_emails: false)
    assert_empty customers(:good_eu).reload.contacts_for_invoice(invoices(:published_invoice))
  end

  test "vat_verification_required scope returns only active customers with vat_id and vat_id_required tax class" do
    assert_includes Customer.vat_verification_required, customers(:good_eu)

    inactive = create_customer(matchcode: "INACTIVE", active: false)
    assert_not_includes Customer.vat_verification_required, inactive

    not_required_class = create_customer(matchcode: "NOTREQ", vat_id: "EXP000", sales_tax_customer_class: sales_tax_customer_classes(:restoftheworld))
    assert_not_includes Customer.vat_verification_required, not_required_class

    blank_vat = create_customer(matchcode: "BLANKVAT", vat_id: nil, sales_tax_customer_class: sales_tax_customer_classes(:restoftheworld))
    assert_not_includes Customer.vat_verification_required, blank_vat
  end

  test "changing vat_id clears vat_id_verified_at" do
    customer = create_customer(vat_id: "BE0123456749")
    customer.update!(vat_id_verified_at: Time.current)
    customer.update!(vat_id: "BE0987654321")
    assert_nil customer.reload.vat_id_verified_at
  end

  test "updating unrelated field preserves vat_id_verified_at" do
    customer = create_customer(vat_id: "BE0123456749")
    timestamp = 2.days.ago
    customer.update!(vat_id_verified_at: timestamp)
    customer.update!(name: "Renamed Co.")
    assert_in_delta timestamp, customer.reload.vat_id_verified_at, 1.second
  end

  # Pins the before_save callback ordering: normalise must run BEFORE the
  # clear callback, otherwise resaving "BE 0123.456-749" against a stored
  # "BE0123456749" would spuriously clear vat_id_verified_at.
  test "resaving cosmetically-different vat_id does not clear vat_id_verified_at" do
    customer = create_customer(vat_id: "BE0123456749")
    timestamp = 2.days.ago
    customer.update!(vat_id_verified_at: timestamp)
    customer.update!(vat_id: " BE 0123.456-749 ")
    assert_in_delta timestamp, customer.reload.vat_id_verified_at, 1.second
  end

  test "normalises vat_id on save (uppercase, strips whitespace, dots, dashes)" do
    customer = create_customer(vat_id: "  be 0123.456-749 ")
    assert_equal "BE0123456749", customer.reload.vat_id
  end

  test "normalise_vat_id is the class-level normalisation entry point" do
    assert_equal "ATU12345678", Customer.normalise_vat_id("at u 12.345-678")
    assert_equal "", Customer.normalise_vat_id(nil)
  end

  test "current_vat_verification returns the latest verification when vat_id matches" do
    customer = customers(:good_eu)
    customer.update_columns(vat_id: "BE0123456749")
    verification = CustomerVatVerification.create!(
      customer: customer, vat_id: "BE0123456749",
      valid_response: false, error_code: "INVALID"
    )
    assert_equal verification, customer.current_vat_verification
  end

  test "current_vat_verification returns nil when vat_id differs from latest verification" do
    customer = customers(:good_eu)
    customer.update_columns(vat_id: "BE0123456749")
    CustomerVatVerification.create!(
      customer: customer, vat_id: "BE0123456749",
      valid_response: false, error_code: "INVALID"
    )
    customer.update!(vat_id: "BE0987654321")
    assert_nil customer.current_vat_verification
  end

  test "strips surrounding whitespace from invoice_email_auto_to before save" do
    customer = customers(:auto_email_customer)
    customer.update!(invoice_email_auto_to: "  billing@autoemail.com  ")
    assert_equal "billing@autoemail.com", customer.reload.invoice_email_auto_to
  end

  test "rejects an invoice_email_auto_to that is not a valid email" do
    customer = build_customer(invoice_email_auto_to: "not-an-email")
    assert_not customer.valid?
    assert_includes customer.errors[:invoice_email_auto_to], "is invalid"
  end

  test "allows blank invoice_email_auto_to" do
    customer = build_customer(invoice_email_auto_to: nil)
    assert customer.valid?, customer.errors.full_messages.inspect

    customer = build_customer(invoice_email_auto_to: "")
    assert customer.valid?, customer.errors.full_messages.inspect
  end

  test "offer columns round-trip with sensible defaults" do
    customer = create_customer
    assert_nil customer.offer_boilerplate
    assert_nil customer.offer_validity_days
    assert_equal false, customer.offer_email_auto_enabled
    assert_equal "", customer.offer_email_auto_to
    assert_equal "", customer.offer_email_auto_subject_template
    assert_equal "replace_contacts", customer.offer_email_auto_contact_mode
  end

  test "offer_email_auto_contact_mode predicates are prefixed to avoid collision with invoice enum" do
    customer = create_customer(offer_email_auto_contact_mode: "cc_contacts")
    assert customer.offer_cc_contacts?
    assert_not customer.offer_replace_contacts?
    # Invoice enum predicates remain unprefixed:
    assert customer.replace_contacts?
  end

  test "offer_email_auto_contact_mode_label reads from the shared labels map" do
    customer = create_customer(offer_email_auto_contact_mode: "cc_contacts")
    assert_equal "Auto address in To, contacts in CC", customer.offer_email_auto_contact_mode_label
  end

  test "offer_milestone_rule_configured? requires threshold plus at least one templates list" do
    customer = create_customer
    assert_not customer.offer_milestone_rule_configured?

    customer.update!(offer_milestone_split_threshold: 10_000)
    assert_not customer.offer_milestone_rule_configured?

    customer.update!(offer_milestone_templates_below: "Wrap-up|on_acceptance|1.0")
    assert customer.offer_milestone_rule_configured?
  end

  test "scaffold_offer_milestones below threshold parses the below-templates list" do
    customer = create_customer(
      offer_milestone_split_threshold: 10_000,
      offer_milestone_templates_below: "Wrap-up|on_acceptance|1.0"
    )
    milestones = customer.scaffold_offer_milestones(5_000)
    assert_equal 1, milestones.size
    assert_equal "Wrap-up", milestones.first[:title]
    assert_equal "on_acceptance", milestones.first[:trigger]
    assert_equal BigDecimal("5000"), milestones.first[:net_amount]
  end

  test "scaffold_offer_milestones above threshold supports any number of milestones" do
    customer = create_customer(
      offer_milestone_split_threshold: 10_000,
      offer_milestone_templates_above: <<~TEMPLATES.strip
        Kick-off|on_order|0.30
        Mid-point|on_acceptance|0.30
        Final delivery|on_acceptance|0.40
      TEMPLATES
    )
    milestones = customer.scaffold_offer_milestones(20_000)
    assert_equal 3, milestones.size
    assert_equal [ "Kick-off", "Mid-point", "Final delivery" ], milestones.map { |m| m[:title] }
    assert_equal [ "on_order", "on_acceptance", "on_acceptance" ], milestones.map { |m| m[:trigger] }
    assert_equal BigDecimal("20000"), milestones.sum { |m| m[:net_amount] }
  end

  test "scaffold_offer_milestones absorbs rounding into the last row so amounts sum to total" do
    customer = create_customer(
      offer_milestone_split_threshold: 10_000,
      offer_milestone_templates_above: <<~TEMPLATES.strip
        A|on_order|0.3333
        B|on_acceptance|0.3333
        C|on_acceptance|0.3334
      TEMPLATES
    )
    milestones = customer.scaffold_offer_milestones(100)
    assert_equal BigDecimal("100"), milestones.sum { |m| m[:net_amount] }
  end

  test "scaffold_offer_milestones falls back to a placeholder when no templates parse" do
    customer = create_customer
    milestones = customer.scaffold_offer_milestones(50_000)
    assert_equal 1, milestones.size
    assert_equal "Milestone", milestones.first[:title]
  end

  test "scaffold_offer_milestones silently skips malformed template lines" do
    customer = create_customer(
      offer_milestone_split_threshold: 10_000,
      offer_milestone_templates_below: <<~TEMPLATES
        broken-line-without-three-parts
        empty|trigger|
        Bad|not_a_trigger|1.0
        Wrap-up|on_acceptance|1.0
      TEMPLATES
    )
    milestones = customer.scaffold_offer_milestones(1_000)
    assert_equal 1, milestones.size
    assert_equal "Wrap-up", milestones.first[:title]
  end
end
