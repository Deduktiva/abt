require "test_helper"

class TextareaAutoResizeTest < ActionDispatch::SystemTestCase
  test "plaintext invoice line textarea auto-resizes on page load" do
    # Use the fixture invoice with license keys
    license_invoice = invoices(:license_invoice)

    visit "/invoices/#{license_invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    # Find the textarea containing the license keys - plaintext items use title field
    # First, let's see what textareas are available
    textareas = all('textarea')
    assert textareas.count > 0, "Should have at least one textarea on the page"

    # For plaintext (plain) lines, the license keys are now in the description field
    license_textarea = nil
    textareas.each do |textarea|
      if textarea.value.include?("Primary License:")
        license_textarea = textarea
        break
      end
    end

    assert license_textarea, "Should find textarea with license key data (#{textareas.count} textareas found)"

    # The textarea should already be correctly sized for its content
    original_height = license_textarea.evaluate_script('this.offsetHeight')

    # Minimum height should be larger than 3 lines due to the long content
    # Approximate minimum for 10+ lines of text (assuming ~24px line height)
    expected_min_height = 200
    assert original_height > expected_min_height,
           "Textarea height (#{original_height}px) should be auto-sized to fit content (expected > #{expected_min_height}px)"

    # Verify the content is visible without scrolling
    scroll_height = license_textarea.evaluate_script('this.scrollHeight')
    client_height = license_textarea.evaluate_script('this.clientHeight')

    # Allow small buffer for borders/padding
    assert (scroll_height - client_height).abs <= 5,
           "Textarea should not need scrolling (scroll: #{scroll_height}, client: #{client_height})"
  end

  test "plaintext invoice line textarea resizes when content changes" do
    license_invoice = invoices(:license_invoice)

    visit "/invoices/#{license_invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    # Find the textarea containing the license keys - now in description field
    license_textarea = nil
    textareas = all('textarea')
    textareas.each do |textarea|
      if textarea.value.include?("Primary License:")
        license_textarea = textarea
        break
      end
    end

    assert license_textarea, "Should find textarea with license key data"

    original_height = license_textarea.evaluate_script('this.offsetHeight')

    # Clear the content to make it smaller
    license_textarea.fill_in(with: "Short content")

    # Wait for the resize to happen
    sleep 0.1

    new_height = license_textarea.evaluate_script('this.offsetHeight')

    # Height should have decreased significantly
    assert new_height < original_height,
           "Textarea should shrink when content is reduced (was #{original_height}px, now #{new_height}px)"

    # Now add more content
    long_content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6\nLine 7\nLine 8\nLine 9\nLine 10\nLine 11\nLine 12"
    license_textarea.fill_in(with: long_content)

    sleep 0.1

    final_height = license_textarea.evaluate_script('this.offsetHeight')

    # Height should have increased again
    assert final_height > new_height,
           "Textarea should grow when content is added (was #{new_height}px, now #{final_height}px)"
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
    # Use the license invoice which already has a long prelude
    invoice = invoices(:license_invoice)
    long_prelude = "This is a very long prelude that should span multiple lines.\n\nIt contains several paragraphs of text to demonstrate the auto-resize functionality.\n\nThe textarea should automatically adjust its height to fit all this content without requiring the user to scroll.\n\nThis makes the form much more user-friendly and professional looking."

    visit "/invoices/#{invoice.id}/edit"
    assert_no_text "Loading...", wait: 10

    # Find the prelude textarea
    prelude_textarea = find('textarea[name="invoice[prelude]"]')

    # The textarea should be sized correctly for the long content on page load
    original_height = prelude_textarea.evaluate_script('this.offsetHeight')

    # Should be taller than minimum height due to long content
    expected_min_height = 120 # More than 3 lines for the long prelude
    assert original_height > expected_min_height,
           "Prelude textarea should auto-size on load (height: #{original_height}px, expected > #{expected_min_height}px)"

    # Test dynamic resizing
    prelude_textarea.fill_in(with: "Short prelude")
    sleep 0.1

    new_height = prelude_textarea.evaluate_script('this.offsetHeight')
    assert new_height < original_height,
           "Prelude textarea should shrink with less content (was #{original_height}px, now #{new_height}px)"

    # Add content back
    prelude_textarea.fill_in(with: long_prelude)
    sleep 0.1

    final_height = prelude_textarea.evaluate_script('this.offsetHeight')
    assert final_height > new_height,
           "Prelude textarea should grow with more content (was #{new_height}px, now #{final_height}px)"
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
