require 'test_helper'

class DocumentNumberTest < ActiveSupport::TestCase
  test 'should not get number if code does not exist' do
    assert_raise NoDocumentNumberRangeError do
      DocumentNumber.get_next_for :invalid, Date.today
    end
  end

  test 'should assign a number' do
    assert DocumentNumber.get_next_for :one, Date.new(2014, 2, 1)
  end

  test 'should not assign numbers when date is older than previous date' do
    DocumentNumber.get_next_for :one, Date.new(2014, 1, 30)
    assert_raise DateNotMonotonicError do
      DocumentNumber.get_next_for :one, Date.new(2014, 1, 29)
    end
  end

  test 'should assign numbers when date is same as previous date' do
    DocumentNumber.get_next_for :one, Date.new(2014, 1, 30)
    assert DocumentNumber.get_next_for :one, Date.new(2014, 1, 30)
  end

  test 'should start at 1' do
    assert DocumentNumber.get_next_for(:fresh, Date.new(2014, 1, 30)) == '20140001'
  end

  test 'should wrap at new year' do
    DocumentNumber.get_next_for :one, Date.new(2014, 10, 1)
    DocumentNumber.get_next_for :one, Date.new(2014, 10, 2)
    assert DocumentNumber.get_next_for(:one, Date.new(2015, 1, 1)) == '20150001'
  end

end
