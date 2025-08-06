require "test_helper"

class CustomerContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @customer = customers(:good_eu)
    @customer_contact = customer_contacts(:anna)
  end

  test "should get new contact form via browser request" do
    get new_customer_customer_contact_path(@customer)
    assert_redirected_to @customer
  end

  test "should create customer contact" do
    assert_difference('CustomerContact.count') do
      post customer_customer_contacts_url(@customer), params: {
        customer_contact: {
          name: "New Contact",
          email: "new@example.com",
          receives_invoices: true
        }
      }, as: :json
    end

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal "New Contact", response_data['contact']['name']
  end

  test "should not create customer contact with invalid params" do
    assert_no_difference('CustomerContact.count') do
      post customer_customer_contacts_url(@customer), params: {
        customer_contact: {
          name: "",
          email: "invalid-email",
          receives_invoices: true
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_not response_data['success']
    assert_includes response_data['errors'], "Name can't be blank"
    assert_includes response_data['errors'], "Email is invalid"
  end

  test "should update customer contact" do
    patch customer_contact_url(@customer_contact), params: {
      customer_contact: {
        name: "Updated Name",
        email: "updated@example.com",
        receives_invoices: false
      }
    }, as: :json

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success']

    @customer_contact.reload
    assert_equal "Updated Name", @customer_contact.name
    assert_equal "updated@example.com", @customer_contact.email
    assert_not @customer_contact.receives_invoices
  end

  test "should not update customer contact with invalid params" do
    patch customer_contact_url(@customer_contact), params: {
      customer_contact: {
        name: "",
        email: "invalid-email"
      }
    }, as: :json

    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_not response_data['success']
    assert_includes response_data['errors'], "Name can't be blank"
    assert_includes response_data['errors'], "Email is invalid"
  end

  test "should update customer contact projects" do
    project1 = projects(:one)
    project2 = projects(:test_project)  # Both belong to good_eu

    patch customer_contact_url(@customer_contact), params: {
      customer_contact: {
        project_ids: [project1.id, project2.id]
      }
    }, as: :json

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success']

    @customer_contact.reload
    assert_includes @customer_contact.projects, project1
    assert_includes @customer_contact.projects, project2
  end

  test "should destroy customer contact" do
    assert_difference('CustomerContact.count', -1) do
      delete customer_contact_url(@customer_contact), as: :json
    end

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success']
  end
end
