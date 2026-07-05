require "test_helper"
require Rails.root.join("db/migrate/20260623211331_backfill_prelude_rich_text")

class BackfillPreludeRichTextTest < ActiveSupport::TestCase
  test "backfill creates rich text preserving line breaks" do
    invoice = invoices(:draft_invoice)
    ActionText::RichText.where(record: invoice, name: "prelude").delete_all

    BackfillPreludeRichText.new.create_prelude_rich_text("Invoice", invoice.id, "Line one\nLine two")

    body = ActionText::RichText.find_by!(record: invoice, name: "prelude").body.to_html
    assert_includes body, "<br"
  end
end
