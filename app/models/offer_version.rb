class OfferVersion < ApplicationRecord
  belongs_to :offer
  belongs_to :sales_tax_product_class, optional: true
  belongs_to :attachment, optional: true

  has_many :milestones, -> { order(:position, :id) }, class_name: "OfferMilestone", dependent: :destroy
  accepts_nested_attributes_for :milestones, allow_destroy: true, reject_if: :all_blank

  include StripsRichTextEdges

  has_rich_text :prelude
  has_rich_text :boilerplate
  strips_rich_text_edges :prelude

  validates :version_number, presence: true, uniqueness: { scope: :offer_id }

  # Deliberately shadows Object#frozen? to match the domain language
  # ("frozen once sent"). ActiveRecord persistence does not consult
  # Object#frozen?, but don't duck-type this against Ruby's freeze protocol.
  def frozen?
    sent_at.present?
  end

  def recalculate_sum_net!
    update_column(:sum_net, milestones.reload.sum(:amount))
  end

  # Copies customer-facing content into a new draft version. Frozen
  # customer-derived values (snapshot, boilerplate) deliberately do NOT copy —
  # drafts return to the live customer reference.
  def branch_draft!
    offer.versions.create!(
      version_number: offer.versions.maximum(:version_number) + 1,
      subject: subject,
      salutation_override: salutation_override,
      delivery_date: delivery_date,
      sales_tax_product_class_id: sales_tax_product_class_id,
      prelude: prelude.body
    ).tap do |draft|
      milestones.each do |m|
        draft.milestones.create!(
          position: m.position, title: m.title, description: m.description,
          trigger: m.trigger, trigger_date: m.trigger_date,
          amount: m.amount, skip_delivery_note: m.skip_delivery_note
        )
      end
    end
  end
end
