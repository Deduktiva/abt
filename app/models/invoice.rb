class Invoice < ActiveRecord::Base
  validates :customer_id, :presence => true
  serialize :tax_classes
  default_scope :order => "id ASC"

  belongs_to :customer
  belongs_to :project
  belongs_to :attachment
  has_many :invoice_lines, :order => "id ASC"
end
