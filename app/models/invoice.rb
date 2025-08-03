class Invoice < ApplicationRecord
  validates :customer_id, :presence => true
  default_scope { order(Arel.sql("id ASC")) }

  after_initialize :set_defaults

  belongs_to :customer
  belongs_to :project
  belongs_to :attachment, :optional => true

  has_many :invoice_lines, -> { order(:position, :id) }, :after_add => :line_addedremoved, :after_remove => :line_addedremoved
  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :all_blank

  has_many :invoice_tax_classes

  before_save :update_sums
  before_save :update_customer

private
  def update_sums
    return if self.published?
    self[:sum_net] = 0
    self.invoice_lines.each do |line|
      line.calculate_amount
      self[:sum_net] += line.amount
    end
    # Reset sum_total to 0 when draft is modified - requires new test booking
    self[:sum_total] = 0
    # Clear any existing tax classes from previous test bookings
    self.invoice_tax_classes.destroy_all
  end

  def update_customer
    return if self.published?
    self.customer.reload
    self.customer_name = self.customer.name
    self.customer_address = self.customer.address
    self.customer_account_number = self.customer.id
    self.customer_supplier_number = self.customer.supplier_number
    self.customer_vat_id = self.customer.vat_id
    self.customer.sales_tax_customer_class.reload
    self.tax_note = self.customer.sales_tax_customer_class.invoice_note
  end

  def line_addedremoved(changed_item)
    self.update_sums
    self.save
  end

  def set_defaults
    self.sum_net ||= 0.0
    self.sum_total ||= 0.0
  end
end
