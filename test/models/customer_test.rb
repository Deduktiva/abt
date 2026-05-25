require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  def build_customer(**overrides)
    Customer.new({
      matchcode: "TEST",
      name: "Test Customer",
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

  test "requires name" do
    customer = build_customer(name: nil)
    assert_not customer.valid?
    assert_includes customer.errors[:name], "can't be blank"
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
      document_number: "INV-PROJ2-FILTER",
      published: true,
      date: Date.current,
      due_date: 30.days.from_now,
      sum_net: 100, sum_total: 121
    )

    emails = project_two_invoice.customer.contacts_for_invoice(project_two_invoice).map(&:email)
    assert_includes emails, "customer@good-company.co.uk"
    assert_not_includes emails, "proj001-lead@good-company.co.uk"
  end

  test "contacts_for_invoice excludes contacts with receives_invoice_emails=false" do
    customers(:good_eu).customer_contacts.update_all(receives_invoice_emails: false)
    assert_empty customers(:good_eu).reload.contacts_for_invoice(invoices(:published_invoice))
  end
end
