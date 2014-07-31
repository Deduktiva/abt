class Invoice < ActiveRecord::Base
  validates :customer_id, :presence => true

  belongs_to :customer
  belongs_to :project
  belongs_to :attachment

  has_many :invoice_lines, :after_add => :update_sums, :after_remove => :update_sums
  accepts_nested_attributes_for :invoice_lines

  has_many :invoice_tax_classes

private
  def update_sums(changed_item)
    return if self.published?
    self[:sum_net] = 0
    self[:sum_total] = 0
    self.invoice_lines.each do |line|
      if line.type == 'item'
        self[:sum_net] += line.amount
      end
    end
    self.save
  end
end
