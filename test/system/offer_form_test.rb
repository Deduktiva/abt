require "application_system_test_case"

class OfferFormTest < ApplicationSystemTestCase
  test "adding a milestone survives submit" do
    visit edit_offer_path(offers(:draft_offer))
    click_on "+ Add Milestone"
    within all("[data-line-index]").last do
      fill_in "Title", with: "Second milestone"
      fill_in "Amount", with: "250"
    end
    click_on "Save"
    assert_text "Offer updated"
    offer = offers(:draft_offer).reload
    assert_equal [ "Concept", "Second milestone" ], offer.draft_version.milestones.map(&:title)
  end

  test "reordering and removing milestones survives submit" do
    version = offers(:draft_offer).draft_version
    version.milestones.create!(position: 2, title: "Middle", amount: 100, trigger: "on_acceptance")
    version.milestones.create!(position: 3, title: "Last", amount: 200, trigger: "on_acceptance")
    visit edit_offer_path(offers(:draft_offer))
    within all("[data-line-index]")[2] do
      click_on "▲"
    end
    within all("[data-line-index]")[2] do
      click_on "🗑"
    end
    click_on "Save"
    assert_text "Offer updated"
    milestones = offers(:draft_offer).reload.draft_version.milestones
    assert_equal [ "Concept", "Last" ], milestones.map(&:title)
    assert_equal [ 1, 2 ], milestones.map(&:position)
  end

  test "milestone description and skip flag are not dropped on submit" do
    visit edit_offer_path(offers(:draft_offer))
    within first("[data-line-index]") do
      fill_in "Description", with: "Detailed scope"
      select "Upon order", from: "Trigger"
    end
    click_on "Save"
    assert_text "Offer updated"
    milestone = offers(:draft_offer).reload.draft_version.milestones.first
    assert_equal "Detailed scope", milestone.description
    assert milestone.skip_delivery_note
  end

  test "send button disabled without milestones" do
    offer = create_draft_offer
    visit offer_path(offer)
    assert_selector "button[disabled]", text: /Send/
  end

  test "accepting without an order document succeeds" do
    offer = offers(:sent_offer)
    visit offer_path(offer)

    click_on "Accept…"
    assert_selector ".accept-order-modal", visible: :visible

    within ".accept-order-modal" do
      fill_in "order_number", with: "PO-NOFILE"
      fill_in "ordered_on", with: Date.new(2026, 7, 1).strftime("%Y-%m-%d")
      click_on "Accept offer"
    end

    assert_text "Offer accepted"
    offer.reload
    assert offer.accepted?
    assert_nil offer.order_attachment_id
  end
  test "applying the milestone rule keeps unsaved form edits" do
    offer = create_draft_offer
    visit edit_offer_path(offer)
    fill_in "Subject", with: "Kept subject"
    fill_in "Target total net", with: "2500"
    click_on "Apply milestone rule"
    assert_text "Milestones scaffolded"
    offer.reload
    assert_equal "Kept subject", offer.draft_version.subject
    assert_equal [ 2500 ], offer.draft_version.milestones.map(&:amount)
  end
end
