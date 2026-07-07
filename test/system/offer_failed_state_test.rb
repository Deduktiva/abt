require "application_system_test_case"

class OfferFailedStateTest < ApplicationSystemTestCase
  test "marking an ordered offer failed and restoring it" do
    offer = offers(:sent_offer)
    offer.accept!(order_number: "PO", ordered_on: Date.current)

    visit offer_path(offer)
    accept_confirm { click_on "Mark failed" }
    assert_selector ".badge.bg-secondary", text: "Failed"

    accept_confirm { click_on "Restore to Ordered" }
    assert_text "Offer restored to ordered"
    assert offer.reload.accepted?
  end
end
