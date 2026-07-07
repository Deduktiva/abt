class Offer < ApplicationRecord
  include YearFilterable
  include ScopedThroughCustomer
  include DocumentIdentity
  include StripsRichTextEdges

  class InvalidTransition < StandardError; end

  STATES = %w[draft sent accepted rejected expired failed].freeze

  # Delivery is "soon" within this window (shared with UpcomingOfferDeliveriesReportJob).
  DELIVERY_SOON_WINDOW = 5.days

  belongs_to :customer
  belongs_to :project
  belongs_to :customer_contact, optional: true
  belongs_to :accepted_version, class_name: "OfferVersion", optional: true
  belongs_to :order_attachment, class_name: "Attachment", optional: true

  has_many :versions, -> { order(:version_number) }, class_name: "OfferVersion", dependent: :destroy
  has_one :draft_version, -> { where(sent_at: nil) }, class_name: "OfferVersion"
  accepts_nested_attributes_for :draft_version

  has_rich_text :internal_notes
  strips_rich_text_edges :internal_notes

  validates :state, inclusion: { in: STATES }
  validate :customer_contact_must_belong_to_customer, if: :will_save_change_to_customer_contact_id?

  after_create :create_initial_version

  STATES.each do |s|
    define_method("#{s}?") { state == s }
  end

  def current_sent_version
    return accepted_version if accepted_version
    versions.where.not(sent_at: nil).order(:version_number).last
  end

  def validity_days
    customer.offer_validity_days.presence || IssuerCompany.get_the_issuer!.offer_validity_days
  end

  def editable?
    %w[draft sent expired].include?(state) && draft_version.present?
  end

  def deletable?
    draft?
  end

  def send_problems
    problems = []
    problems << "No draft version to send." if draft_version.nil?
    problems << "Add at least one milestone before sending." if draft_version && draft_version.milestones.none?
    problems << "Add a subject before sending." if draft_version && draft_version.subject.blank?
    problems << "Offer is #{state}; reopen it before sending a revision." unless %w[draft sent expired].include?(state)
    problems
  end

  def accept!(order_number:, ordered_on:, order_pdf: nil)
    with_lock do
      raise InvalidTransition, "accept requires state sent, was #{state}" unless sent?
      raise InvalidTransition, "order date is required" if ordered_on.blank?
      self.accepted_version = versions.where.not(sent_at: nil).order(:version_number).last
      self.accepted_at = Time.current
      self.order_number = order_number
      self.ordered_on = ordered_on
      attach_order_pdf(order_pdf) if order_pdf
      self.state = "accepted"
      draft_version&.destroy
      save!
    end
  end

  def reject!
    with_lock do
      raise InvalidTransition, "reject requires sent or expired, was #{state}" unless sent? || expired?
      update!(state: "rejected", rejected_at: Time.current)
    end
  end

  def reopen!
    with_lock do
      case state
      when "accepted"
        source = accepted_version
        assign_attributes(state: "sent", accepted_at: nil, accepted_version: nil, reported_expired_at: nil)
        save!
        if draft_version.nil?
          source.branch_draft!
          # draft_version is a has_one keyed on `sent_at IS NULL`; the branch
          # above just created that row through a different in-memory Offer
          # instance (source.offer), so this object's cached "no draft" result
          # from the nil? check above would otherwise linger stale.
          association(:draft_version).reset
        end
      when "rejected"
        # reported_expired_at must be cleared here too: an offer that was
        # auto-expired by ExpiringOffersReportJob, then rejected (reject!
        # allows expired -> rejected), still carries that stamp. Left in
        # place, the job's `reported_expired_at: nil` filter would never
        # pick this offer up again after it lands back in "sent" below.
        update!(state: "sent", rejected_at: nil, reported_expired_at: nil)
      else
        raise InvalidTransition, "reopen requires accepted or rejected, was #{state}"
      end
    end
  end

  def mark_failed!
    with_lock do
      raise InvalidTransition, "mark_failed requires state accepted, was #{state}" unless accepted?
      update!(state: "failed", failed_at: Time.current)
    end
  end

  def restore!
    with_lock do
      raise InvalidTransition, "restore requires state failed, was #{state}" unless failed?
      update!(state: "accepted", failed_at: nil)
    end
  end

  def email_recipients
    customer.contacts_for_offer(self).map(&:to_email_address)
  end

  def email_cc_recipients
    []
  end

  def email_salutation_contact
    contacts = customer.contacts_for_offer(self)
    contacts.size == 1 ? contacts.first : nil
  end

  def emailable?
    current_sent_version&.attachment.present? && email_recipients.any?
  end

  def status_badge
    if accepted?
      case accepted_invoicing_status
      when :paid then [ "Paid", "bg-success" ]
      when :invoiced then [ "Invoiced", "bg-info text-dark" ]
      else [ "Ordered", "bg-primary" ]
      end
    else
      { "draft" => [ "Draft", "bg-secondary" ],
        "sent" => [ "Sent", "bg-warning text-dark" ],
        "rejected" => [ "Rejected", "bg-secondary" ],
        "expired" => [ "Expired", "bg-warning text-dark" ],
        "failed" => [ "Failed", "bg-secondary" ] }.fetch(state)
    end
  end

  # Once accepted, the status refines by invoicing progress: :invoiced when every
  # milestone has a booked invoice, :paid when those invoices are all paid too,
  # nil while any milestone is still un- or under-invoiced.
  def accepted_invoicing_status
    milestones = accepted_version&.milestones.to_a
    return nil if milestones.empty?

    invoices = milestones.map(&:invoice)
    return nil unless invoices.all? { |invoice| invoice&.published? }

    invoices.all?(&:paid?) ? :paid : :invoiced
  end

  def fully_invoiced?
    accepted_invoicing_status.present?
  end

  # True when the shown version's delivery date is near or past and invoicing
  # isn't complete yet — drives the red delivery date on the offers list.
  def delivery_date_urgent?
    return false if failed?
    date = (draft_version || current_sent_version)&.delivery_date
    return false if date.nil? || fully_invoiced?

    date <= Date.current + DELIVERY_SOON_WINDOW
  end

  def attach_order_pdf(uploaded_file)
    attachment = order_attachment || Attachment.new
    attachment.set_data(uploaded_file.read, "application/pdf")
    attachment.filename = "Order-#{display_label}.pdf"
    attachment.title = "Customer order for #{display_name}"
    attachment.save!
    self.order_attachment = attachment
  end

  private

  def create_initial_version
    versions.create!(version_number: 1, sales_tax_product_class: sole_customer_tax_class)
  end

  # Preselect the tax class when the customer's rate table offers no real choice.
  def sole_customer_tax_class
    classes = SalesTaxProductClass
      .where(id: customer.sales_tax_rates.select(:sales_tax_product_class_id))
      .limit(2).to_a
    classes.size == 1 ? classes.first : nil
  end

  def customer_contact_must_belong_to_customer
    return if customer_contact_id.nil?
    return if customer_id.nil?
    return if CustomerContact.where(id: customer_contact_id, customer_id: customer_id).exists?
    errors.add(:customer_contact, "must belong to the offer's customer")
  end
end
