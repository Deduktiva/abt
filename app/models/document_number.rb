class NoDocumentNumberRangeError < StandardError; end
class DateNotMonotonicError < StandardError; end

class DocumentNumber < ActiveRecord::Base
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
    return unless self.format.include? 'year'
    if self.last_date.nil? or (date.year != self.last_date.year)
      self.sequence = 0
    end
  end

  def format_at(date)
    self.format % { :year => date.year, :number => self.sequence }
  end

  def self.get_next_for(code, date)
    dn = DocumentNumber.find_by_code code
    raise NoDocumentNumberRangeError.new "No document number config for code #{code}" if dn.nil?
    number = dn.get_next date
    dn.save!
    number
  end
end
