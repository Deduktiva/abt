require "application_system_test_case"

class AcceptanceUploadTest < ApplicationSystemTestCase
  skip_default_signin! # customer-facing page is unauthenticated

  setup do
    @prev_app_host = Capybara.app_host
    @prev_include_port = Capybara.always_include_port
    Capybara.app_host = "http://#{Settings.customer_portal.host}"
    Capybara.always_include_port = true
  end

  teardown do
    Capybara.app_host = @prev_app_host
    Capybara.always_include_port = @prev_include_port
  end

  test "customer uploads a signed acceptance document" do
    dn = delivery_notes(:published_delivery_note)
    token = dn.issue_acceptance_upload_token!

    visit delivery_acceptance_upload_path(token: token)
    assert_text "Acceptance for Delivery Note"

    attach_file "acceptance_pdf", Rails.root.join("test/fixtures/files/acceptance.pdf")
    click_button "Submit signed acceptance"

    assert_text "Received"
    assert_equal 1, dn.reload.acceptance_submissions.pending.count
  end
end
