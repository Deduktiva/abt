require "test_helper"

class IssuerCompanyTest < ActiveSupport::TestCase
  test "requires short_name" do
    company = IssuerCompany.new(legal_name: "Test Ltd")
    assert_not company.valid?
    assert_includes company.errors[:short_name], "can't be blank"
  end

  test "requires legal_name" do
    company = IssuerCompany.new(short_name: "Test")
    assert_not company.valid?
    assert_includes company.errors[:legal_name], "can't be blank"
  end

  test "document_accent_color accepts hex colors of 3, 4, 6, and 8 hex digits" do
    [ "#abc", "#ABCD", "#aabbcc", "#AABBCCDD" ].each do |color|
      company = IssuerCompany.new(short_name: "X", legal_name: "Y", country_iso2: "NL", document_accent_color: color)
      assert company.valid?, "expected color=#{color} to be valid"
    end
  end

  test "document_accent_color rejects non-hex values" do
    [ "red", "#xyz", "3366cc", "#12" ].each do |color|
      company = IssuerCompany.new(short_name: "X", legal_name: "Y", country_iso2: "NL", document_accent_color: color)
      assert_not company.valid?, "expected color=#{color} to be invalid"
      assert_includes company.errors[:document_accent_color], "must be a hex color like #rrggbb"
    end
  end

  test "document_accent_color is optional" do
    company = IssuerCompany.new(short_name: "X", legal_name: "Y", country_iso2: "NL", document_accent_color: nil)
    assert company.valid?
    company.document_accent_color = ""
    assert company.valid?
  end

  test "reporting_email, document_email_from, document_email_auto_bcc reject malformed addresses" do
    [ :reporting_email, :document_email_from, :document_email_auto_bcc ].each do |field|
      company = issuer_companies(:one)
      company.assign_attributes(field => "not-an-email")
      assert_not company.valid?, "expected #{field}=not-an-email to be invalid"
      assert_includes company.errors[field], "is invalid"
    end
  end

  test "reporting_email is required" do
    company = issuer_companies(:one)
    company.reporting_email = ""
    assert_not company.valid?
    assert_includes company.errors[:reporting_email], "can't be blank"
  end

  test "valid email values are accepted on all three email fields" do
    company = issuer_companies(:one)
    company.assign_attributes(
      reporting_email: "reports@example.com",
      document_email_from: "from@example.com",
      document_email_auto_bcc: "bcc@example.com"
    )
    assert company.valid?
  end

  test "money_decimal_places rejects out-of-range and non-integer values" do
    [ -1, 5, 2.5 ].each do |value|
      company = issuer_companies(:one)
      company.money_decimal_places = value
      assert_not company.valid?, "expected money_decimal_places=#{value} to be invalid"
    end
  end

  test "get_the_issuer! returns the active issuer" do
    assert_equal issuer_companies(:one), IssuerCompany.get_the_issuer!
  end

  test "get_the_issuer! returns nil when no active issuer exists" do
    issuer_companies(:one).update!(active: false)
    assert_nil IssuerCompany.get_the_issuer!
  end

  test "reporting_email backfills from document_email_auto_bcc on existing fixture rows" do
    assert_equal issuer_companies(:one).document_email_auto_bcc, issuer_companies(:one).reporting_email
  end

  test "website_url must be http(s) when present" do
    issuer = issuer_companies(:one)
    issuer.website_url = "javascript:alert(1)"
    assert_not issuer.valid?
    issuer.website_url = "https://example.com"
    assert issuer.valid?
  end

  test "offer_validity_days defaults to 30 and offer_footer is nullable" do
    company = IssuerCompany.new(short_name: "X", legal_name: "Y")
    assert_equal 30, company.offer_validity_days
    assert_nil company.offer_footer
  end
end
