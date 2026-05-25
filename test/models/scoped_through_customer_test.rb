require "test_helper"

# Regression coverage for the ScopedThroughCustomer concern. Invoices and
# delivery notes have no team_id of their own — visibility is derived from
# their customer. Without this concern a user with invoices.edit/
# delivery_notes.edit in team A could mass-assign `customer_id` pointing
# at another team's customer and plant a record in that team's books.
class ScopedThroughCustomerTest < ActiveSupport::TestCase
  setup do
    # bob is in Default + Acme (per fixtures); create a team he's NOT in
    # and a customer/project hanging off it.
    @other_team = Team.create!(name: "Other")
    @other_customer = Customer.create!(
      matchcode: "OTHER",
      name: "Other Co",
      vat_id: "EU888888888",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: @other_team
    )
    @other_project = Project.create!(
      matchcode: "OTHER_PROJ",
      bill_to_customer: @other_customer,
      team: @other_team
    )
  end

  test "Invoice.new rejects customer_id from a team Current.user can't see" do
    Current.set(user: users(:bob)) do
      invoice = Invoice.new(customer_id: @other_customer.id)
      refute invoice.valid?
      assert_includes invoice.errors[:customer_id], "must be a customer you can access"
    end
  end

  test "Invoice.new rejects project_id from a team Current.user can't see" do
    Current.set(user: users(:bob)) do
      invoice = Invoice.new(customer: customers(:good_eu), project_id: @other_project.id)
      refute invoice.valid?
      assert_includes invoice.errors[:project_id], "must be a project you can access"
    end
  end

  test "Invoice.new accepts customer_id from a team Current.user can see" do
    Current.set(user: users(:bob)) do
      invoice = Invoice.new(customer: customers(:good_eu), project: projects(:one))
      assert invoice.valid?, invoice.errors.full_messages.inspect
    end
  end

  test "Invoice.new bypasses scope for bypass_team_scoping users" do
    Current.set(user: users(:alice)) do
      invoice = Invoice.new(customer: @other_customer, project: @other_project)
      assert invoice.valid?, invoice.errors.full_messages.inspect
    end
  end

  test "Invoice.new in a system context (no Current.user) is allowed" do
    invoice = Invoice.new(customer: @other_customer, project: @other_project)
    assert invoice.valid?, invoice.errors.full_messages.inspect
  end

  test "DeliveryNote.new rejects customer_id from a team Current.user can't see" do
    Current.set(user: users(:bob)) do
      dn = DeliveryNote.new(customer_id: @other_customer.id,
                            delivery_start_date: Date.current)
      refute dn.valid?
      assert_includes dn.errors[:customer_id], "must be a customer you can access"
    end
  end

  test "DeliveryNote.new rejects project_id from a team Current.user can't see" do
    Current.set(user: users(:bob)) do
      dn = DeliveryNote.new(customer: customers(:good_eu),
                            project_id: @other_project.id,
                            delivery_start_date: Date.current)
      refute dn.valid?
      assert_includes dn.errors[:project_id], "must be a project you can access"
    end
  end

  test "DeliveryNote.new accepts customer_id from a team Current.user can see" do
    Current.set(user: users(:bob)) do
      dn = DeliveryNote.new(customer: customers(:good_eu),
                            project: projects(:one),
                            delivery_start_date: Date.current)
      assert dn.valid?, dn.errors.full_messages.inspect
    end
  end
end
