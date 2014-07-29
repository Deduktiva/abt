class DocumentNumber < ActiveRecord::Base
  attr_accessible :code, :format, :last_date, :last_number, :sequence

  def get_next(date)
    if !self.last_date.nil? && date < self.last_date
      raise "New date #{date} is older than previously used date #{self.date}"
    end
    wraparound_if_needed date
    self.sequence = self.sequence + 1
    self.last_date = date
    self.last_number = format_at date
  end

  def wraparound_if_needed(date)
    return unless self.format.include? 'year'
    if self.last_date.nil? || date.year != self.last_date.year
      self.sequence = 0
    end
  end

  def format_at(date)
    self.format % { :year => date.year, :number => self.sequence }
  end

  def self.get_next_for(code, date)
    dn = DocumentNumber.find_by_code code
    raise "No document number config for code #{code}" if dn.nil?
    number = dn.get_next date
    dn.save!
    number
  end
end
