class Customer < ActiveRecord::Base
  attr_accessible :address, :matchcode, :name, :notes, :time_budget

  validates :matchcode, :presence => true

end
