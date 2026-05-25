require "test_helper"

class OffersControllerTest < ActionDispatch::IntegrationTest
  def create_offer(**overrides)
    Offer.create_with_initial_version!({
      matchcode: "ctrl-test-#{SecureRandom.hex(3)}",
      customer: customers(:good_eu),
      project: projects(:one),
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
        offer: { matchcode: "via-controller", customer_id: customers(:good_eu).id, project_id: projects(:one).id }
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

  test "POST /milestones/:id/convert builds an invoice and redirects" do
    offer = create_offer(project: projects(:one))
    milestone = offer.current_version.offer_milestones.create!(
      title: "Phase 1", trigger: "on_order", net_amount: 100
    )
    offer.send_current_version!
    offer.reload
    offer.accept!
    offer.reload
    accepted_ms = offer.accepted_version.offer_milestones.find(milestone.id)

    assert_difference -> { Invoice.count } => 1 do
      post convert_offer_milestone_url(offer, accepted_ms), params: { skip_delivery_note: true }
    end
    assert_response :redirect
    assert accepted_ms.reload.converted?
  end

  test "POST /milestones/:id/reopen clears conversion links" do
    offer = create_offer(project: projects(:one))
    milestone = offer.current_version.offer_milestones.create!(
      title: "Phase 1", trigger: "on_order", net_amount: 100
    )
    offer.send_current_version!
    offer.reload
    offer.accept!
    offer.reload
    accepted_ms = offer.accepted_version.offer_milestones.find(milestone.id)
    accepted_ms.convert!(skip_delivery_note: true)

    post reopen_offer_milestone_url(offer, accepted_ms)
    assert_response :redirect
    accepted_ms.reload
    assert_nil accepted_ms.invoice_id
  end

  test "POST /milestones/scaffold applies the customer rule below threshold" do
    customers(:good_eu).update!(
      offer_milestone_split_threshold: 10_000,
      offer_milestone_split_first_ratio: 0.5
    )
    offer = create_offer
    assert_difference -> { OfferMilestone.count } => 1 do
      post scaffold_offer_milestones_url(offer), params: { total_amount: 5_000 }
    end
    assert_redirected_to edit_offer_url(offer)
    assert_equal "Final delivery", offer.current_version.offer_milestones.first.title
  end

  test "POST /milestones/scaffold splits when above threshold" do
    customers(:good_eu).update!(
      offer_milestone_split_threshold: 10_000,
      offer_milestone_split_first_ratio: 0.5
    )
    offer = create_offer
    assert_difference -> { OfferMilestone.count } => 2 do
      post scaffold_offer_milestones_url(offer), params: { total_amount: 15_000 }
    end
    titles = offer.current_version.offer_milestones.order(:position).pluck(:title)
    assert_equal [ "Order entry", "Final delivery" ], titles
  end

  test "POST /milestones/scaffold refuses when milestones already exist" do
    customers(:good_eu).update!(
      offer_milestone_split_threshold: 10_000,
      offer_milestone_split_first_ratio: 0.5
    )
    offer = create_offer
    offer.current_version.offer_milestones.create!(title: "Manual", trigger: "on_order", net_amount: 1)

    assert_no_difference -> { OfferMilestone.count } do
      post scaffold_offer_milestones_url(offer), params: { total_amount: 15_000 }
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
