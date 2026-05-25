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

  private

  def addressed_to_contact_belongs_to_customer
    return if addressed_to_contact.nil?
    return if addressed_to_contact.customer_id == customer_id
    errors.add(:addressed_to_contact_id, "must belong to this offer's customer")
  end
end
