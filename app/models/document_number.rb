class NoDocumentNumberRangeError < StandardError; end
class DateNotMonotonicError < StandardError; end

class DocumentNumber < ApplicationRecord
  def get_next(date)
    if !self.last_date.nil? && date < self.last_date
      raise DateNotMonotonicError.new "New date #{date} is older than previously used date #{self.last_date}"
    end
    wraparound_if_needed date
    self.sequence = self.sequence + 1
    self.last_date = date
    self.last_number = format_at date
  end

  def wraparound_if_needed(date)
    if self.format.include? "date"
      self.sequence = 0 if self.last_date.nil? or date != self.last_date
    elsif self.format.include? "year"
      self.sequence = 0 if self.last_date.nil? or date.year != self.last_date.year
    end
  end

  def format_at(date)
    self.format % { year: date.year, number: self.sequence, date: date.strftime("%Y%m%d") }
  end

  # Must run inside the caller's publish transaction: `lock` takes a row lock
  # (SELECT ... FOR UPDATE) so two concurrent publishes can't read the same
  # sequence and mint the same number.
  def self.get_next_for(code, date)
    dn = lock.find_by(code: code)
    raise NoDocumentNumberRangeError.new "No document number config for code #{code}" if dn.nil?
    number = dn.get_next date
    dn.save!
    number
  end
end
