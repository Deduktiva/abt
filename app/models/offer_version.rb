class OfferVersion < ApplicationRecord
  belongs_to :offer
  belongs_to :sales_tax_product_class, optional: true
  belongs_to :pdf_attachment, class_name: "Attachment", optional: true
  has_many :offer_milestones, -> { order(:position, :id) }, dependent: :destroy

  enum :state, {
    draft: "draft",
    sent: "sent",
    superseded: "superseded"
  }, prefix: :state

  validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :version_number, uniqueness: { scope: :offer_id }

  before_validation :assign_version_number, on: :create
  before_validation :assign_default_tax_class, on: :create

  # Frozen versions cannot be edited. Drafts are editable; superseded snapshots
  # are read-only history. The latest version of an Offer is always either a
  # draft (in-progress) or sent (just sent and pending branching by next send).
  def editable?
    state_draft?
  end

  def frozen_state?
    !state_draft?
  end

  # Identifier used for the PDF cover, page header, and filename:
  #   "<document_number> <matchcode> v<version_number>"
  # Falls back to "DRAFT" when the offer hasn't been sent yet (no
  # document_number).
  def identifier
    parts = [ offer.document_number.presence || "DRAFT", offer.matchcode, "v#{version_number}" ]
    parts.join(" ")
  end

  private

  def assign_version_number
    return if version_number.present?
    self.version_number = (offer.offer_versions.maximum(:version_number) || 0) + 1
  end

  def assign_default_tax_class
    return if sales_tax_product_class_id.present?
    self.sales_tax_product_class = SalesTaxProductClass.where(is_default: true).first
  end
end
