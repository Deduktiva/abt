require "test_helper"

class RichTextFoConverterTest < ActiveSupport::TestCase
  def fo(html)
    RichTextFoConverter.new(html).to_fo_fragment
  end

  test "blank input produces empty fragment" do
    assert_equal "", fo("")
  end

  test "nil input produces empty fragment" do
    assert_equal "", fo(nil)
  end

  test "div becomes fo:block with escaped text" do
    assert_equal %(<fo:block>a &amp; b</fo:block>), fo("<div>a &amp; b</div>")
  end

  test "br becomes a U+2028 line separator" do
    assert_includes fo("<div>a<br>b</div>"), "a b"
  end

  test "nested inline formatting nests fo:inline elements" do
    out = fo("<div><strong><em>x</em></strong></div>")
    assert_includes out, %(<fo:inline font-weight="bold">)
    assert_includes out, %(<fo:inline font-style="italic">x</fo:inline>)
  end

  test "bold and italic become fo:inline" do
    assert_includes fo("<div><strong>x</strong></div>"), %(<fo:inline font-weight="bold">x</fo:inline>)
    assert_includes fo("<div><em>y</em></div>"), %(<fo:inline font-style="italic">y</fo:inline>)
  end

  test "h1 becomes a styled fo:block" do
    out = fo("<h1>Title</h1>")
    assert_includes out, %(font-weight="bold")
    assert_includes out, "Title"
  end

  test "bullet list emits fo:list-block with bullet labels" do
    out = fo("<ul><li>one</li><li>two</li></ul>")
    assert_includes out, "<fo:list-block"
    assert_includes out, "•"
    assert_includes out, "one"
    assert_includes out, "two"
  end

  test "numbered list labels increment" do
    out = fo("<ol><li>a</li><li>b</li></ol>")
    assert_includes out, "1."
    assert_includes out, "2."
  end

  test "unknown inline tag is unwrapped but text kept" do
    assert_equal %(<fo:block>hi</fo:block>), fo("<div><span>hi</span></div>")
  end

  test "child-of-li nested list renders as an indented sub-list" do
    out = fo("<ul><li>a<ul><li>sub</li></ul></li></ul>")
    assert_equal 2, out.scan("<fo:list-block").size
    assert_includes out, "a"
    assert_includes out, "sub"
  end

  test "sibling-nested list attaches as the preceding item's sub-list" do
    out = fo("<ul><li>first</li><ul><li>sub</li></ul></ul>")
    assert_equal 2, out.scan("<fo:list-block").size
    assert_includes out, "first"
    assert_includes out, "sub"
  end

  test "nested numbered list nests instead of flattening into a top-level item" do
    out = fo("<ol><li>list item</li><li>second<ol><li>sub</li></ol></li></ol>")
    assert_equal 2, out.scan("<fo:list-block").size
    assert_includes out, "sub"
    # A flattened sub-item would produce a third top-level "3." label.
    refute_includes out, "<fo:block>3.</fo:block>"
  end
end
