require "test_helper"

class CustomerContactTest < ActiveSupport::TestCase
  test "should create customer contact with valid attributes" do
    customer = customers(:good_eu)
    contact = CustomerContact.new(
      customer: customer,
      name: "Test Contact",
      email: "test@example.com",
      receives_invoices: true
    )

    assert contact.valid?
    assert contact.save
  end

  test "should require name" do
    customer = customers(:good_eu)
    contact = CustomerContact.new(
      customer: customer,
      email: "test@example.com",
      receives_invoices: true
    )

    assert_not contact.valid?
    assert_includes contact.errors[:name], "can't be blank"
  end

  test "should require email" do
    customer = customers(:good_eu)
    contact = CustomerContact.new(
      customer: customer,
      name: "Test Contact",
      receives_invoices: true
    )

    assert_not contact.valid?
    assert_includes contact.errors[:email], "can't be blank"
  end

  test "should require valid email format" do
    customer = customers(:good_eu)
    contact = CustomerContact.new(
      customer: customer,
      name: "Test Contact",
      email: "invalid-email",
      receives_invoices: true
    )

    assert_not contact.valid?
    assert_includes contact.errors[:email], "is invalid"
  end

  test "should require customer" do
    contact = CustomerContact.new(
      name: "Test Contact",
      email: "test@example.com",
      receives_invoices: true
    )

    assert_not contact.valid?
    assert_includes contact.errors[:customer], "must exist"
  end

  test "receives_invoices_for_project should return false when receives_invoices is false" do
    customer = customers(:good_eu)
    project = projects(:one)
    contact = CustomerContact.create!(
      customer: customer,
      name: "Test Contact",
      email: "test@example.com",
      receives_invoices: false
    )

    assert_not contact.receives_invoices_for_project?(project)
  end

  test "receives_invoices_for_project should return true when receives_invoices is true and no specific projects" do
    customer = customers(:good_eu)
    project = projects(:one)
    contact = CustomerContact.create!(
      customer: customer,
      name: "Test Contact",
      email: "test@example.com",
      receives_invoices: true
    )

    assert contact.receives_invoices_for_project?(project)
  end

  test "receives_invoices_for_project should return true when receives_invoices is true and project is associated" do
    customer = customers(:good_eu)
    project = projects(:one)
    contact = CustomerContact.create!(
      customer: customer,
      name: "Test Contact",
      email: "test@example.com",
      receives_invoices: true
    )
    contact.projects = [project]

    assert contact.receives_invoices_for_project?(project)
  end

  test "receives_invoices_for_project should return false when receives_invoices is true but project is not associated" do
    customer = customers(:good_eu)
    project1 = projects(:one)
    project2 = projects(:two)
    contact = CustomerContact.create!(
      customer: customer,
      name: "Test Contact",
      email: "test@example.com",
      receives_invoices: true
    )
    contact.projects = [project1]

    assert_not contact.receives_invoices_for_project?(project2)
  end

  test "should destroy associated customer_contact_projects when destroyed" do
    customer = customers(:good_eu)
    project = projects(:one)
    contact = CustomerContact.create!(
      customer: customer,
      name: "Test Contact",
      email: "test@example.com",
      receives_invoices: true
    )
    contact.projects = [project]

    assert_equal 1, contact.customer_contact_projects.count
    contact_project_id = contact.customer_contact_projects.first.id

    contact.destroy

    assert_not CustomerContactProject.exists?(contact_project_id)
  end
end
