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

  def calculate_estimated_taxes
    return [] if published? || sum_net == 0

    estimated_taxes = []

    # Get customer tax rates
    customer_sales_tax_rates = customer.sales_tax_rates
    return estimated_taxes if customer_sales_tax_rates.nil?

    # Group lines by tax class and calculate estimated taxes
    tax_totals = {}

    invoice_lines.select { |line| line.type == 'item' && line.sales_tax_product_class_id }.each do |line|
      tax_class_id = line.sales_tax_product_class_id
      line_amount = line.amount || (line.quantity * line.rate rescue 0)

      if tax_totals[tax_class_id]
        tax_totals[tax_class_id][:net] += line_amount
      else
        # Find the tax rate for this product class
        tax_rate = customer_sales_tax_rates.find { |rate| rate.sales_tax_product_class_id == tax_class_id }
        if tax_rate
          tax_totals[tax_class_id] = {
            name: tax_rate.sales_tax_product_class.name,
            rate: tax_rate.rate,
            net: line_amount
          }
        end
      end
    end

    # Calculate tax values
    tax_totals.each do |tax_class_id, data|
      tax_value = data[:net] * (data[:rate] / 100.0)
      estimated_taxes << {
        name: data[:name],
        rate: data[:rate],
        net: data[:net],
        value: tax_value
      }
    end

    estimated_taxes
  end

  def estimated_sum_total
    return sum_total if published?
    sum_net + calculate_estimated_taxes.sum { |tax| tax[:value] }
  end

private
  def update_sums
    return if self.published?
    self[:sum_net] = 0
    self.invoice_lines.each do |line|
      line.calculate_amount
      self[:sum_net] += line.amount
    end
    # For draft invoices, keep sum_total as 0 - only test booking sets it
    # self[:sum_total] remains unchanged
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
