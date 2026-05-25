require "test_helper"

class OffersControllerTest < ActionDispatch::IntegrationTest
  def create_offer(**overrides)
    Offer.create_with_initial_version!({
      matchcode: "ctrl-test-#{SecureRandom.hex(3)}",
      customer: customers(:good_eu),
      state: "draft"
    }.merge(overrides))
  end

  test "GET /offers renders" do
    create_offer
    get offers_url
    assert_response :success
    assert_select "table"
  end

  test "GET /offers/new renders" do
    get new_offer_url
    assert_response :success
  end

  test "POST /offers creates an offer with v1 draft and redirects to edit" do
    assert_difference -> { Offer.count } => 1, -> { OfferVersion.count } => 1 do
      post offers_url, params: {
        offer: { matchcode: "via-controller", customer_id: customers(:good_eu).id }
      }
    end
    offer = Offer.order(:created_at).last
    assert_redirected_to edit_offer_path(offer)
    assert offer.current_version.state_draft?
  end

  test "GET /offers/:id renders the show page" do
    offer = create_offer
    get offer_url(offer)
    assert_response :success
    assert_select "h1, h2, h3", text: /Draft/
  end

  test "GET /offers/:id/edit renders for drafts" do
    offer = create_offer
    get edit_offer_url(offer)
    assert_response :success
  end

  test "GET /offers/:id/edit redirects when state is not draft" do
    offer = create_offer
    offer.current_version.offer_milestones.create!(title: "M", trigger: "on_order", net_amount: 100)
    offer.send_current_version!  # state becomes sent

    get edit_offer_url(offer)
    assert_redirected_to offer_url(offer)
  end

  test "POST /offers/:id/send freezes the current draft" do
    offer = create_offer
    offer.current_version.offer_milestones.create!(title: "M", trigger: "on_order", net_amount: 100)
    post send_offer_url(offer)
    assert_redirected_to offer_url(offer)
    assert offer.reload.state_sent?
  end

  test "POST /offers/:id/accept marks accepted after a send" do
    offer = create_offer
    offer.current_version.offer_milestones.create!(title: "M", trigger: "on_order", net_amount: 100)
    offer.send_current_version!

    post accept_offer_url(offer)
    assert_redirected_to offer_url(offer)
    assert offer.reload.state_accepted?
  end

  test "POST /offers/:id/reject from sent" do
    offer = create_offer
    offer.current_version.offer_milestones.create!(title: "M", trigger: "on_order", net_amount: 1)
    offer.send_current_version!
    post reject_offer_url(offer)
    assert_redirected_to offer_url(offer)
    assert offer.reload.state_rejected?
  end

  test "POST /offers/:id/reopen from accepted" do
    offer = create_offer
    offer.current_version.offer_milestones.create!(title: "M", trigger: "on_order", net_amount: 1)
    offer.send_current_version!
    offer.accept!

    post reopen_offer_url(offer)
    assert_redirected_to offer_url(offer)
    offer.reload
    assert offer.state_sent?
    assert offer.current_version.state_draft?
  end

  test "DELETE /offers/:id removes draft offers" do
    offer = create_offer
    assert_difference -> { Offer.count } => -1 do
      delete offer_url(offer)
    end
    assert_redirected_to offers_url
  end

  test "DELETE /offers/:id refuses on a sent offer" do
    offer = create_offer
    offer.current_version.offer_milestones.create!(title: "M", trigger: "on_order", net_amount: 1)
    offer.send_current_version!
    assert_no_difference -> { Offer.count } do
      delete offer_url(offer)
    end
    assert_redirected_to offer_url(offer)
  end

  test "POST /offers/:id/milestones adds a milestone to the current draft" do
    offer = create_offer
    assert_difference -> { OfferMilestone.count } => 1 do
      post offer_milestones_url(offer), params: {
        offer_milestone: { title: "Phase 1", trigger: "on_order", net_amount: 250 }
      }
    end
    assert_redirected_to edit_offer_url(offer)
  end

  test "milestone create refused when offer is not editable" do
    offer = create_offer
    offer.current_version.offer_milestones.create!(title: "M", trigger: "on_order", net_amount: 1)
    offer.send_current_version!
    assert_no_difference -> { OfferMilestone.count } do
      post offer_milestones_url(offer), params: {
        offer_milestone: { title: "After-send", trigger: "on_order", net_amount: 1 }
      }
    end
    assert_redirected_to offer_url(offer)
  end
end
