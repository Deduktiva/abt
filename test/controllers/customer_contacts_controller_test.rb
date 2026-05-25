require "test_helper"

class CustomerContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @customer = customers(:good_eu)
    @contact  = customer_contacts(:good_eu_accounting)
  end

  # --- shape / Turbo Frame contract ----------------------------------------

  test "new renders the new_customer_contact frame" do
    get new_customer_customer_contact_path(@customer)
    assert_response :success
    assert_select "turbo-frame#new_customer_contact"
  end

  test "create on success appends row and replaces add-link with turbo-stream" do
    assert_difference -> { @customer.customer_contacts.count }, +1 do
      post customer_customer_contacts_path(@customer),
           params: { customer_contact: { name: "Adam", email: "adam@example.com", receives_invoice_emails: true } },
           headers: { Accept: "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_includes response.media_type, "turbo-stream"
    new_contact = @customer.customer_contacts.find_by(email: "adam@example.com")
    assert_select %(turbo-stream[action="append"][target="customer_contacts_tbody"]) do
      assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(new_contact)}"
    end
    assert_select %(turbo-stream[action="replace"][target="new_customer_contact"])
  end

  test "create on validation failure re-renders the new frame with 422" do
    assert_no_difference -> { @customer.customer_contacts.count } do
      post customer_customer_contacts_path(@customer),
           params: { customer_contact: { name: "", email: "not-an-email" } }
    end

    assert_response :unprocessable_content
    assert_select "turbo-frame#new_customer_contact"
  end

  test "edit returns the row frame containing the form" do
    get edit_customer_contact_path(@contact)
    assert_response :success
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(@contact)}"
    assert_select "input[name=?]", "customer_contact[name]"
  end

  test "update on success renders the read-only row partial inside the frame" do
    patch customer_contact_path(@contact),
          params: { customer_contact: { name: "Renamed Acct", email: @contact.email } }

    assert_response :success
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(@contact)}"
    assert_equal "Renamed Acct", @contact.reload.name
  end

  test "update on validation failure returns 422 with the frame" do
    patch customer_contact_path(@contact),
          params: { customer_contact: { name: "", email: "bad" } }

    assert_response :unprocessable_content
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(@contact)}"
    assert_equal "GOOD Accounting", @contact.reload.name
  end

  test "destroy removes the row via turbo-stream" do
    contact_id = @contact.id
    delete customer_contact_path(@contact), headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.media_type, "turbo-stream"
    assert_select %(turbo-stream[action="remove"][target="customer_contact_#{contact_id}"])
    assert_nil CustomerContact.find_by(id: contact_id)
  end

  # --- permission + cross-team scoping -------------------------------------

  test "user without customers.edit cannot create" do
    sign_in_as users(:bob)  # bob has no group, so no permissions
    post customer_customer_contacts_path(@customer),
         params: { customer_contact: { name: "X", email: "x@example.com" } }
    assert_response :redirect
  end

  test "user without customers.edit cannot update" do
    sign_in_as users(:bob)
    patch customer_contact_path(@contact),
          params: { customer_contact: { name: "Hijacked" } }
    assert_response :redirect
    assert_equal "GOOD Accounting", @contact.reload.name
  end

  test "user without customers.edit cannot destroy" do
    sign_in_as users(:bob)
    assert_no_difference -> { CustomerContact.count } do
      delete customer_contact_path(@contact)
    end
    assert_response :redirect
  end

  test "cross-team access returns 404 on a contact from a team the user isn't in" do
    GroupMembership.create!(group: groups(:sales), user: users(:bob))
    other_team = Team.create!(name: "Isolated")
    other_customer = Customer.create!(
      matchcode: "ISO", name: "Iso Co",
      vat_id: "EU131313131",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: other_team
    )
    other_contact = other_customer.customer_contacts.create!(name: "X", email: "x@example.com")

    sign_in_as users(:bob)  # bob is in default + acme, not Isolated
    get edit_customer_contact_path(other_contact)
    # bob has customers.edit (via sales group), so the permission check passes,
    # but the scoped lookup raises RecordNotFound which Rails maps to 404.
    assert_response :not_found
  end

  test "create rejects forged project_id from a team the user can't see" do
    # Put bob in the Sales group (customers.view + customers.edit, no bypass)
    # so he stays restricted to default+acme teams.
    GroupMembership.create!(group: groups(:sales), user: users(:bob))

    other_team = Team.create!(name: "Pwn")
    foreign_project = Project.create!(
      matchcode: "PWNPRJ", description: "", bill_to_customer: nil, team: other_team
    )

    sign_in_as users(:bob)
    post customer_customer_contacts_path(@customer),
         params: { customer_contact: { name: "C", email: "c@example.com", project_ids: [ foreign_project.id ] } }

    new_contact = @customer.customer_contacts.find_by(email: "c@example.com")
    assert_not_nil new_contact, "expected the contact to be saved without the forged project"
    assert_empty new_contact.projects, "expected no projects; got #{new_contact.projects.inspect}"
  end
end
