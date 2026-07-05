require "application_system_test_case"

class InvoicePreludeRichTextTest < ApplicationSystemTestCase
  test "prelude uses trix editor with attachment button absent" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"

    assert_selector "trix-toolbar"
    assert_selector "trix-toolbar .trix-button--icon-bold"
    assert_no_selector ".trix-button-group--file-tools"
    assert_no_selector "trix-toolbar .trix-button--icon-attach"
    assert_no_selector "trix-toolbar [data-trix-action='link']"
    assert_no_selector "trix-toolbar [data-trix-attribute='quote']"
    assert_no_selector "trix-toolbar [data-trix-attribute='code']"
    assert_no_selector "trix-toolbar [data-trix-attribute='strike']"
    assert_no_selector "trix-toolbar [data-trix-action='increaseNestingLevel']"
    assert_no_selector "trix-toolbar [data-trix-action='decreaseNestingLevel']"
  end

  test "typing in trix editor saves and displays prelude on show page" do
    invoice = invoices(:draft_invoice)
    visit "/invoices/#{invoice.id}/edit"

    assert_selector "trix-toolbar"
    editor = find("trix-editor")
    editor.click
    editor.send_keys("Hello from rich text prelude")

    click_button "Save"

    assert_selector ".card-body", text: "Hello from rich text prelude"
  end
end
