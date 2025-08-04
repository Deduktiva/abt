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
