class Offer < ApplicationRecord
  include ScopedThroughCustomer

  belongs_to :customer
  belongs_to :project, optional: true
  belongs_to :addressed_to_contact, class_name: "CustomerContact", optional: true
  belongs_to :accepted_version, class_name: "OfferVersion", optional: true
  has_many :offer_versions, dependent: :destroy

  enum :state, {
    draft: "draft",
    sent: "sent",
    accepted: "accepted",
    rejected: "rejected",
    expired: "expired"
  }, prefix: :state

  validates :matchcode, presence: true,
                        uniqueness: { scope: :customer_id, case_sensitive: false }
  validate :addressed_to_contact_belongs_to_customer

  # The latest OfferVersion row (highest version_number). Drafts created by
  # send! auto-branching live as the current_version until the next send.
  def current_version
    offer_versions.order(version_number: :desc).first
  end

  # The most-recently-sent (frozen) version, used for the customer-facing
  # representation: PDF, email attachment, "last sent on …" timestamps.
  def latest_sent_version
    offer_versions.where(state: [ "sent", "superseded" ]).order(version_number: :desc).first
  end

  # Effective offer validity window (days). Customer override falls back to
  # the issuer-wide default.
  def validity_days
    customer.offer_validity_days.presence || IssuerCompany.get_the_issuer!.offer_validity_days
  end

  # Recipients used by the OfferMailer for To: line. Mirrors the Invoice /
  # DeliveryNote helpers introduced by PR #323 / PR #351.
  def email_recipients
    if customer.offer_email_auto_enabled?
      [ customer.offer_email_auto_to.to_s.strip ].reject(&:empty?)
    else
      customer.contacts_for_offer(self).map(&:email)
    end
  end

  def email_cc_recipients
    return [] unless customer.offer_email_auto_enabled? && customer.offer_cc_contacts?
    auto_to = customer.offer_email_auto_to.to_s.downcase.strip
    customer.contacts_for_offer(self).map(&:email).reject { |e| e.to_s.downcase.strip == auto_to }
  end

  def email_salutation_contact
    return nil if customer.offer_email_auto_enabled?
    contacts = customer.contacts_for_offer(self)
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

  # Factory: create a new offer + its v1 draft in one transaction.
  def self.create_with_initial_version!(attributes)
    transaction do
      offer = create!(attributes)
      offer.offer_versions.create!
      offer.reload
    end
  end

  # Send the current draft version: freezes it, marks priors superseded,
  # assigns document_number on first send, refreshes expires_at, creates the
  # next-version draft. Returns the just-sent OfferVersion.
  #
  # PDF rendering / storage into pdf_attachment_id is wired by the renderer
  # in a later commit; for now sent versions carry no PDF attachment.
  def send_current_version!
    raise "cannot send: state is #{state}, not draft or sent" unless state_draft? || state_sent?
    version = current_version
    raise "cannot send: no current version" if version.nil?
    raise "cannot send: current version is not a draft" unless version.state_draft?

    now = Time.current
    transaction do
      self.document_number ||= DocumentNumber.get_next_for("offer", now.to_date)

      offer_versions.where.not(id: version.id).where(state: "sent").update_all(state: "superseded", updated_at: now)

      version.update!(state: "sent", sent_at: now)

      self.state = "sent"
      self.expires_at = now + validity_days.days
      save!

      next_draft = offer_versions.create!(
        prelude: version.prelude,
        salutation_override: version.salutation_override,
        delivery_start_date: version.delivery_start_date,
        delivery_end_date: version.delivery_end_date,
        sales_tax_product_class: version.sales_tax_product_class,
        client_line_override: version.client_line_override
      )
      copy_milestones_from(version, next_draft)
    end

    version
  end

  # Mark the offer accepted; remembers which version was accepted. Discards
  # the in-progress draft (if any) since acceptance ends edits.
  def accept!
    raise "cannot accept: state is #{state}, not sent" unless state_sent?
    sent_version = latest_sent_version
    raise "cannot accept: no sent version" if sent_version.nil?

    transaction do
      offer_versions.where(state: "draft").destroy_all
      update!(
        state: "accepted",
        accepted_at: Time.current,
        accepted_version_id: sent_version.id,
        rejected_at: nil,
        reopened_at: nil
      )
    end
  end

  def reject!
    raise "cannot reject: state is #{state}" unless state_sent? || state_expired?
    update!(state: "rejected", rejected_at: Time.current)
  end

  # Reopen an accepted offer for further edits. Creates a fresh draft branched
  # off the previously-accepted version's milestones / prelude so the user
  # doesn't start from scratch.
  def reopen!
    raise "cannot reopen: state is #{state}, not accepted" unless state_accepted?
    raise "cannot reopen: no accepted_version recorded" if accepted_version.nil?

    transaction do
      base = accepted_version
      next_n = (offer_versions.maximum(:version_number) || 0) + 1
      draft = offer_versions.create!(
        version_number: next_n,
        state: "draft",
        prelude: base.prelude,
        salutation_override: base.salutation_override,
        delivery_start_date: base.delivery_start_date,
        delivery_end_date: base.delivery_end_date,
        sales_tax_product_class: base.sales_tax_product_class,
        client_line_override: base.client_line_override
      )
      copy_milestones_from(base, draft)

      update!(
        state: "sent",
        accepted_at: nil,
        accepted_version_id: nil,
        reopened_at: Time.current
      )
    end
  end

  private

  def addressed_to_contact_belongs_to_customer
    return if addressed_to_contact.nil?
    return if addressed_to_contact.customer_id == customer_id
    errors.add(:addressed_to_contact_id, "must belong to this offer's customer")
  end

  # Deep-copy milestones from one version to another. Conversion FKs (linked
  # invoice / delivery_note) are TRANSFERRED — cleared on the source row and
  # set on the new row — because the partial-unique indexes only allow one
  # milestone per linked invoice/delivery_note at a time. The latest version
  # therefore owns the conversion link; older versions become history.
  def copy_milestones_from(source_version, target_version)
    source_version.offer_milestones.order(:position, :id).each do |m|
      invoice_id = m.invoice_id
      delivery_note_id = m.delivery_note_id
      if invoice_id || delivery_note_id
        m.update_columns(invoice_id: nil, delivery_note_id: nil, updated_at: Time.current)
      end
      target_version.offer_milestones.create!(
        position: m.position,
        title: m.title,
        description: m.description,
        trigger: m.trigger,
        trigger_date: m.trigger_date,
        net_amount: m.net_amount,
        skip_delivery_note: m.skip_delivery_note,
        invoice_id: invoice_id,
        delivery_note_id: delivery_note_id
      )
    end
  end
end
