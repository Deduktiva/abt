class OfferMilestonesController < ApplicationController
  before_action -> { require_permission!("offers.edit") }, except: %i[convert reopen]
  before_action -> { require_permission!("offers.convert") }, only: %i[convert reopen]
  before_action :set_offer
  before_action :ensure_editable, only: %i[create update destroy scaffold]
  before_action :set_milestone, only: %i[update destroy convert reopen]

  def create
    @milestone = current_version.offer_milestones.build(milestone_params)
    if @milestone.save
      redirect_to edit_offer_path(@offer), notice: "Milestone added."
    else
      redirect_to edit_offer_path(@offer), alert: @milestone.errors.full_messages.to_sentence
    end
  end

  def update
    if @milestone.update(milestone_params)
      redirect_to edit_offer_path(@offer), notice: "Milestone updated."
    else
      redirect_to edit_offer_path(@offer), alert: @milestone.errors.full_messages.to_sentence
    end
  end

  def destroy
    @milestone.destroy
    redirect_to edit_offer_path(@offer), notice: "Milestone removed."
  end

  # POST /offers/:offer_id/milestones/scaffold
  # Builds milestones for the current draft from the customer's offer
  # milestone rule. Refuses if the draft already has milestones (the rule
  # is a scaffold, not a destructive replace).
  def scaffold
    if current_version.offer_milestones.any?
      redirect_to edit_offer_path(@offer),
                  alert: "Milestones already exist. Remove them before applying the rule." and return
    end

    total = BigDecimal(params[:total_amount].to_s)
    if total <= 0
      redirect_to edit_offer_path(@offer),
                  alert: "Enter a positive total amount." and return
    end

    @offer.customer.scaffold_offer_milestones(total).each do |attrs|
      current_version.offer_milestones.create!(attrs)
    end
    redirect_to edit_offer_path(@offer), notice: "Milestones scaffolded from customer rule."
  end

  # POST /offers/:offer_id/milestones/:id/convert
  # Builds a draft Invoice (and optionally DeliveryNote) for this milestone
  # and links the FKs back. Only valid on milestones owned by the
  # accepted_version, since OfferMilestone#convert! gates on state_accepted?.
  def convert
    skip_dn = params[:skip_delivery_note].nil? ? nil : ActiveModel::Type::Boolean.new.cast(params[:skip_delivery_note])
    invoice = @milestone.convert!(skip_delivery_note: skip_dn)
    redirect_to invoice, notice: "Invoice draft created from milestone."
  rescue RuntimeError, ActiveRecord::RecordInvalid => e
    redirect_to @offer, alert: e.message
  end

  # POST /offers/:offer_id/milestones/:id/reopen
  # Manually clear invoice / delivery_note links from a milestone so it can
  # be converted again. Used after an invoice gets voided/deleted, where
  # the milestone link is intentionally NOT auto-cleared.
  def reopen
    @milestone.update!(invoice_id: nil, delivery_note_id: nil)
    redirect_to @offer, notice: "Milestone marked as not-converted."
  end

  private

  def set_offer
    @offer = Offer.visible_to(current_user).find(params[:offer_id])
  end

  def ensure_editable
    return if @offer.state_draft? && current_version&.state_draft?
    redirect_to @offer, alert: "Milestones can only be edited on the current draft version."
  end

  def set_milestone
    # convert/reopen target milestones on the accepted_version, not just the
    # current draft. Find across all versions on this offer.
    @milestone = OfferMilestone.joins(:offer_version)
                               .where(offer_versions: { offer_id: @offer.id })
                               .find(params[:id])
  end

  def current_version
    @offer.current_version
  end

  def milestone_params
    params.require(:offer_milestone)
          .permit(:title, :description, :trigger, :trigger_date, :net_amount, :skip_delivery_note, :position)
  end
end
