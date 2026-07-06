require "test_helper"

class OffersControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "index lists offers with state filter" do
    get offers_url
    assert_response :success
    get offers_url(state: "sent", year: "all")
    assert_response :success
    assert_select "td", text: offers(:sent_offer).document_number
  end

  test "index denied without offers.view" do
    sign_in_as users(:bob)
    get offers_url
    assert_redirected_to root_path
  end

  test "create redirects to edit with starter milestone flash" do
    assert_difference("Offer.count") do
      post offers_url, params: { offer: { customer_id: customers(:good_eu).id,
                                          project_id: projects(:one).id } }
    end
    assert_redirected_to edit_offer_url(Offer.order(:id).last)
  end

  test "update edits offer and draft version fields" do
    offer = offers(:draft_offer)
    patch offer_url(offer), params: { offer: {
      internal_reference: "internal-x",
      draft_version_attributes: { id: offer.draft_version.id, subject: "New subject" }
    } }
    assert_redirected_to offer_url(offer)
    assert_equal "New subject", offer.reload.draft_version.subject
  end

  test "destroy only in draft" do
    assert_difference("Offer.count", -1) { delete offer_url(offers(:draft_offer)) }
    assert_no_difference("Offer.count") { delete offer_url(offers(:sent_offer)) }
    assert_redirected_to offer_url(offers(:sent_offer))
  end

  test "send_offer transitions to sent" do
    offer = create_offer_with_milestone
    post send_offer_offer_url(offer)
    assert_redirected_to offer_url(offer)
    assert offer.reload.sent?
  end

  test "send_offer failure path alerts from sender log" do
    offer = create_draft_offer
    post send_offer_offer_url(offer)
    assert_redirected_to offer_url(offer)
    assert_match(/milestone/i, flash[:alert])
    assert offer.reload.draft?
  end

  test "preview redirects with alert for a draft with no milestones" do
    offer = create_draft_offer
    get preview_offer_url(offer)
    assert_redirected_to offer_url(offer)
    assert_match(/milestone/i, flash[:alert])
  end

  test "accept collects order data and order pdf" do
    offer = offers(:sent_offer)
    pdf = fixture_file_upload("acceptance.pdf", "application/pdf")
    post accept_offer_url(offer), params: { order_number: "PO-1", ordered_on: "2026-07-01", order_pdf: pdf }
    assert_redirected_to offer_url(offer)
    offer.reload
    assert offer.accepted?
    assert offer.order_attachment.present?
  end

  test "convert_milestone requires offers.convert and links documents" do
    offer = offers(:sent_offer)
    offer.accept!(order_number: "PO", ordered_on: Date.current)
    milestone = offer_milestones(:sent_ms_two)
    assert_difference([ "Invoice.count", "DeliveryNote.count" ]) do
      post convert_milestone_offer_url(offer, milestone_id: milestone.id)
    end
    milestone.reload
    assert milestone.converted?
    assert_equal "Milestone converted to #{milestone.invoice.display_name} and #{milestone.delivery_note.display_name}.",
                 flash[:notice]
  end

  test "deleting a converted invoice redirects with an alert and keeps it" do
    offer = offers(:sent_offer)
    offer.accept!(order_number: "PO", ordered_on: Date.current)
    milestone = offer_milestones(:sent_ms_two)
    post convert_milestone_offer_url(offer, milestone_id: milestone.id)
    invoice = milestone.reload.invoice
    assert_no_difference("Invoice.count") do
      delete invoice_url(invoice)
    end
    assert_redirected_to invoice_url(invoice)
    assert_match(/converted from/, flash[:alert])
  end

  test "convert_milestone flash names only the invoice when the delivery note is skipped" do
    offer = offers(:sent_offer)
    offer.accept!(order_number: "PO", ordered_on: Date.current)
    milestone = offer_milestones(:sent_ms_one)
    post convert_milestone_offer_url(offer, milestone_id: milestone.id)
    assert_equal "Milestone converted to #{milestone.reload.invoice.display_name}.", flash[:notice]
  end

  test "convert_milestone redirects with alert when offer isn't accepted" do
    offer = offers(:sent_offer)
    milestone = offer_milestones(:sent_ms_two)
    assert_no_difference([ "Invoice.count", "DeliveryNote.count" ]) do
      post convert_milestone_offer_url(offer, milestone_id: milestone.id)
    end
    assert_redirected_to offer_url(offer)
    assert flash[:alert].present?
    assert_not milestone.reload.converted?
  end

  test "reopen_milestone_link redirects with alert when offer isn't accepted" do
    offer = offers(:sent_offer)
    milestone = offer_milestones(:sent_ms_two)
    post reopen_milestone_link_offer_url(offer, milestone_id: milestone.id)
    assert_redirected_to offer_url(offer)
    assert flash[:alert].present?
  end

  test "convert_milestone denied without offers.convert" do
    offer = offers(:sent_offer)
    offer.accept!(order_number: "PO", ordered_on: Date.current)
    milestone = offer_milestones(:sent_ms_two)

    sales = users(:bob)
    sales.groups << groups(:sales) # customers/invoices only, no offers.* perms
    sign_in_as(sales)

    post convert_milestone_offer_url(offer, milestone_id: milestone.id)
    assert_redirected_to root_path
  end

  test "update_internal_notes works even when accepted" do
    offer = offers(:sent_offer)
    offer.accept!(order_number: "PO", ordered_on: Date.current)
    patch update_internal_notes_offer_url(offer), params: { offer: { internal_notes: "<p>note</p>" } }
    assert_redirected_to offer_url(offer)
    assert_includes offer.reload.internal_notes.body.to_html, "note"
  end

  test "scaffold_milestones saves pending offer edits before scaffolding" do
    offer = create_draft_offer
    post scaffold_milestones_offer_url(offer), params: {
      total: "1000",
      offer: { internal_reference: "edited-ref",
               draft_version_attributes: { id: offer.draft_version.id, subject: "Edited subject" } }
    }
    assert_redirected_to edit_offer_url(offer)
    offer.reload
    assert_equal "edited-ref", offer.internal_reference
    assert_equal "Edited subject", offer.draft_version.subject
    assert_equal [ "Milestone" ], offer.draft_version.milestones.map(&:title)
  end

  test "scaffold refuses when milestones exist" do
    offer = create_offer_with_milestone
    post scaffold_milestones_offer_url(offer), params: { total: "1000" }
    assert_redirected_to edit_offer_url(offer)
    assert_match(/remove/i, flash[:alert])
  end

  test "edit blocked once accepted" do
    offer = offers(:sent_offer)
    offer.accept!(order_number: "PO", ordered_on: Date.current)
    get edit_offer_url(offer)
    assert_redirected_to offer_url(offer)
  end

  # Carry-forward obligation: the OfferMailer branch of the mail_delivery_tracker
  # initializer (config/initializers/mail_delivery_tracker.rb) stamps
  # email_sent_at on successful delivery. Untested since Task 6.
  test "send_email stamps email_sent_at once delivered" do
    ActionMailer::Base.deliveries.clear
    offer = offers(:sent_offer)
    attach_pdf_to(offer.versions.find_by(version_number: 1))

    assert_enqueued_emails 1 do
      post send_email_offer_url(offer)
    end
    assert_redirected_to offer_url(offer)

    perform_enqueued_jobs

    assert_equal 1, ActionMailer::Base.deliveries.size
    offer.reload
    assert_not_nil offer.email_sent_at
  end

  test "send_email refuses when the offer has never been sent" do
    offer = create_draft_offer
    post send_email_offer_url(offer)
    assert_redirected_to offer_url(offer)
    assert_nil offer.reload.email_sent_at
  end

  test "show states the decision on accepted offers" do
    offer = offers(:sent_offer)
    offer.accept!(order_number: "PO", ordered_on: Date.current)
    get offer_url(offer)
    assert_select ".badge.bg-primary", text: "Ordered", minimum: 2
    assert_match offer.accepted_at.to_date.strftime("%d.%m.%Y"), response.body
  end

  test "show states the decision on rejected offers" do
    offer = offers(:sent_offer)
    offer.reject!
    get offer_url(offer)
    assert_select ".badge.bg-secondary", text: "Rejected", minimum: 2
    assert_match offer.rejected_at.to_date.strftime("%d.%m.%Y"), response.body
  end

  test "index marks an urgent delivery date in red" do
    offer = offers(:sent_offer)
    offer.accept!(order_number: "PO", ordered_on: Date.current)
    offer.accepted_version.update!(delivery_date: Date.current + 2)
    get offers_url(year: "all")
    assert_select "td.delivery-urgent"
  end

  test "index leaves a comfortable delivery date uncolored" do
    offer = offers(:sent_offer)
    offer.accept!(order_number: "PO", ordered_on: Date.current)
    offer.accepted_version.update!(delivery_date: Date.current + 30)
    get offers_url(year: "all")
    assert_select "td.delivery-urgent", false
  end

  private

  def attach_pdf_to(version)
    attachment = Attachment.new(title: "Offer PDF", filename: "offer.pdf")
    attachment.set_data("%PDF-fake", "application/pdf")
    attachment.save!
    version.update!(attachment: attachment)
  end
end
