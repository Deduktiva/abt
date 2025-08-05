require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  def setup
    @issuer = IssuerCompany.get_the_issuer!
    @original_short_name = @issuer.short_name
  end

  def teardown
    # Restore original short_name after each test
    @issuer.update!(short_name: @original_short_name) if @issuer
  end

  test "page_title returns ABT with issuer short_name when available" do
    @issuer.update!(short_name: "MyCompany")

    assert_equal "ABT: MyCompany", page_title
  end

  test "page_title returns ABT when issuer short_name is blank" do
    # Temporarily set short_name to blank (but Rails validation might prevent this)
    @issuer.update_column(:short_name, "")

    assert_equal "ABT", page_title
  end

  test "page_title returns ABT when issuer short_name is nil" do
    # Temporarily set short_name to nil
    @issuer.update_column(:short_name, nil)

    assert_equal "ABT", page_title
  end

  test "app_version returns test-version in test environment" do
    assert_equal "test-version", app_version
  end

  test "app_version caches result to avoid repeated calls" do
    # First call should set the instance variable
    first_call = app_version

    # Second call should return cached value
    second_call = app_version

    assert_equal first_call, second_call
    assert_equal "test-version", second_call
  end
end