require "test_helper"

class CustomerContactProjectTest < ActiveSupport::TestCase
  test "should create customer contact project with valid attributes" do
    customer = customers(:good_eu)
    project = projects(:one)
    contact = CustomerContact.create!(
      customer: customer,
      name: "Test Contact",
      email: "test@example.com",
      receives_invoices: true
    )

    contact_project = CustomerContactProject.new(
      customer_contact: contact,
      project: project
    )

    assert contact_project.valid?
    assert contact_project.save
  end

  test "should require customer contact" do
    project = projects(:one)
    contact_project = CustomerContactProject.new(project: project)

    assert_not contact_project.valid?
    assert_includes contact_project.errors[:customer_contact], "must exist"
  end

  test "should require project" do
    customer = customers(:good_eu)
    contact = CustomerContact.create!(
      customer: customer,
      name: "Test Contact",
      email: "test@example.com",
      receives_invoices: true
    )

    contact_project = CustomerContactProject.new(customer_contact: contact)

    assert_not contact_project.valid?
    assert_includes contact_project.errors[:project], "must exist"
  end

  test "should validate that project belongs to same customer as contact" do
    good_customer = customers(:good_eu)
    local_customer = customers(:good_national)

    # Project belongs to local_customer
    project = projects(:two)

    # Contact belongs to good_customer
    contact = CustomerContact.create!(
      customer: good_customer,
      name: "Test Contact",
      email: "test@example.com",
      receives_invoices: true
    )

    contact_project = CustomerContactProject.new(
      customer_contact: contact,
      project: project
    )

    assert_not contact_project.valid?
    assert_includes contact_project.errors[:project], "must belong to the same customer as the contact"
  end

  test "should allow project that belongs to same customer as contact" do
    customer = customers(:good_eu)
    project = projects(:one)
    contact = CustomerContact.create!(
      customer: customer,
      name: "Test Contact",
      email: "test@example.com",
      receives_invoices: true
    )

    contact_project = CustomerContactProject.new(
      customer_contact: contact,
      project: project
    )

    assert contact_project.valid?
  end
end
