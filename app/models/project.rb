class Project < ActiveRecord::Base
  belongs_to :bill_to_customer, :class_name => 'Customer'

  validates :matchcode, :presence => true
end
