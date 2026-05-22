require "test_helper"

class IssuerCompaniesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @issuer_company = issuer_companies(:one)
  end

  test "should get show" do
    get issuer_company_url
    assert_response :success
    assert_select 'h1', text: 'Issuer Company'
  end

  test "should get edit" do
    get edit_issuer_company_url
    assert_response :success
    assert_select 'h1', text: 'Edit Issuer Company'
    assert_select 'form'
  end

  test "should update issuer_company" do
    patch issuer_company_url, params: {
      issuer_company: {
        short_name: 'Updated Name',
        legal_name: 'Updated Legal Name'
      }
    }
    assert_redirected_to issuer_company_url
    follow_redirect!
    assert_select '.alert', text: /successfully updated/
  end

  test "should handle invalid update" do
    patch issuer_company_url, params: {
      issuer_company: {
        short_name: '',
        legal_name: ''
      }
    }
    assert_response :success
    assert_select '.alert-danger'
    assert_select 'form'
  end

  test "should reject oversized png logo upload" do
    big = Rack::Test::UploadedFile.new(
      StringIO.new('x' * (IssuerCompaniesController::MAX_LOGO_SIZE_BYTES + 1)),
      'image/png',
      original_filename: 'big.png'
    )
    patch issuer_company_url, params: {
      issuer_company: { png_logo_file: big }
    }
    assert_redirected_to edit_issuer_company_url
    follow_redirect!
    assert_select '.alert-danger', text: /too large/
  end

  test "should reject png upload that is not a real png" do
    fake = Rack::Test::UploadedFile.new(
      StringIO.new('<script>alert(1)</script>'),
      'image/png',
      original_filename: 'evil.png'
    )
    patch issuer_company_url, params: {
      issuer_company: { png_logo_file: fake }
    }
    assert_redirected_to edit_issuer_company_url
    follow_redirect!
    assert_select '.alert-danger', text: /not image\/png/
  end

  test "should accept a valid png upload" do
    png_data = "\x89PNG\r\n\x1A\n".b + ("\x00" * 32).b
    valid = Rack::Test::UploadedFile.new(
      StringIO.new(png_data),
      'image/png',
      original_filename: 'logo.png'
    )
    patch issuer_company_url, params: {
      issuer_company: { png_logo_file: valid }
    }
    assert_redirected_to issuer_company_url
    @issuer_company.reload
    assert_equal png_data, @issuer_company.png_logo
  end

  test "png_logo response sets nosniff header" do
    @issuer_company.update!(png_logo: "\x89PNG\r\n\x1A\n".b + "rest".b)
    get png_logo_issuer_company_url
    assert_response :success
    assert_equal 'nosniff', response.headers['X-Content-Type-Options']
  end

  test "should ignore direct mass-assignment of pdf_logo and png_logo" do
    @issuer_company.update!(png_logo: nil, pdf_logo: nil)
    patch issuer_company_url, params: {
      issuer_company: {
        pdf_logo: '<script>alert(1)</script>',
        png_logo: '<script>alert(1)</script>'
      }
    }
    @issuer_company.reload
    assert_nil @issuer_company.pdf_logo
    assert_nil @issuer_company.png_logo
  end

  test "should preserve whitespace in contact lines on show page" do
    # Update the fixture to have explicit whitespace
    @issuer_company.update!(
      document_contact_line1: "www.example.com      hi@example.com",
      document_contact_line2: "voice + xxx xxxxxx"
    )

    get issuer_company_url
    assert_response :success

    # Check that whitespace is preserved in the rendered HTML
    assert_select 'span[style*="white-space: pre-wrap"]' do |elements|
      contact_line1_element = elements.find { |el| el.text.include?("www.example.com      hi@example.com") }
      contact_line2_element = elements.find { |el| el.text.include?("voice + xxx xxxxxx") }

      assert contact_line1_element, "Contact Line 1 with preserved whitespace not found"
      assert contact_line2_element, "Contact Line 2 with preserved whitespace not found"
    end
  end
end
