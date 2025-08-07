class Invoice < ApplicationRecord
  validates :customer_id, :presence => true
  default_scope { order(Arel.sql("id ASC")) }

  scope :email_sent, -> { where.not(email_sent_at: nil) }
  scope :email_unsent, -> {
    joins(:customer)
    .where(email_sent_at: nil)
    .where("customers.email IS NOT NULL AND customers.email != '' OR customers.invoice_email_auto_enabled = true")
  }
  scope :published, -> { where(published: true) }

  after_initialize :set_defaults

  belongs_to :customer
  belongs_to :project
  belongs_to :attachment, :optional => true

  has_many :invoice_lines, -> { order(:position, :id) }, :after_add => :line_addedremoved, :after_remove => :line_addedremoved
  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :all_blank

  has_many :invoice_tax_classes

  before_save :update_customer
  before_save :update_sums

  def has_items?
    self.invoice_lines.any? { |line| line.is_item? }
  end

  def validate_lines_for_booking
    errors = []
    log = []
    log << '--- BEGIN LINES ---'

    self.invoice_lines.each do |line|
      log << "#{line.id}.  #{line.type} #{line.title} #{line.description}"

      next unless line.is_item?

      if line.quantity.nil?
        errors << "no quantity on line id #{line.id}"
      end

      if line.rate.nil?
        errors << "no rate on line id #{line.id}"
      end

      itc = self.invoice_tax_classes.find_by_sales_tax_product_class_id(line.sales_tax_product_class_id)
      if itc.nil?
        errors << "no tax config for product class #{line.sales_tax_product_class_id}"
      end

      log << "#{line.id}.     Qty #{line.quantity} * #{line.rate} = #{line.amount}"
    end

    log << '--- END LINES ---'
    log << ''

    return {
      :success => errors.empty?,
      :errors => errors,
      :log => log,
    }
  end

private
  def update_sums
    return if self.published?

    self.setup_tax_classes
    self.invoice_tax_classes.records  # ensure invoice_tax_classes is loaded
    modified_itcs = []
    valid = true

    # Reset all tax class sums before recalculating
    self.invoice_tax_classes.each do |itc|
      itc.net = 0
    end

    self[:sum_net] = 0
    self[:sum_total] = 0
    self.invoice_lines.each do |line|
      line.calculate_amount

      if line.is_item?
        itc = self.invoice_tax_classes.find { |itc| itc.sales_tax_product_class_id == line.sales_tax_product_class_id }

        if itc.nil?
          Rails.logger.warn "!! No InvoiceTaxClass for sales_tax_product_class_id = #{line.sales_tax_product_class_id}, line #{line.inspect}"
          line.sales_tax_name = nil
          line.sales_tax_rate = nil
          line.sales_tax_indicator_code = nil
          valid = false
        else
          line.sales_tax_name = itc.name
          line.sales_tax_rate = itc.rate
          line.sales_tax_indicator_code = itc.indicator_code

          current_net = itc.net || 0
          itc.net = current_net + line.amount
          itc.save! # Save immediately to ensure persistence
        end
      end
    end

    self.invoice_tax_classes.each do |itc|
      self[:sum_net] += itc.net
      self[:sum_total] += itc.total
    end

    # Reset sum_total if tax setup is broken.
    if !valid
      Rails.logger.warn "!! Invoice has invalid items, resetting sum_total"
      self[:sum_total] = 0
    end
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

  def setup_tax_classes
    if self.customer.nil? or self.customer.sales_tax_rates.nil?
      customer_sales_tax_rates = []
    else
      customer_sales_tax_rates = self.customer.sales_tax_rates
    end

    # Get required product class IDs from customer tax rates
    required_product_class_ids = customer_sales_tax_rates.map(&:sales_tax_product_class_id).to_set

    # Get existing tax classes
    existing_tax_classes = self.invoice_tax_classes.includes(:sales_tax_product_class).index_by(&:sales_tax_product_class_id)

    # Update/create required tax classes
    customer_sales_tax_rates.each do |cst|
      product_class_id = cst.sales_tax_product_class_id

      if existing_tax_classes[product_class_id]
        # Update existing tax class
        itc = existing_tax_classes[product_class_id]
        itc.name = cst.sales_tax_product_class.name
        itc.indicator_code = cst.sales_tax_product_class.indicator_code
        itc.rate = cst.rate
        itc.net = 0
        itc.total = 0
        itc.save
      else
        # Create new tax class
        self.invoice_tax_classes << InvoiceTaxClass.new(
          sales_tax_product_class: cst.sales_tax_product_class,
          name: cst.sales_tax_product_class.name,
          indicator_code: cst.sales_tax_product_class.indicator_code,
          rate: cst.rate,
          net: 0,
          total: 0
        )
      end
    end

    # Delete tax classes that are no longer needed
    self.invoice_tax_classes.where.not(sales_tax_product_class_id: required_product_class_ids).destroy_all
  end
end
