require "application_system_test_case"

# End-to-end happy path for the offer feature: create → add milestone →
# send → accept → convert. Drives the same UI an admin uses, including the
# state-transition buttons on the show page and the milestone form on edit.
class OffersWorkflowTest < ApplicationSystemTestCase
  test "create draft, add milestone, send, accept, convert (invoice only)" do
    visit "/offers"
    assert_text "Listing offers"
    click_link "+ New"

    fill_in "offer[matchcode]", with: "happy-path"

    # Customer + project pickers are searchable-dropdowns (same widget the
    # invoice and delivery-note forms use). Drive them by opening the
    # button and clicking the loaded option.
    within(".customer-dropdown") do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector ".searchable-option", wait: 10
      find(".searchable-option", text: customers(:good_eu).name).click
    end
    within(".project-dropdown") do
      find('[data-searchable-dropdown-target="select"]').click
      assert_selector ".searchable-option", wait: 10
      find(".searchable-option", text: projects(:one).matchcode).click
    end

    click_button "Save"

    # Lands on edit page for the new draft.
    assert_text "Edit offer Draft"
    offer = Offer.find_by!(matchcode: "happy-path")
    assert_equal projects(:one).id, offer.project_id
    within(all("form[action$='/milestones']").last) do
      fill_in "offer_milestone[title]", with: "Phase 1"
      select "On order",                from: "offer_milestone[trigger]"
      fill_in "offer_milestone[net_amount]", with: "100"
      click_button "Add"
    end

    # Edit page reload should show the saved row plus a fresh add-row.
    assert_text "Milestone added."
    assert_field "offer_milestone[title]", with: "Phase 1"

    # Jump to the show page and send the offer.
    visit offer_path(Offer.find_by!(matchcode: "happy-path"))
    assert_text "happy-path"

    accept_confirm { click_button "Send" }
    assert_text "Offer v1 sent."
    assert_selector ".badge", text: "Sent"

    # Accept the offer.
    accept_confirm { click_button "Accept" }
    assert_text "Offer accepted."
    assert_selector ".badge", text: "Accepted"

    # Convert (invoice only) — lands on the new invoice draft.
    click_button "Convert (invoice only)"
    assert_text "Invoice draft created from milestone."
    assert_current_path(%r{/invoices/\d+})
  end

  test "milestone description + skip_delivery_note round-trip from the add form" do
    # Regression for: the saved-row delete used to be a button_to whose
    # nested <form> would terminate the outer milestone form, orphaning the
    # description + skip_delivery_note inputs underneath it. Driving the add
    # path here proves the inputs sit inside the form and reach the server.
    offer = Offer.create_with_initial_version!(
      matchcode: "round-trip",
      customer: customers(:good_eu),
      project: projects(:one),
      state: "draft"
    )
    visit edit_offer_path(offer)

    within(all("form[action$='/milestones']").last) do
      fill_in "offer_milestone[title]",       with: "All-fields"
      select  "On acceptance",                from: "offer_milestone[trigger]"
      fill_in "offer_milestone[net_amount]",  with: "200"
      fill_in "offer_milestone[description]", with: "Detailed scope here"
      check   "offer_milestone[skip_delivery_note]"
      click_button "Add"
    end

    assert_text "Milestone added."
    milestone = offer.current_version.offer_milestones.find_by!(title: "All-fields")
    assert_equal "Detailed scope here", milestone.description
    assert milestone.skip_delivery_note
  end

  test "send button refuses when there are no milestones yet" do
    offer = Offer.create_with_initial_version!(
      matchcode: "no-milestones",
      customer: customers(:good_eu),
      project: projects(:one),
      state: "draft"
    )
    visit offer_path(offer)
    # The Send button is rendered disabled when the current draft has no
    # milestones; disabled: :all so Capybara doesn't filter it out.
    send_button = find_button("Send", disabled: :all)
    assert send_button.disabled?, "Send button should be disabled with no milestones"
  end
end
