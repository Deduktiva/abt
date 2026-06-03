require "test_helper"
class PublicAcceptancesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  setup { host! Settings.customer_portal.host }

  def open_note
    dn = delivery_notes(:published_delivery_note)
    @token = dn.issue_acceptance_upload_token!
    dn
  end

  def pdf
    fixture_file_upload("acceptance.pdf", "application/pdf")
  end

  test "GET with a valid token shows the upload form" do
    open_note
    get delivery_acceptance_upload_url(token: @token, host: Settings.customer_portal.host)
    assert_response :success
    assert_select "form[action=?]", delivery_acceptance_upload_submit_path(token: @token)
    assert_select "small", text: /maximum 25 MB/i
  end

  test "renders the upload page in the visitor's Accept-Language locale" do
    dn = delivery_notes(:published_delivery_note)
    token = dn.issue_acceptance_upload_token!
    get delivery_acceptance_upload_url(token: token, host: Settings.customer_portal.host),
        headers: { "Accept-Language" => "de-DE,de;q=0.9,en;q=0.8" }
    assert_select "h1", text: /Abnahme/
  end

  test "GET with an unknown token shows the closed page" do
    get delivery_acceptance_upload_url(token: "nope", host: Settings.customer_portal.host)
    assert_response :success
    assert_select "form", count: 0
  end

  test "GET on an already-accepted note shows closed" do
    dn = open_note
    AcceptanceSubmission.submit!(delivery_note: dn, uploaded_file: pdf, ip: "1.1.1.1").accept!(by: users(:alice))
    get delivery_acceptance_upload_url(token: @token, host: Settings.customer_portal.host)
    assert_select "form", count: 0
  end

  test "POST a PDF creates a pending submission and notifies the issuer" do
    dn = open_note
    assert_difference -> { dn.acceptance_submissions.pending.count }, 1 do
      assert_enqueued_emails 1 do
        post delivery_acceptance_upload_submit_url(token: @token, host: Settings.customer_portal.host), params: { acceptance_pdf: pdf }
      end
    end
    assert_response :success
    assert_select "h1", text: /received/i
  end

  test "POST a non-PDF re-renders the form with an error" do
    open_note
    bad = fixture_file_upload("notpdf.html", "application/pdf")
    post delivery_acceptance_upload_submit_url(token: @token, host: Settings.customer_portal.host), params: { acceptance_pdf: bad }
    assert_response :unprocessable_content
    assert_select ".alert", text: /PDF/i
  end

  test "the upload route is unreachable on the app host" do
    host! "app.example.com"
    get "/delivery-acceptance/sometoken"
    assert_response :not_found
  end
end
