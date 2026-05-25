class Invoice < ApplicationRecord
  include YearFilterable
  include HasLineItems
  include ScopedThroughCustomer

  has_line_items :invoice_lines

  validates :customer_id, presence: true
  validate :must_have_item_line_for_publish
  default_scope { order(Arel.sql("id ASC")) }

  # Mirror of emailable? in SQL — must agree.
  # Auto-email branch needs a non-blank auto_to (the only To recipient).
  # Contacts branch only applies when auto-email is OFF (when it's on, contacts
  # go to CC, never To).
  scope :email_unsent, -> {
    where(email_sent_at: nil).where(<<~SQL.squish)
      EXISTS (
        SELECT 1 FROM customers c
        WHERE c.id = invoices.customer_id
          AND c.invoice_email_auto_enabled = TRUE
          AND COALESCE(TRIM(c.invoice_email_auto_to), '') <> ''
      )
      OR EXISTS (
        SELECT 1 FROM customer_contacts cc
        LEFT JOIN customer_contact_projects ccp ON ccp.customer_contact_id = cc.id
        JOIN customers c ON c.id = cc.customer_id
        WHERE cc.customer_id = invoices.customer_id
          AND c.invoice_email_auto_enabled = FALSE
          AND cc.receives_invoice_emails = TRUE
          AND (ccp.project_id IS NULL OR ccp.project_id = invoices.project_id)
      )
    SQL
  }
  scope :published, -> { where(published: true) }
  scope :unpaid, -> { where(paid_at: nil) }

  # Recipients for a real outbound send. Honors invoice_email_auto_contact_mode
  # when the customer's auto-email feature is on. Returns an array of email
  # strings; callers compose them into mail.to / mail.cc.
  def email_recipients
    return customer.contacts_for_invoice(self).map(&:email) unless customer.invoice_email_auto_enabled?
    [ customer.invoice_email_auto_to ].compact_blank
  end

  def email_cc_recipients
    return [] unless customer.invoice_email_auto_enabled? && customer.cc_contacts?
    auto_to = customer.invoice_email_auto_to.to_s.downcase.strip
    customer.contacts_for_invoice(self).map(&:email).reject { |e| e.to_s.downcase.strip == auto_to }
  end

  # The contact whose salutation_line should personalize this invoice's email,
  # or nil to fall back to the I18n greeting. Returns the contact only when
  # the To: line resolves to exactly one CustomerContact (i.e. auto-email is
  # off and there's a single matching contact).
  def email_salutation_contact
    return nil if customer.invoice_email_auto_enabled?
    contacts = customer.contacts_for_invoice(self)
    contacts.size == 1 ? contacts.first : nil
  end

  def emailable?
    email_recipients.any?
  end

  def self.visible_to(user)
    return none if user.nil?
    return all if user.bypass_team_scoping?
    where(customer_id: Customer.visible_to(user).select(:id))
  end

  after_initialize :set_defaults

  belongs_to :customer
  belongs_to :project
  belongs_to :attachment, optional: true

  has_one :delivery_note

  has_many :invoice_lines, -> { order(:position, :id) }, after_add: :line_addedremoved, after_remove: :line_addedremoved
  accepts_nested_attributes_for :invoice_lines, allow_destroy: true, reject_if: :all_blank

  has_many :invoice_tax_classes

  before_save :update_customer
  before_save :update_sums

  def paid?
    self.paid_at.present?
  end

  def overdue?
    self.published? && !self.paid? && self.due_date.present? && self.due_date < Date.current
  end

  def validate_lines_for_booking
    errors = []
    log = []
    log << "--- BEGIN LINES ---"

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

    log << "--- END LINES ---"
    log << ""

    {
      success: errors.empty?,
      errors: errors,
      log: log
    }
  end

private
  def must_have_item_line_for_publish
    return unless will_save_change_to_published? && published?
    return if has_items?

    errors.add(:base, "must have at least one item line before it can be published")
  end

  def update_sums
    return if self.published?

    self.setup_tax_classes
    self.invoice_tax_classes.records  # ensure invoice_tax_classes is loaded
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
    self.payment_terms_days = self.customer.payment_terms_days
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
