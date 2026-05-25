require "test_helper"

class CustomerTeamScopingTest < ActiveSupport::TestCase
  test "visible_to returns all customers for bypass users" do
    visible = Customer.visible_to(users(:alice)).pluck(:id).sort
    assert_equal Customer.pluck(:id).sort, visible
  end

  test "visible_to filters by team for non-bypass users" do
    acme_customer = Customer.create!(
      matchcode: "ACME_ONLY",
      name: "Acme Only",
      vat_id: "EU111111111",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: teams(:acme)
    )
    # Bob is in Default + Acme
    bob_visible = Customer.visible_to(users(:bob)).pluck(:id)
    assert_includes bob_visible, acme_customer.id
    assert_includes bob_visible, customers(:good_eu).id

    # blocked_carol is in no teams
    refute_includes Customer.visible_to(users(:blocked_carol)).pluck(:id), acme_customer.id
  end

  test "current user must be a member of the target team" do
    bob = users(:bob)
    # bob is in Default + Acme; bob can assign to Acme.
    Current.set(user: bob) do
      customer = Customer.new(
        matchcode: "AS_BOB",
        name: "Bob Customer",
        vat_id: "EU222222222",
        sales_tax_customer_class: sales_tax_customer_classes(:eu),
        language: languages(:english),
        team: teams(:acme)
      )
      assert customer.valid?
    end

    # Create a team bob is NOT in.
    other_team = Team.create!(name: "Stranger")
    Current.set(user: bob) do
      customer2 = Customer.new(
        matchcode: "BAD_BOB",
        name: "Bob Bad",
        vat_id: "EU333333333",
        sales_tax_customer_class: sales_tax_customer_classes(:eu),
        language: languages(:english),
        team: other_team
      )
      refute customer2.valid?
      assert_includes customer2.errors[:team_id], "must be a team you are a member of"
    end
  end

  test "bypass user can assign to any team" do
    alice = users(:alice)
    other_team = Team.create!(name: "StrangerToAlice")
    refute alice.teams.include?(other_team)
    Current.set(user: alice) do
      customer = Customer.new(
        matchcode: "AS_ALICE",
        name: "Alice Customer",
        vat_id: "EU444444444",
        sales_tax_customer_class: sales_tax_customer_classes(:eu),
        language: languages(:english),
        team: other_team
      )
      assert customer.valid?
    end
  end

  # System contexts (seeds, console, background jobs) have no Current.user
  # set. The validation skips so they can legitimately seed records.
  test "system contexts without a current user are allowed to assign" do
    other_team = Team.create!(name: "SystemOnly")
    customer = Customer.new(
      matchcode: "SYS",
      name: "System Customer",
      vat_id: "EU555555555",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: other_team
    )
    # Current.user is nil in this test body.
    assert customer.valid?
  end
end
