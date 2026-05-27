require "json"

class InvoicesController < ApplicationController
  include EmailPreviewHelper
  include PublishableDocument
  include DocumentWithLines

  publishable_document :invoice, label: "invoice"
  document_with_lines line_class: InvoiceLine

  before_action -> { require_permission!("invoices.view") }, only: %i[index show preview preview_email preview_email_raw]
  before_action -> { require_permission!("invoices.edit") }, only: %i[
    new create edit update destroy
    publish send_email mark_paid mark_unpaid bulk_send_emails
  ]

  before_action :set_invoice, only: %i[show edit update destroy publish preview preview_email preview_email_raw send_email mark_paid mark_unpaid]

  # Permit the inline <style> blocks and embedded data: images that the
  # mailer layout produces. Scoped strictly to the iframe response so the
  # parent app's strict CSP remains intact.
  content_security_policy(only: :preview_email_raw) do |policy|
    policy.default_src     :none
    policy.style_src       :unsafe_inline
    policy.img_src         :self, :data
    policy.font_src        :none
    policy.script_src      :none
    policy.connect_src     :none
    policy.frame_ancestors :self
  end

  # The global nonce_directives setting auto-injects nonces into script-src
  # and style-src. With both 'unsafe-inline' and a nonce present, the CSP
  # spec tells browsers to ignore 'unsafe-inline' — which would re-block the
  # mailer's inline <style> tags. Strip the nonce list for this action.
  before_action(only: :preview_email_raw) { request.content_security_policy_nonce_directives = [] }
  before_action :require_unpublished, only: %i[edit update destroy preview publish]
  before_action :require_published, only: %i[send_email mark_paid mark_unpaid]
  # preview_email reads from a pre-rendered @invoice.attachment, so it never
  # invokes FOP. The guard belongs on actions that actually render. publish
  # has its own check via Invoice#publish_problems in the action body.
  before_action :require_item_line, only: %i[preview]

  # GET /invoices
  def index
    @selected_year = params[:year] == "all" ? "all" : (params[:year]&.to_i || Date.current.year)
    @filter = params[:filter] || "all"
    @selected_customer_id = params[:customer_id].presence&.to_i

    @invoices = Invoice.visible_to(current_user).ordered
    unless @selected_year == "all"
      @invoices = @invoices.in_year(@selected_year, include_drafts: @selected_year == Date.current.year)
    end

    case @filter
    when "unsent"
      @invoices = @invoices.email_unsent.published
    when "unpaid"
      @invoices = @invoices.unpaid.published
    end

    @invoices = @invoices.where(customer_id: @selected_customer_id) if @selected_customer_id

    @available_years = Invoice.visible_to(current_user).available_years
    @available_customers = Customer.visible_to(current_user)
                                   .where(id: Invoice.visible_to(current_user).select(:customer_id))
                                   .where("active = ? OR id = ?", true, @selected_customer_id)
                                   .order(:name)
  end

  # GET /invoices/1
  def show
  end

  # GET /invoices/new
  def new
    @invoice = Invoice.new(customer_id: params[:customer_id].presence)
    set_form_options
  end

  # GET /invoices/1/edit
  def edit
    set_form_options
  end

  # POST /invoices
  def create
    @invoice = Invoice.new(invoice_params)

    if @invoice.save
      redirect_to @invoice, notice: "Invoice was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PUT /invoices/1
  def update
    if @invoice.update(invoice_params)
      redirect_to @invoice, notice: "Invoice was successfully updated."
    else
      set_form_options
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /invoices/1
  def destroy
    @invoice.destroy
    redirect_to invoices_url
  end

  def publish
    publisher = InvoicePublisher.new @invoice, IssuerCompany.get_the_issuer!
    if publisher.publish!
      redirect_to invoice_path(@invoice, published: 1)
    else
      flash[:error] = "Publishing failed: #{@invoice.publish_problems.join('; ')}"
      redirect_to @invoice
    end
  end

  def preview
    issuer = IssuerCompany.get_the_issuer!
    publisher = InvoicePublisher.new @invoice, issuer
    problems = nil
    pdf = nil

    ActiveRecord::Base.transaction(requires_new: true) do
      @invoice.document_number = "DRAFT"
      publisher.prepare!
      problems = @invoice.publish_problems
      pdf = InvoiceRenderer.new(@invoice, issuer).render if problems.empty?
      raise ActiveRecord::Rollback, "preview only"
    end

    if !pdf.nil? && !pdf.empty?
      send_data pdf, type: "application/pdf", disposition: "inline"
    else
      log = [ "Preview failed.", "" ] + problems
      send_data log.join("\n"), type: "text/plain", disposition: "inline"
    end
  end

  def preview_email
    mail = InvoiceMailer.with(invoice: @invoice).customer_email
    render json: extract_email_preview_data(mail)
  end

  def preview_email_raw
    mail = InvoiceMailer.with(invoice: @invoice).customer_email
    render html: extract_html_body(mail).to_s.html_safe, layout: false
  end

  def send_email
    unless @invoice.emailable?
      respond_to do |format|
        format.html { redirect_to @invoice, alert: "No recipient configured for this invoice." }
        format.json { render json: { error: "No recipient configured for this invoice." }, status: :unprocessable_content }
      end
      return
    end
    InvoiceMailer.with(invoice: @invoice).customer_email.deliver_later
    respond_to do |format|
      format.html { redirect_to @invoice, notice: "E-Mail queued for sending." }
      format.json { head :ok }
    end
  end

  def mark_paid
    paid_date = params[:paid_at].presence
    @invoice.paid_at = paid_date ? Date.parse(paid_date) : Date.current
    @invoice.save!
    redirect_to @invoice, notice: "Invoice marked as paid on #{I18n.l(@invoice.paid_at)}."
  rescue ArgumentError
    redirect_to @invoice, alert: "Invalid date."
  end

  def mark_unpaid
    @invoice.update!(paid_at: nil)
    redirect_to @invoice, notice: "Invoice marked as unpaid."
  end

  def bulk_send_emails
    invoice_ids = params[:invoice_ids] || []
    invoice_ids = invoice_ids.reject(&:blank?)

    if invoice_ids.empty?
      redirect_to invoices_path, alert: "No invoices selected."
      return
    end

    invoices = Invoice.visible_to(current_user).where(id: invoice_ids, published: true)
    queued_count = 0
    skipped_count = 0

    invoices.each do |invoice|
      if invoice.emailable?
        InvoiceMailer.with(invoice: invoice).customer_email.deliver_later
        queued_count += 1
      else
        skipped_count += 1
      end
    end

    notice = "#{queued_count} emails queued for sending."
    notice += " #{skipped_count} skipped (no recipients)." if skipped_count > 0
    redirect_to invoices_path, notice: notice
  end

protected
  def set_invoice
    @invoice = Invoice.visible_to(current_user).find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(:customer_id, :project_id, :cust_reference, :cust_order, :prelude,
      invoice_lines_attributes: [ :id, :type, :title, :description, :rate, :quantity, :sales_tax_product_class_id, :position, :_destroy ])
  end
end
