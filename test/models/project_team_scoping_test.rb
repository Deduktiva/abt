require "test_helper"

class ProjectTeamScopingTest < ActiveSupport::TestCase
  test "project team must match customer team when bill_to_customer is set" do
    acme_customer = Customer.create!(
      matchcode: "ACME_CUST",
      name: "Acme Co.",
      vat_id: "EU666666666",

      country_iso2: "NL",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: teams(:acme)
    )

    # Mismatched team should be invalid.
    project = Project.new(
      matchcode: "MISMATCH",
      description: "mismatched",
      bill_to_customer: acme_customer,
      team: teams(:default)
    )
    refute project.valid?
    assert_match(/must match the team of the bill-to customer/, project.errors[:team_id].first)

    # Matching team is valid.
    project.team = teams(:acme)
    assert project.valid?
  end

  test "reusable project (no customer) is free to pick any team" do
    project = Project.new(
      matchcode: "REUSE",
      description: "no customer",
      bill_to_customer: nil,
      team: teams(:acme)
    )
    assert project.valid?
  end

  test "visible_to filters by team" do
    acme_customer = Customer.create!(
      matchcode: "ACME_CUST2",
      name: "Acme 2",
      vat_id: "EU777777777",

      country_iso2: "NL",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: teams(:acme)
    )
    acme_project = Project.create!(
      matchcode: "ACMEPRJ",
      description: "Acme only project",
      bill_to_customer: acme_customer,
      team: teams(:acme)
    )

    bob_visible = Project.visible_to(users(:bob)).pluck(:id)
    assert_includes bob_visible, acme_project.id

    carol_visible = Project.visible_to(users(:blocked_carol)).pluck(:id)
    refute_includes carol_visible, acme_project.id
  end
end
