class OffersController < ApplicationController
  before_action -> { require_permission!("offers.view") }, only: %i[index show]
  before_action -> { require_permission!("offers.edit") }, only: %i[
    new create edit update destroy
    send_now accept reject reopen
  ]

  before_action :set_offer, only: %i[show edit update destroy send_now accept reject reopen]

  # GET /offers
  def index
    @offers = Offer.visible_to(current_user)
                   .includes(:customer, :project, offer_versions: :offer_milestones)
                   .order(updated_at: :desc)
  end

  # GET /offers/1
  def show
    @current_version = @offer.current_version
    @sent_versions = @offer.offer_versions.where.not(state: "draft").order(version_number: :desc)
  end

  # GET /offers/new
  def new
    @offer = Offer.new(customer_id: params[:customer_id], project_id: params[:project_id])
  end

  # POST /offers
  def create
    attrs = offer_create_params.to_h.merge(state: "draft")
    @offer = Offer.create_with_initial_version!(attrs)
    redirect_to edit_offer_path(@offer), notice: "Offer was successfully created."
  rescue ActiveRecord::RecordInvalid => e
    @offer = e.record
    render :new, status: :unprocessable_content
  end

  # GET /offers/1/edit
  def edit
    redirect_to @offer, alert: "Only the current draft version can be edited." and return unless current_version_editable?
    @version = @offer.current_version
  end

  # PATCH /offers/1
  def update
    redirect_to @offer, alert: "Only the current draft version can be edited." and return unless current_version_editable?
    version = @offer.current_version

    if @offer.update(offer_update_params) && version.update(version_update_params)
      redirect_to @offer, notice: "Offer updated."
    else
      @version = version
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /offers/1
  def destroy
    if @offer.state_draft?
      @offer.destroy
      redirect_to offers_path, notice: "Offer was deleted."
    else
      redirect_to @offer, alert: "Cannot delete an offer that has been sent."
    end
  end

  # POST /offers/1/send
  # Named `send_now` (not `send`) to avoid shadowing Kernel#send. The route
  # uses `action: :send_now` while keeping the URL `/offers/:id/send`.
  def send_now
    @offer.send_current_version!
    redirect_to @offer, notice: "Offer v#{@offer.latest_sent_version.version_number} sent."
  rescue RuntimeError => e
    redirect_to @offer, alert: e.message
  end

  # POST /offers/1/accept
  def accept
    @offer.accept!
    redirect_to @offer, notice: "Offer accepted."
  rescue RuntimeError => e
    redirect_to @offer, alert: e.message
  end

  # POST /offers/1/reject
  def reject
    @offer.reject!
    redirect_to @offer, notice: "Offer marked as rejected."
  rescue RuntimeError => e
    redirect_to @offer, alert: e.message
  end

  # POST /offers/1/reopen
  def reopen
    @offer.reopen!
    redirect_to @offer, notice: "Offer reopened. A new draft is ready."
  rescue RuntimeError => e
    redirect_to @offer, alert: e.message
  end

  private

  def set_offer
    @offer = Offer.visible_to(current_user).find(params[:id])
  end

  def current_version_editable?
    @offer.state_draft? && @offer.current_version&.state_draft?
  end

  def offer_create_params
    params.require(:offer).permit(:matchcode, :customer_id, :project_id, :addressed_to_contact_id)
  end

  def offer_update_params
    params.require(:offer).permit(:matchcode, :project_id, :addressed_to_contact_id)
  end

  def version_update_params
    return {} unless params[:offer].is_a?(ActionController::Parameters) && params[:offer][:version].is_a?(ActionController::Parameters)
    params[:offer][:version].permit(:prelude, :salutation_override, :delivery_start_date, :delivery_end_date, :sales_tax_product_class_id, :client_line_override)
  end
end
