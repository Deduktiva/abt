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
end
