require "test_helper"

class BusinessesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @business = businesses(:one)
  end

  test "should get show" do
    get business_url
    assert_response :success
    assert_select ".breadcrumb-item.active", text: "Business"
  end

  test "should get edit" do
    get edit_business_url
    assert_response :success
    assert_select ".breadcrumb-item.active", text: "Edit"
    assert_select "form"
  end

  test "should update business" do
    patch business_url, params: {
      business: {
        short_name: "Updated Name",
        legal_name: "Updated Legal Name"
      }
    }
    assert_redirected_to business_url
    follow_redirect!
    assert_select ".alert", text: /successfully updated/
  end

  test "should handle invalid update" do
    patch business_url, params: {
      business: {
        short_name: "",
        legal_name: ""
      }
    }
    assert_response :unprocessable_content
    assert_select ".alert-danger"
    assert_select "form"
  end

  test "should reject oversized png logo upload" do
    big = Rack::Test::UploadedFile.new(
      StringIO.new("x" * (BusinessesController::MAX_LOGO_SIZE_BYTES + 1)),
      "image/png",
      original_filename: "big.png"
    )
    patch business_url, params: {
      business: { png_logo_file: big }
    }
    assert_redirected_to edit_business_url
    follow_redirect!
    assert_select ".alert-danger", text: /too large/
  end

  test "should reject png upload that is not a real png" do
    fake = Rack::Test::UploadedFile.new(
      StringIO.new("<script>alert(1)</script>"),
      "image/png",
      original_filename: "evil.png"
    )
    patch business_url, params: {
      business: { png_logo_file: fake }
    }
    assert_redirected_to edit_business_url
    follow_redirect!
    assert_select ".alert-danger", text: /not image\/png/
  end

  test "should accept a valid png upload" do
    png_data = "\x89PNG\r\n\x1A\n".b + ("\x00" * 32).b
    valid = Rack::Test::UploadedFile.new(
      StringIO.new(png_data),
      "image/png",
      original_filename: "logo.png"
    )
    patch business_url, params: {
      business: { png_logo_file: valid }
    }
    assert_redirected_to business_url
    @business.reload
    assert_equal png_data, @business.png_logo
  end

  test "png_logo response sets nosniff header" do
    @business.update!(png_logo: "\x89PNG\r\n\x1A\n".b + "rest".b)
    get png_logo_business_url
    assert_response :success
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
  end

  test "should ignore direct mass-assignment of pdf_logo and png_logo" do
    @business.update!(png_logo: nil, pdf_logo: nil)
    patch business_url, params: {
      business: {
        pdf_logo: "<script>alert(1)</script>",
        png_logo: "<script>alert(1)</script>"
      }
    }
    @business.reload
    assert_nil @business.pdf_logo
    assert_nil @business.png_logo
  end

  test "update permits vat_id_recheck_days and persists the new value" do
    patch business_url, params: {
      business: { vat_id_recheck_days: 30 }
    }
    assert_redirected_to business_url
    assert_equal 30, @business.reload.vat_id_recheck_days
  end

  test "update permits money_decimal_places and persists the new value" do
    patch business_url, params: {
      business: { money_decimal_places: 3 }
    }
    assert_redirected_to business_url
    assert_equal 3, @business.reload.money_decimal_places
  end

  test "update permits reporting_email and persists the new value" do
    patch business_url, params: {
      business: { reporting_email: "reports@example.com" }
    }
    assert_redirected_to business_url
    assert_equal "reports@example.com", @business.reload.reporting_email
  end

  test "update rejects vat_id_recheck_days of zero" do
    original = @business.vat_id_recheck_days
    patch business_url, params: {
      business: { vat_id_recheck_days: 0 }
    }
    assert_response :unprocessable_content
    assert_select ".alert-danger"
    assert_equal original, @business.reload.vat_id_recheck_days
  end

  test "offer settings round-trip" do
    patch business_url, params: {
      business: { offer_validity_days: 45, offer_footer: "Offer footer" }
    }
    assert_redirected_to business_url
    @business.reload
    assert_equal 45, @business.offer_validity_days
    assert_equal "Offer footer", @business.offer_footer
  end

  test "should preserve whitespace in contact lines on show page" do
    # Update the fixture to have explicit whitespace
    @business.update!(
      document_contact_line1: "www.example.com      hi@example.com",
      document_contact_line2: "voice + xxx xxxxxx"
    )

    get business_url
    assert_response :success

    # Check that whitespace is preserved in the rendered HTML
    assert_select "span.text-pre-wrap" do |elements|
      contact_line1_element = elements.find { |el| el.text.include?("www.example.com      hi@example.com") }
      contact_line2_element = elements.find { |el| el.text.include?("voice + xxx xxxxxx") }

      assert contact_line1_element, "Contact Line 1 with preserved whitespace not found"
      assert contact_line2_element, "Contact Line 2 with preserved whitespace not found"
    end
  end
end
