require "test_helper"

class DocumentNumberTest < ActiveSupport::TestCase
  test "get_next increments sequence and formats the number" do
    dn = document_numbers(:fresh)
    number = dn.get_next(Date.new(2026, 3, 1))
    assert_equal 1, dn.sequence
    assert_equal "20260001", number.to_s
    assert_equal Date.new(2026, 3, 1), dn.last_date
  end

  test "get_next resets sequence on year change when format includes year" do
    dn = document_numbers(:used1) # sequence=1, last_date=2014-01-10, format includes year
    number = dn.get_next(Date.new(2015, 1, 5))
    assert_equal 1, dn.sequence
    assert_equal "20150001", number.to_s
  end

  test "get_next does not reset sequence when staying within the same year" do
    dn = document_numbers(:used1) # sequence=1
    dn.get_next(Date.new(2014, 6, 1))
    assert_equal 2, dn.sequence
  end

  test "get_next does not reset sequence when format omits year" do
    dn = DocumentNumber.create!(code: "yearless", format: "%<number>06d", sequence: 5, last_date: Date.new(2014, 12, 31))
    dn.get_next(Date.new(2015, 1, 1))
    assert_equal 6, dn.sequence
  end

  test "get_next raises DateNotMonotonicError when date moves backward" do
    dn = document_numbers(:used1)
    assert_raises(DateNotMonotonicError) do
      dn.get_next(Date.new(2014, 1, 9))
    end
  end

  test "get_next accepts a date equal to last_date" do
    dn = document_numbers(:used1) # last_date=2014-01-10
    assert_nothing_raised { dn.get_next(Date.new(2014, 1, 10)) }
  end

  test "get_next_for raises NoDocumentNumberRangeError for unknown code" do
    assert_raises(NoDocumentNumberRangeError) do
      DocumentNumber.get_next_for("does-not-exist", Date.current)
    end
  end

  test "get_next_for saves the row and returns the formatted number" do
    number = DocumentNumber.get_next_for("invoice", Date.new(2026, 1, 1))
    assert_equal "20260001", number.to_s
    dn = DocumentNumber.find_by(code: "invoice")
    assert_equal 1, dn.sequence
    assert_equal Date.new(2026, 1, 1), dn.last_date
  end
  test "date format resets the sequence each day and zero-pads" do
    dn = DocumentNumber.create!(code: "daily", format: "%{date}-%<number>02d", sequence: 0)
    assert_equal "20260705-01", dn.get_next(Date.new(2026, 7, 5))
    assert_equal "20260705-02", dn.get_next(Date.new(2026, 7, 5))
    assert_equal "20260706-01", dn.get_next(Date.new(2026, 7, 6))
  end
end
