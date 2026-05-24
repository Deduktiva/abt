require 'application_system_test_case'

class ThemeDetectionTest < ApplicationSystemTestCase
  test "html element has data-bs-theme attribute set after page load" do
    visit root_path

    attr = page.evaluate_script("document.documentElement.getAttribute('data-bs-theme')")
    assert_includes %w[light dark], attr, "expected data-bs-theme to be 'light' or 'dark', got #{attr.inspect}"
  end
end
