require "test_helper"

# Exercises YearFilterable once, via the Invoice model. DeliveryNote includes
# the same concern; we trust that wiring and avoid duplicating these assertions
# in delivery_notes_controller_test.rb.
class YearFilterableTest < ActiveSupport::TestCase
  test "in_year returns only records dated in the given year" do
    in_range = create_draft_invoice(cust_reference: "Y2023", date: Date.new(2023, 6, 15))
    out_of_range = create_draft_invoice(cust_reference: "Y2024", date: Date.new(2024, 6, 15))

    result = Invoice.in_year(2023)

    assert_includes result, in_range
    assert_not_includes result, out_of_range
  end

  test "in_year with include_drafts true also returns records with a null date" do
    draft = create_draft_invoice(cust_reference: "DRAFT_NIL_DATE", date: nil)
    dated = create_draft_invoice(cust_reference: "DATED_THIS_YEAR", date: Date.current)
    other_year = create_draft_invoice(cust_reference: "DATED_PRIOR_YEAR", date: Date.current - 2.years)

    result = Invoice.in_year(Date.current.year, include_drafts: true)

    assert_includes result, draft
    assert_includes result, dated
    assert_not_includes result, other_year
  end

  test "in_year with include_drafts false excludes records with a null date" do
    draft = create_draft_invoice(cust_reference: "DRAFT_EXCLUDED", date: nil)
    dated = create_draft_invoice(cust_reference: "DATED_CURRENT", date: Date.current)

    result = Invoice.in_year(Date.current.year, include_drafts: false)

    assert_not_includes result, draft
    assert_includes result, dated
  end

  test "available_years returns distinct years from non-null dates, newest first" do
    create_draft_invoice(cust_reference: "AY_2022", date: Date.new(2022, 3, 1))
    create_draft_invoice(cust_reference: "AY_2024_a", date: Date.new(2024, 2, 1))
    create_draft_invoice(cust_reference: "AY_2024_b", date: Date.new(2024, 9, 1))
    create_draft_invoice(cust_reference: "AY_DRAFT", date: nil)

    years = Invoice.available_years

    # Fixtures inject some dated records too; assert ordering and that our
    # years appear, without pinning the full set.
    assert_equal years, years.sort.reverse
    assert_includes years, 2022
    assert_includes years, 2024
  end
end
