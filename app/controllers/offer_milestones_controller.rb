class OfferMilestonesController < ApplicationController
  before_action -> { require_permission!("offers.edit") }
  before_action :set_offer
  before_action :ensure_editable
  before_action :set_milestone, only: %i[update destroy]

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

  private

  def set_offer
    @offer = Offer.visible_to(current_user).find(params[:offer_id])
  end

  def ensure_editable
    return if @offer.state_draft? && current_version&.state_draft?
    redirect_to @offer, alert: "Milestones can only be edited on the current draft version."
  end

  def set_milestone
    @milestone = current_version.offer_milestones.find(params[:id])
  end

  def current_version
    @offer.current_version
  end

  def milestone_params
    params.require(:offer_milestone)
          .permit(:title, :description, :trigger, :trigger_date, :net_amount, :skip_delivery_note, :position)
  end
end
