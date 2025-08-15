require "application_system_test_case"

class TextareaAutoResizeTest < ApplicationSystemTestCase
  test "plaintext invoice line textarea auto-resizes on page load" do
    # Use the fixture invoice with license keys
    license_invoice = invoices(:license_invoice)

    visit "/invoices/#{license_invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    # Find the textarea containing the license keys
    license_textarea = find('textarea[name*="[description]"]') do |textarea|
      textarea.value.include?("Primary License:")
    end

    assert license_textarea, "Should find textarea with license key data"

    # The textarea should be sized for its content (basic check)
    original_height = license_textarea.evaluate_script('this.offsetHeight')
    assert original_height > 60, "Textarea should be auto-sized for content (#{original_height}px)"

    # Verify content fits without excessive scrolling
    scroll_height = license_textarea.evaluate_script('this.scrollHeight')
    client_height = license_textarea.evaluate_script('this.clientHeight')
    assert (scroll_height - client_height) <= 20, "Textarea should fit content reasonably well"
  end

  test "plaintext invoice line textarea resizes when content changes" do
    license_invoice = invoices(:license_invoice)

    visit "/invoices/#{license_invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    # Find the license textarea
    license_textarea = find('textarea[name*="[description]"]') do |textarea|
      textarea.value.include?("Primary License:")
    end

    assert license_textarea, "Should find textarea with license key data"

    original_height = license_textarea.evaluate_script('this.offsetHeight')

    # Test with short content
    license_textarea.fill_in(with: "Short content")
    sleep 0.1
    new_height = license_textarea.evaluate_script('this.offsetHeight')

    # Basic resize check (allow some flexibility)
    assert new_height <= original_height + 10, "Textarea should not grow significantly with short content"

    # Test with long content
    long_content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6\nLine 7\nLine 8"
    license_textarea.fill_in(with: long_content)
    sleep 0.1
    final_height = license_textarea.evaluate_script('this.offsetHeight')

    # Should accommodate longer content
    assert final_height >= new_height, "Textarea should accommodate longer content"
  end

  test "description textarea auto-resizes properly" do
    # Use any invoice with regular item lines
    invoice = Invoice.joins(:invoice_lines)
                    .where(invoice_lines: { type: 'item' })
                    .first

    visit "/invoices/#{invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    # Find a description textarea (these are for item lines)
    description_textarea = find('textarea[name*="[description]"]')

    original_height = description_textarea.evaluate_script('this.offsetHeight')

    # Add multi-line content
    multiline_content = "First line of description\nSecond line with more detail\nThird line with even more information\nFourth line to test the auto-resize\nFifth line for good measure"
    description_textarea.fill_in(with: multiline_content)

    sleep 0.1

    new_height = description_textarea.evaluate_script('this.offsetHeight')

    # Height should have increased to accommodate the content
    assert new_height > original_height,
           "Description textarea should auto-resize (was #{original_height}px, now #{new_height}px)"

    # Content should fit without scrolling
    scroll_height = description_textarea.evaluate_script('this.scrollHeight')
    client_height = description_textarea.evaluate_script('this.clientHeight')

    assert (scroll_height - client_height).abs <= 5,
           "Description textarea should not need scrolling after resize"
  end

  test "prelude textarea auto-resizes on page load and content change" do
    # Use the license invoice which has a multi-line prelude
    invoice = invoices(:license_invoice)

    visit "/invoices/#{invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    # Find the prelude textarea
    prelude_textarea = find('textarea[name="invoice[prelude]"]')

    # Basic size check - should be reasonable height for the content
    original_height = prelude_textarea.evaluate_script('this.offsetHeight')
    assert original_height > 60, "Prelude textarea should be sized for content (#{original_height}px)"

    # Test resizing with different content
    prelude_textarea.fill_in(with: "Short prelude")
    sleep 0.1
    new_height = prelude_textarea.evaluate_script('this.offsetHeight')

    # Should still be a reasonable size
    assert new_height >= 60, "Prelude textarea should maintain minimum size"

    # Add more content
    prelude_textarea.fill_in(with: "Longer prelude text\nwith multiple lines\nto test resizing")
    sleep 0.1

    final_height = prelude_textarea.evaluate_script('this.offsetHeight')
    assert final_height >= new_height,
           "Prelude textarea should accommodate longer content"
  end

  test "textarea auto-resize respects minimum height of 3 lines" do
    invoice = invoices(:license_invoice)
    visit "/invoices/#{invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    prelude_textarea = find('textarea[name="invoice[prelude]"]')

    # Clear content to test minimum height
    prelude_textarea.fill_in(with: "")
    sleep 0.1

    height = prelude_textarea.evaluate_script('this.offsetHeight')

    # Calculate expected minimum height for 3 lines
    line_height = prelude_textarea.evaluate_script('parseInt(window.getComputedStyle(this).lineHeight) || 20')
    padding_top = prelude_textarea.evaluate_script('parseInt(window.getComputedStyle(this).paddingTop) || 0')
    padding_bottom = prelude_textarea.evaluate_script('parseInt(window.getComputedStyle(this).paddingBottom) || 0')
    border_top = prelude_textarea.evaluate_script('parseInt(window.getComputedStyle(this).borderTopWidth) || 0')
    border_bottom = prelude_textarea.evaluate_script('parseInt(window.getComputedStyle(this).borderBottomWidth) || 0')

    min_expected = (line_height * 3) + padding_top + padding_bottom + border_top + border_bottom

    # Allow small buffer for calculation differences
    assert height >= (min_expected - 10),
           "Empty textarea should maintain minimum height of ~3 lines (actual: #{height}px, expected: ~#{min_expected}px)"
  end
end
