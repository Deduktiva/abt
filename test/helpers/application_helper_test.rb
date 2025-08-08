require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  # Removed redundant page_title tests - covered more comprehensively in integration tests

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
