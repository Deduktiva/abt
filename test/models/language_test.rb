require "test_helper"

class LanguageTest < ActiveSupport::TestCase
  test "requires iso_code" do
    language = Language.new(title: "Spanish")
    assert_not language.valid?
    assert_includes language.errors[:iso_code], "can't be blank"
  end

  test "requires title" do
    language = Language.new(iso_code: "es")
    assert_not language.valid?
    assert_includes language.errors[:title], "can't be blank"
  end

  test "iso_code must be exactly 2 characters" do
    too_short = Language.new(iso_code: "e", title: "Bad")
    assert_not too_short.valid?
    assert_includes too_short.errors[:iso_code], "is the wrong length (should be 2 characters)"

    too_long = Language.new(iso_code: "eng", title: "Bad")
    assert_not too_long.valid?
    assert_includes too_long.errors[:iso_code], "is the wrong length (should be 2 characters)"
  end

  test "iso_code must be unique" do
    duplicate = Language.new(iso_code: "en", title: "English Again")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:iso_code], "has already been taken"
  end

  test "destroy is blocked when customers reference the language" do
    language = languages(:english)
    assert_not language.destroy
    assert_includes language.errors[:base].join, "Cannot delete record because dependent customers exist"
  end

  test "destroy succeeds when no customers reference the language" do
    language = Language.create!(iso_code: "es", title: "Spanish")
    assert language.destroy
  end
end
