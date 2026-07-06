class InvoicesController < ApplicationController
  include EmailableDocument
  include PublishableDocument
  include DocumentWithLines

  publishable_document :invoice, label: "invoice"
  document_with_lines line_class: InvoiceLine

  before_action -> { require_permission!("invoices.view") }, only: %i[index show preview preview_email preview_email_html]
  before_action -> { require_permission!("invoices.edit") }, only: %i[
    new create edit update destroy
    publish send_email mark_paid mark_unpaid bulk_send_emails import_lines
  ]

  before_action :set_invoice, only: %i[show edit update destroy publish preview preview_email preview_email_html send_email mark_paid mark_unpaid import_lines]

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
    @available_customers = Invoice.available_customers(current_user, including: @selected_customer_id)
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
    # A freshly created invoice arrives with one empty line, title focused, ready to fill in.
    if flash[:build_starter_line]
      @invoice.invoice_lines.build(type: "item", amount: 0, rate: 0, quantity: 1)
      @autofocus_first_line = true
    end
  end

  # POST /invoices
  def create
    @invoice = Invoice.new(invoice_params)

    if @invoice.save
      redirect_to edit_invoice_path(@invoice),
        flash: { notice: "Invoice was successfully created.", build_starter_line: true }
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
    if @invoice.destroy
      redirect_to invoices_url
    else
      redirect_to @invoice, alert: @invoice.errors.full_messages.to_sentence
    end
  end

  def publish
    publish_document { InvoicePublisher.new(@invoice, IssuerCompany.get_the_issuer!).publish! }
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

  # Parses an uploaded Tyme CSV into invoice line attributes, returned as JSON for
  # the editor to inject. Read-only — nothing is persisted here.
  def import_lines
    file = params[:file]
    raise ArgumentError, "No file uploaded" if file.blank?

    lines = TymeCsvImporter.new(file, customer: @invoice.customer).lines
    render json: { lines: lines }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  def bulk_send_emails
    bulk_send_document_emails(Invoice, ids_param: :invoice_ids, redirect_path: invoices_path, noun: "invoices") do |invoices|
      queued = skipped = 0
      invoices.each do |invoice|
        if invoice.emailable?
          InvoiceMailer.with(invoice: invoice).customer_email.deliver_later
          queued += 1
        else
          skipped += 1
        end
      end
      [ queued, skipped ]
    end
  end

protected
  def set_invoice
    @invoice = Invoice.visible_to(current_user).find(params[:id])
  end

  # EmailableDocument hooks.
  def email_preview_document = @invoice

  def email_preview_mail = build_customer_email(skip_attachments: false)
  def email_preview_html_mail = build_customer_email(skip_attachments: true)
  def email_for_sending = build_customer_email(skip_attachments: false)

  def build_customer_email(skip_attachments:)
    InvoiceMailer.with(invoice: @invoice, skip_attachments:).customer_email
  end

  def invoice_params
    params.require(:invoice).permit(:customer_id, :project_id, :cust_reference, :cust_order, :internal_reference, :prelude,
      invoice_lines_attributes: [ :id, :type, :title, :description, :rate, :quantity, :sales_tax_product_class_id, :position, :_destroy ])
  end
end
