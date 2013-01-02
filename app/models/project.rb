class Project < ActiveRecord::Base
  attr_accessible :bill_to_customer_id, :description, :matchcode, :time_budget
  belongs_to :bill_to_customer, :class_name => "Customer"

  validates :matchcode, :presence => true

end
