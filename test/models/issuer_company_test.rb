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
      company = IssuerCompany.new(short_name: "X", legal_name: "Y", document_accent_color: color)
      assert company.valid?, "expected color=#{color} to be valid"
    end
  end

  test "document_accent_color rejects non-hex values" do
    [ "red", "#xyz", "3366cc", "#12" ].each do |color|
      company = IssuerCompany.new(short_name: "X", legal_name: "Y", document_accent_color: color)
      assert_not company.valid?, "expected color=#{color} to be invalid"
      assert_includes company.errors[:document_accent_color], "must be a hex color like #rrggbb"
    end
  end

  test "document_accent_color is optional" do
    company = IssuerCompany.new(short_name: "X", legal_name: "Y", document_accent_color: nil)
    assert company.valid?
    company.document_accent_color = ""
    assert company.valid?
  end

  test "get_the_issuer! returns the active issuer" do
    assert_equal issuer_companies(:one), IssuerCompany.get_the_issuer!
  end

  test "get_the_issuer! returns nil when no active issuer exists" do
    issuer_companies(:one).update!(active: false)
    assert_nil IssuerCompany.get_the_issuer!
  end

  test "offer_validity_days defaults to 30 and offer_footer is nullable" do
    company = IssuerCompany.new(short_name: "X", legal_name: "Y")
    assert_equal 30, company.offer_validity_days
    assert_nil company.offer_footer
  end
end
