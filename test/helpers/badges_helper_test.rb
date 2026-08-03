require "test_helper"

class BadgesHelperTest < ActionView::TestCase
  # No view-level test asserts a badge colour any more, so this is the only
  # thing standing between a typo here and every Overdue badge turning yellow.
  test "badge_tag renders each level with its Bootstrap background class" do
    expected = {
      neutral: "bg-secondary", info: "bg-info", active: "bg-primary",
      warning: "bg-warning", danger: "bg-danger", success: "bg-success"
    }
    expected.each do |level, klass|
      assert_dom_equal %(<span class="badge #{klass}">x</span>), badge_tag(level, "x")
    end
    assert_equal expected.keys.sort, BadgesHelper::BADGE_LEVELS.keys.sort
  end

  test "badge_tag appends caller-supplied classes after the level class" do
    assert_dom_equal '<span class="badge bg-info ms-1">This is you</span>', badge_tag(:info, "This is you", klass: "ms-1")
  end

  test "badge_tag raises on an unknown level instead of rendering an unstyled pill" do
    assert_raises(KeyError) { badge_tag(:mauve, "Whatever") }
  end

  test "badge_tag renders non-String content" do
    assert_dom_equal '<span class="badge bg-secondary">3</span>', badge_tag(:neutral, 3)
  end

  test "status_badge_tag unpacks a model's level and text" do
    assert_dom_equal '<span class="badge bg-danger">Overdue, 3d</span>',
                     status_badge_tag({ level: :danger, text: "Overdue, 3d" })
  end

  test "status_badge_tag renders nothing when the model reports no badge" do
    assert_nil status_badge_tag(nil)
  end
end
