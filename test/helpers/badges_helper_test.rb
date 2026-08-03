require "test_helper"

class BadgesHelperTest < ActionView::TestCase
  test "badge_tag maps a level to its Bootstrap background class" do
    assert_dom_equal '<span class="badge bg-secondary">Inactive</span>', badge_tag(:neutral, "Inactive")
  end

  test "badge_tag appends caller-supplied classes after the level class" do
    assert_dom_equal '<span class="badge bg-info ms-1">This is you</span>', badge_tag(:info, "This is you", css: "ms-1")
  end

  test "badge_tag raises on an unknown level instead of rendering an unstyled pill" do
    assert_raises(KeyError) { badge_tag(:mauve, "Whatever") }
  end

  test "badge_tag renders non-String content" do
    assert_dom_equal '<span class="badge bg-secondary">3</span>', badge_tag(:neutral, 3)
  end
end
