class OffersController < ApplicationController
  include EmailableDocument

  before_action -> { require_permission!("offers.view") },
                only: %i[index show preview preview_email preview_email_html]
  before_action -> { require_permission!("offers.edit") },
                only: %i[new create edit update destroy send_offer accept reject reopen
                         scaffold_milestones update_internal_notes upload_order_pdf send_email]
  before_action -> { require_permission!("offers.convert") },
                only: %i[convert_milestone reopen_milestone_link]

  before_action :set_offer, except: %i[index new create]
  before_action :require_editable, only: %i[edit update preview scaffold_milestones]
  before_action :require_deletable, only: %i[destroy]
  before_action :require_sent_version, only: %i[send_email]
  before_action :require_accepted, only: %i[convert_milestone reopen_milestone_link]

  def index
    @selected_year = params[:year] == "all" ? "all" : (params[:year].presence || Date.current.year).to_i
    @state_filter = params[:state].presence_in(Offer::STATES) || "all"
    @selected_customer_id = params[:customer_id].presence&.to_i

    scope = Offer.visible_to(current_user).ordered
                 .includes(:customer, :project, draft_version: :milestones, accepted_version: { milestones: :invoice })
    scope = scope.in_year(@selected_year, include_drafts: @selected_year == Date.current.year) unless @selected_year == "all"
    scope = scope.where(state: @state_filter) unless @state_filter == "all"
    scope = scope.where(customer_id: @selected_customer_id) if @selected_customer_id
    @offers = scope

    @available_years = Offer.visible_to(current_user).available_years
    @available_customers = Offer.available_customers(current_user, including: @selected_customer_id)
  end

  def show
    @version = @offer.editable? ? @offer.draft_version : @offer.current_sent_version
  end

  def new
    @offer = Offer.new(customer_id: params[:customer_id].presence)
  end

  def create
    @offer = Offer.new(offer_params)
    if @offer.save
      redirect_to edit_offer_path(@offer), flash: { notice: "Offer created.", build_starter_milestone: true }
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @autofocus_first_milestone = flash[:build_starter_milestone].present?
  end

  def update
    if @offer.update(offer_params)
      redirect_to @offer, notice: "Offer updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @offer.destroy
    redirect_to offers_path, notice: "Offer deleted."
  end

  def preview
    problems = @offer.send_problems
    if problems.any?
      redirect_to @offer, alert: problems.join("; ")
      return
    end

    version = @offer.draft_version
    version.date = Date.current
    pdf = OfferRenderer.new(version, IssuerCompany.get_the_issuer!).render
    send_data pdf, type: "application/pdf", disposition: "inline",
              filename: "offer-draft-#{@offer.id}.pdf"
  end

  def send_offer
    sender = OfferSender.new(@offer, IssuerCompany.get_the_issuer!)
    if sender.send!
      redirect_to @offer, notice: "Offer sent version #{@offer.reload.current_sent_version.version_number}."
    else
      redirect_to @offer, alert: sender.log.presence || "Offer could not be sent."
    end
  end

  def accept
    order_pdf = params[:order_pdf]
    if order_pdf.present? && Attachment.detect_content_type(order_pdf.tempfile) != "application/pdf"
      return redirect_to @offer, alert: "Order document must be a PDF."
    end
    @offer.accept!(order_number: params[:order_number], ordered_on: params[:ordered_on],
                   order_pdf: order_pdf)
    redirect_to @offer, notice: "Offer accepted."
  rescue Offer::InvalidTransition => e
    redirect_to @offer, alert: e.message
  end

  def reject
    @offer.reject!
    redirect_to @offer, notice: "Offer rejected."
  rescue Offer::InvalidTransition => e
    redirect_to @offer, alert: e.message
  end

  def reopen
    @offer.reopen!
    redirect_to @offer, notice: "Offer reopened."
  rescue Offer::InvalidTransition => e
    redirect_to @offer, alert: e.message
  end

  # Submitted by the page form via formaction, so pending edits save first.
  def scaffold_milestones
    if params[:offer].present? && !@offer.update(offer_params)
      return render :edit, status: :unprocessable_content
    end
    OfferMilestoneScaffolder.new(@offer.customer, params[:total].to_d).apply_to(@offer.draft_version)
    redirect_to edit_offer_path(@offer), notice: "Milestones scaffolded."
  rescue OfferMilestoneScaffolder::MilestonesPresent
    redirect_to edit_offer_path(@offer), alert: "Remove the existing milestones first."
  end

  def update_internal_notes
    @offer.update!(internal_notes: params.require(:offer)[:internal_notes])
    redirect_to @offer, notice: "Internal notes saved."
  end

  def upload_order_pdf
    uploaded = params[:order_pdf]
    if uploaded.blank? || Attachment.detect_content_type(uploaded.tempfile) != "application/pdf"
      return redirect_to @offer, alert: "Order document must be a PDF."
    end
    @offer.attach_order_pdf(uploaded)
    @offer.save!
    redirect_to @offer, notice: "Order document stored."
  end

  def convert_milestone
    milestone = accepted_milestone!
    invoice = OfferMilestoneConverter.new(milestone).convert!
    documents = [ invoice, milestone.reload.delivery_note ].compact.map(&:display_name)
    redirect_to @offer, notice: "Milestone converted to #{documents.join(' and ')}."
  rescue OfferMilestoneConverter::NotConvertible => e
    redirect_to @offer, alert: e.message
  end

  def reopen_milestone_link
    milestone = accepted_milestone!
    milestone.reopen_link!
    redirect_to @offer, notice: "Milestone link cleared."
  end

  protected

  def set_offer
    @offer = Offer.visible_to(current_user).find(params[:id])
  end

  # EmailableDocument hooks.
  def email_preview_document = @offer

  def email_preview_mail = build_customer_email(skip_attachments: false)
  def email_preview_html_mail = build_customer_email(skip_attachments: true)
  def email_for_sending = build_customer_email(skip_attachments: false)

  def build_customer_email(skip_attachments:)
    OfferMailer.with(offer: @offer, skip_attachments:).customer_email
  end

  private

  def require_editable
    redirect_to @offer, alert: "This offer can no longer be edited." unless @offer.editable?
  end

  def require_deletable
    redirect_to @offer, alert: "Only draft offers can be deleted." unless @offer.deletable?
  end

  # send_email delegates to EmailableDocument, which already redirects with
  # "No recipient configured." when #emailable? is false — but that check
  # can't distinguish "never sent" from "sent but no contact opted in for
  # offer emails". Offers that have never been sent have no rendered PDF at
  # all, so give that case its own clearer message before EmailableDocument
  # runs.
  def require_sent_version
    return true if @offer.current_sent_version.present?
    redirect_to @offer, alert: "Send the offer before emailing it."
    false
  end

  # Guards convert_milestone and reopen_milestone_link: both dig through
  # @offer.accepted_version, which is nil unless the offer is accepted (e.g.
  # a stale tab left open on a sent-but-not-yet-accepted offer). Without this,
  # accepted_milestone! raises NoMethodError on nil instead of redirecting.
  def require_accepted
    return true if @offer.accepted?
    redirect_to @offer, alert: "This offer must be accepted before its milestones can be converted."
    false
  end

  def accepted_milestone!
    @offer.accepted_version.milestones.find(params[:milestone_id])
  end

  def offer_params
    params.require(:offer).permit(
      :customer_id, :project_id, :customer_contact_id, :internal_reference,
      draft_version_attributes: [
        :id, :subject, :prelude, :salutation_override, :delivery_date, :sales_tax_product_class_id,
        milestones_attributes: [
          :id, :position, :title, :description, :trigger, :trigger_date,
          :amount, :skip_delivery_note, :_destroy
        ]
      ]
    )
  end
end
