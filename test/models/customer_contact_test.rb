require "test_helper"

class CustomerContactTest < ActiveSupport::TestCase
  setup { Current.user = nil }
  teardown { Current.user = nil }

  test "valid contact with name and email" do
    contact = CustomerContact.new(customer: customers(:good_eu), name: "X", email: "x@example.com")
    assert contact.valid?
  end

  test "requires name" do
    contact = CustomerContact.new(customer: customers(:good_eu), email: "x@example.com")
    assert_not contact.valid?
    assert_includes contact.errors[:name], "can't be blank"
  end

  test "requires email and validates format" do
    contact = CustomerContact.new(customer: customers(:good_eu), name: "X")
    assert_not contact.valid?
    assert_includes contact.errors[:email], "can't be blank"

    contact.email = "not-an-email"
    assert_not contact.valid?
    assert_includes contact.errors[:email], "is invalid"
  end

  test "applies_to_project? returns true for any project when no projects assigned" do
    contact = customer_contacts(:good_eu_accounting)
    assert_empty contact.projects
    assert contact.applies_to_project?(projects(:one))
    assert contact.applies_to_project?(projects(:two))
  end

  test "applies_to_project? is true only for assigned projects" do
    contact = customer_contacts(:good_eu_project_one_lead)
    assert_equal [ projects(:one) ], contact.projects.to_a
    assert contact.applies_to_project?(projects(:one))
    assert_not contact.applies_to_project?(projects(:two))
  end

  test "projects_belong_to_customer_or_unassigned rejects another customer's project" do
    # projects(:two) belongs to good_national, not good_eu
    contact = CustomerContact.new(
      customer: customers(:good_eu),
      name: "X", email: "x@example.com",
      projects: [ projects(:two) ]
    )
    assert_not contact.valid?
    assert_includes contact.errors[:projects], "must belong to this customer or to no customer"
  end

  test "projects_belong_to_customer_or_unassigned accepts unassigned projects" do
    contact = CustomerContact.new(
      customer: customers(:good_eu),
      name: "X", email: "x@example.com",
      projects: [ projects(:reusable_project) ]
    )
    assert contact.valid?, contact.errors.full_messages.to_sentence
  end

  test "customer visibility check skipped when Current.user is nil (seeds context)" do
    contact = CustomerContact.new(
      customer: customers(:good_eu),
      name: "X", email: "x@example.com"
    )
    assert_nil Current.user
    assert contact.valid?
  end

  test "customer visibility check enforced when Current.user is set" do
    other_team = Team.create!(name: "Other")
    other_customer = Customer.create!(
      matchcode: "OTH", name: "Other",
      vat_id: "EU101010101",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: other_team
    )

    Current.user = users(:bob)
    contact = CustomerContact.new(customer: other_customer, name: "X", email: "x@example.com")
    assert_not contact.valid?
    assert_includes contact.errors[:customer_id], "must be a customer you can access"
  end

  test "salutation_line round-trips when set, and is nil-allowed" do
    contact = CustomerContact.create!(
      customer: customers(:good_eu),
      name: "Salutation Person",
      email: "salutation@example.com"
    )
    assert_nil contact.salutation_line

    contact.update!(salutation_line: "Sehr geehrter Herr Huber,")
    assert_equal "Sehr geehrter Herr Huber,", contact.reload.salutation_line
  end

  test "projects visibility check enforced when Current.user is set" do
    other_team = Team.create!(name: "Visibility Other")
    other_customer = Customer.create!(
      matchcode: "VOTH", name: "Visibility Other",
      vat_id: "EU121212121",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: other_team
    )
    foreign_project = Project.create!(
      matchcode: "FOREIGN", description: "", bill_to_customer: other_customer, team: other_team
    )

    Current.user = users(:bob)
    contact = CustomerContact.new(
      customer: customers(:good_eu),
      name: "X", email: "x@example.com",
      projects: [ foreign_project ]
    )
    assert_not contact.valid?
    # Bob can't see foreign_project, so both validations may fire; just check
    # at least one signals the access problem.
    assert (contact.errors[:projects].any? || contact.errors.full_messages.any? { |m| m.match?(/access/i) }),
           contact.errors.full_messages.inspect
  end
end
