require "test_helper"

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @attachment = attachments(:invoice_pdf)
  end

  test "show serves a PDF inline with nosniff header" do
    get attachment_url(@attachment)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/inline/, response.headers["Content-Disposition"].to_s)
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
  end

  test "show forces attachment disposition and octet-stream for non-safelisted content types" do
    @attachment.update_column(:content_type, "text/html")
    get attachment_url(@attachment)
    assert_response :success
    assert_equal "application/octet-stream", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"].to_s)
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
  end

  test "show denies an attachment with no parent invoice or delivery note" do
    orphan = Attachment.create!(
      title: "orphan",
      filename: "orphan.pdf",
      content_type: "application/pdf",
      data: "orphan"
    )
    get attachment_url(orphan)
    assert_redirected_to root_path
  end

  test "show denies an attachment whose parent invoice belongs to another team" do
    other_team = Team.create!(name: "OutsideTeam")
    outside_customer = Customer.create!(
      matchcode: "OUT",
      name: "Outside Co.",
      vat_id: "EU141414141",

      country_iso2: "NL",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: other_team
    )
    outside_attachment = Attachment.create!(
      title: "secret",
      filename: "secret.pdf",
      content_type: "application/pdf",
      data: "secret"
    )
    Invoice.create!(customer: outside_customer, project: projects(:reusable_project), attachment: outside_attachment)

    bob = users(:bob)
    bob.groups << groups(:sales)  # invoices.view but not bypass
    sign_in_as(bob)

    get attachment_url(outside_attachment)
    assert_redirected_to root_path
  end

  test "show serves an offer-version PDF to alice" do
    offer = offers(:sent_offer)
    version = offer.versions.find_by(version_number: 1)
    attachment = Attachment.create!(
      title: "Offer PDF",
      filename: "offer.pdf",
      content_type: "application/pdf",
      data: "%PDF-fake"
    )
    version.update!(attachment: attachment)

    get attachment_url(attachment)
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "show denies an offer-version PDF whose customer belongs to another team" do
    other_team = Team.create!(name: "OutsideOffersTeam")
    outside_customer = Customer.create!(
      matchcode: "OUTOFF",
      name: "Outside Offers Co.",
      vat_id: "EU161616161",
      country_iso2: "NL",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: other_team
    )
    outside_offer = Offer.create!(customer: outside_customer, project: projects(:reusable_project))
    outside_attachment = Attachment.create!(
      title: "secret offer",
      filename: "secret.pdf",
      content_type: "application/pdf",
      data: "secret"
    )
    outside_offer.draft_version.update!(attachment: outside_attachment)

    offers_viewer = Group.create!(name: "OffersViewerOnly")
    GroupPermission.create!(group: offers_viewer, permission: "offers.view")
    bob = users(:bob)
    bob.groups << offers_viewer # offers.view, but bob's teams don't include OutsideOffersTeam
    sign_in_as(bob)

    get attachment_url(outside_attachment)
    assert_redirected_to root_path
  end
end
