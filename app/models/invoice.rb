class Invoice < ActiveRecord::Base
  attr_accessible :attachment_id, :cust_reference, :cust_order, :customer_id, :date, :document_number, :prelude, :project_id, :published
  validates :customer_id, :presence => true

  belongs_to :customer
  belongs_to :project
  belongs_to :attachment

  def render
    # TODO: fop
    puts self.inspect
  end
end
