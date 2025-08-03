class Invoice < ApplicationRecord
  validates :customer_id, :presence => true
  default_scope { order(Arel.sql("id ASC")) }

  belongs_to :customer
  belongs_to :project
  belongs_to :attachment, :optional => true

  has_many :invoice_lines, -> { order(:position, :id) }, :after_add => :line_addedremoved, :after_remove => :line_addedremoved
  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :all_blank

  has_many :invoice_tax_classes

  before_save :update_sums

private
  def update_sums
    return if self.published?
    self[:sum_net] = 0
    self[:sum_total] = 0
    self.invoice_lines.each do |line|
      line.calculate_amount
      self[:sum_net] += line.amount
    end
  end

  def line_addedremoved(changed_item)
    self.update_sums
    self.save
  end
end
