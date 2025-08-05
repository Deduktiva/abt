require 'test_helper'

class ProjectTest < ActiveSupport::TestCase
  def setup
    @customer = customers(:good_eu)
    @project = Project.create!(
      matchcode: 'TEST_PROJECT',
      description: 'Test project',
      bill_to_customer: @customer
    )
  end

  test "should be valid" do
    assert @project.valid?
  end

  test "should require matchcode" do
    @project.matchcode = nil
    assert_not @project.valid?
    assert_not_nil @project.errors[:matchcode]
  end

  test "should be active by default" do
    new_project = Project.new(
      matchcode: 'NEW_PROJECT',
      bill_to_customer: @customer
    )
    assert new_project.active?
  end

  test "should have active and inactive scopes" do
    # Create some test projects
    active_project = Project.create!(
      matchcode: 'ACTIVE',
      bill_to_customer: @customer,
      active: true
    )

    inactive_project = Project.create!(
      matchcode: 'INACTIVE',
      bill_to_customer: @customer,
      active: false
    )

    assert_includes Project.active, active_project
    assert_not_includes Project.active, inactive_project
    assert_includes Project.inactive, inactive_project
    assert_not_includes Project.inactive, active_project
  end

  test "should detect when used in invoices" do
    # Initially not used
    assert_not @project.used_in_invoices?
    assert @project.can_be_deleted?
    assert_not @project.can_be_deactivated?

    # Create an invoice using this project
    Invoice.create!(
      customer: @customer,
      project: @project
    )

    # Now it should be detected as used
    assert @project.used_in_invoices?
    assert_not @project.can_be_deleted?
    assert @project.can_be_deactivated?
  end

  test "should prevent deletion when used in invoices" do
    # Create an invoice using this project
    Invoice.create!(
      customer: @customer,
      project: @project
    )

    assert_not @project.destroy
    assert_includes @project.errors[:base], "Cannot delete project that has been used in invoices"
  end

  test "should allow deletion when not used in invoices" do
    # Project is not used in any invoices
    assert @project.destroy
  end

  test "display_name should return description when present" do
    @project.description = "My Project Description"
    assert_equal "My Project Description", @project.display_name
  end

  test "display_name should return matchcode when description is blank" do
    @project.description = ""
    assert_equal @project.matchcode, @project.display_name

    @project.description = nil
    assert_equal @project.matchcode, @project.display_name
  end

  test "should have association with invoices" do
    assert_respond_to @project, :invoices
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @project.invoices
  end

  test "should belong to bill_to_customer" do
    assert_respond_to @project, :bill_to_customer
    assert_equal @customer, @project.bill_to_customer
  end

  test "should allow projects without bill_to_customer" do
    project_without_customer = Project.new(
      matchcode: 'NO_CUSTOMER_PROJECT',
      description: 'Project without customer'
    )

    assert project_without_customer.valid?
    assert_nil project_without_customer.bill_to_customer

    # Should be able to save
    assert project_without_customer.save

    # Should still have all expected methods
    assert_respond_to project_without_customer, :bill_to_customer
    assert_equal 'Project without customer', project_without_customer.display_name
  end
end