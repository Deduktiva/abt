require "application_system_test_case"

# Locks in the Turbo Frame contract for the contacts table on the customer
# show page (see plan §5 and §10). The contract:
#   - per-row frame `dom_id(contact)` for inline view/edit
#   - singleton frame `new_customer_contact` for the add form
#   - new rows append to `#customer_contacts_tbody` via turbo-stream
#   - validation failure re-renders the form inside its own frame (422)
class CustomerContactsTest < ApplicationSystemTestCase
  setup do
    @customer = customers(:good_eu)
    @accounting = customer_contacts(:good_eu_accounting)
    @project_lead = customer_contacts(:good_eu_project_one_lead)
  end

  test "add row appends to the table and resets the add-link frame" do
    visit customer_path(@customer)
    assert_selector "#new_customer_contact a", text: "+ Add contact"

    click_link "+ Add contact"
    assert_selector "#new_customer_contact input[name='customer_contact[name]']"

    within("#new_customer_contact") do
      fill_in "customer_contact[name]", with: "New Person"
      fill_in "customer_contact[email]", with: "new@example.com"
      check "customer_contact[receives_invoice_emails]"
      click_button "Add"
    end

    # Row appears, add-link resets, no page navigation.
    new_contact = @customer.customer_contacts.find_by(email: "new@example.com")
    assert_selector "##{ActionView::RecordIdentifier.dom_id(new_contact)}", text: "New Person"
    assert_selector "#new_customer_contact a", text: "+ Add contact"
    assert_current_path customer_path(@customer)
  end

  test "add row validation failure keeps the form inside the frame with errors" do
    visit customer_path(@customer)
    click_link "+ Add contact"

    within("#new_customer_contact") do
      # Both empty — fills happen before submit. Browser's "required" would
      # block on real interaction, so we explicitly post empties via JS form
      # submission would be brittle. Instead: use an invalid email format so
      # client-side validation passes but server validation rejects.
      fill_in "customer_contact[name]", with: "Edge Case"
      fill_in "customer_contact[email]", with: "not-an-email-format"
      click_button "Add"
    end

    # Frame still shows the form (not the add link).
    assert_selector "#new_customer_contact input[name='customer_contact[email]']"
    assert_no_selector "#new_customer_contact a", text: "+ Add contact"
    assert_equal 0, @customer.customer_contacts.where(email: "not-an-email-format").count
  end

  test "edit row swaps to inputs inline and saves back to read-only" do
    visit customer_path(@customer)

    row = "##{ActionView::RecordIdentifier.dom_id(@accounting)}"
    other_row = "##{ActionView::RecordIdentifier.dom_id(@project_lead)}"

    within(row) { click_link "Edit" }
    assert_selector "#{row} input[name='customer_contact[name]']"
    # Other rows stay in view mode.
    assert_no_selector "#{other_row} input[name='customer_contact[name]']"

    within(row) do
      fill_in "customer_contact[name]", with: "Accounting (Updated)"
      click_button "Save"
    end

    assert_selector "#{row}", text: "Accounting (Updated)"
    assert_no_selector "#{row} input[name='customer_contact[name]']"
    assert_equal "Accounting (Updated)", @accounting.reload.name
  end

  test "cancel edit reverts the row without saving" do
    visit customer_path(@customer)
    row = "##{ActionView::RecordIdentifier.dom_id(@accounting)}"

    within(row) { click_link "Edit" }
    within(row) do
      fill_in "customer_contact[name]", with: "Should Not Persist"
      click_link "Cancel"
    end

    # Frame returns to read-only with original value.
    assert_selector "#{row}", text: @accounting.name
    assert_no_selector "#{row} input[name='customer_contact[name]']"
    assert_equal @accounting.name, @accounting.reload.name
  end

  test "delete row removes only that row" do
    visit customer_path(@customer)
    row = "##{ActionView::RecordIdentifier.dom_id(@accounting)}"
    other_row = "##{ActionView::RecordIdentifier.dom_id(@project_lead)}"

    accept_confirm do
      within(row) { click_link "🗑" }
    end

    assert_no_selector row
    assert_selector other_row
    assert_nil CustomerContact.find_by(id: @accounting.id)
  end

  test "empty-state message hides when first contact is added and returns after the last is removed" do
    empty_customer = customers(:no_email_customer)
    visit customer_path(empty_customer)
    assert_selector "#customer_contacts_empty_message"

    click_link "+ Add contact"
    within("#new_customer_contact") do
      fill_in "customer_contact[name]", with: "First Contact"
      fill_in "customer_contact[email]", with: "first@example.com"
      click_button "Add"
    end

    new_contact = empty_customer.customer_contacts.find_by(email: "first@example.com")
    assert_selector "##{ActionView::RecordIdentifier.dom_id(new_contact)}"
    assert_no_selector "#customer_contacts_empty_message"

    accept_confirm do
      within("##{ActionView::RecordIdentifier.dom_id(new_contact)}") { click_link "🗑" }
    end

    assert_no_selector "##{ActionView::RecordIdentifier.dom_id(new_contact)}"
    assert_selector "#customer_contacts_empty_message"
  end

  test "salutation_line persists from the edit form and renders in the row" do
    visit customer_path(@customer)
    row = "##{ActionView::RecordIdentifier.dom_id(@accounting)}"

    within(row) { click_link "Edit" }
    within(row) do
      fill_in "customer_contact[salutation_line]", with: "Hi tester,"
      click_button "Save"
    end

    assert_selector "#{row}", text: "Hi tester,"
    assert_equal "Hi tester,", @accounting.reload.salutation_line
  end

  test "project picker only offers this customer's projects and unassigned projects" do
    visit customer_path(@customer)
    click_link "+ Add contact"

    options = within("#new_customer_contact") do
      find("select[name='customer_contact[project_ids][]']").all("option").map(&:text)
    end

    assert_includes options, projects(:one).matchcode          # belongs to good_eu
    assert_includes options, projects(:reusable_project).matchcode  # bill_to nil
    assert_not_includes options, projects(:two).matchcode      # belongs to good_national
  end
end
