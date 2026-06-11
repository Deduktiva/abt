require "application_system_test_case"

class InvoiceCsvImportTest < ApplicationSystemTestCase
  setup do
    @invoice = invoices(:draft_invoice)
  end

  test "importing a Tyme CSV injects localized lines into the editor" do
    visit edit_invoice_path(@invoice)
    initial = all("[data-line-index]").count

    attach_file("file", Rails.root.join("test/fixtures/files/tyme_sample.csv"), make_visible: true)

    assert_selector "[data-line-index]", count: initial + 3
    new_lines = all("[data-line-index]").last(3)

    titles = new_lines.map { |line| line.find('input[name*="[title]"]').value }
    assert_includes titles, "IT-Beratung pro Stunde: Project Alpha"

    quantities = new_lines.map { |line| line.find('input[name*="[quantity]"]', visible: false).value }
    assert_includes quantities, "6.75"

    descriptions = new_lines.map { |line| line.find('textarea[name*="[description]"]').value }
    assert descriptions.any? { |d| d.include?("März 2025") }, "expected a line with a localized month header"
    assert descriptions.any? { |d| d.include?("Endkunde: Northwind Ltd") }, "expected the end-customer line"

    new_lines.each do |line|
      assert line.has_no_selector?("[data-product-dropdown]", visible: true),
        "imported lines should not open the product picker"
    end
  end
end
