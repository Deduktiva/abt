class DeliveryNotesController < ApplicationController
  include EmailableDocument
  include PublishableDocument
  include DocumentWithLines
  include UploadChecks
  include YearFilteredIndex

  publishable_document :delivery_note, label: "delivery note"
  document_with_lines line_class: DeliveryNoteLine

  EMAIL_FILTERS = %w[all unsent].freeze
  ACCEPTANCE_FILTERS = %w[pending].freeze

  before_action -> { require_permission!("delivery_notes.view") }, only: %i[index show preview preview_email preview_email_html pdf]
  before_action -> { require_permission!("delivery_notes.edit") }, only: %i[
    new create edit update destroy
    publish unpublish send_email upload_acceptance delete_acceptance
    convert_to_invoice bulk_send_emails
  ]
  before_action -> { require_permission!("delivery_notes.review_acceptance") }, only: %i[accept_acceptance reject_acceptance]

  before_action :set_delivery_note, only: %i[show edit update destroy publish preview pdf unpublish upload_acceptance delete_acceptance convert_to_invoice preview_email preview_email_html send_email accept_acceptance reject_acceptance]

  before_action :require_unpublished, only: %i[edit update destroy publish preview]
  before_action :require_unnumbered, only: :destroy
  before_action :require_published, only: %i[pdf unpublish upload_acceptance delete_acceptance convert_to_invoice send_email accept_acceptance reject_acceptance]
  before_action :require_item_line, only: %i[preview preview_email]

  # GET /delivery_notes
  def index
    @email_filter = params[:email_filter].presence_in(EMAIL_FILTERS) || "all"
    @acceptance_filter = params[:acceptance_filter].presence_in(ACCEPTANCE_FILTERS)
    @selected_customer_id = integer_param(:customer_id)

    @delivery_notes = filtered_by_year(DeliveryNote.visible_to(current_user).ordered)

    case @email_filter
    when "unsent"
      @delivery_notes = @delivery_notes.email_unsent.published
    end

    @delivery_notes = @delivery_notes.with_pending_acceptance.published if @acceptance_filter == "pending"

    @delivery_notes = @delivery_notes.where(customer_id: @selected_customer_id) if @selected_customer_id

    @available_years = DeliveryNote.visible_to(current_user).available_years
    @available_customers = DeliveryNote.available_customers(current_user, including: @selected_customer_id)
  end

  # GET /delivery_notes/1
  def show
  end

  # GET /delivery_notes/new
  def new
    @delivery_note = DeliveryNote.new(customer_id: params[:customer_id].presence)
    set_form_options
  end

  # GET /delivery_notes/1/edit
  def edit
    set_form_options
    # A freshly created delivery note arrives with one empty line, title focused, ready to fill in.
    if flash[:build_starter_line]
      @delivery_note.delivery_note_lines.build(type: "item", quantity: 1)
      @autofocus_first_line = true
    end
  end

  # POST /delivery_notes
  def create
    @delivery_note = DeliveryNote.new(delivery_note_params)

    if @delivery_note.save
      redirect_to edit_delivery_note_path(@delivery_note),
        flash: { notice: "Delivery Note was successfully created.", build_starter_line: true }
    else
      render :new, status: :unprocessable_content
    end
  end

  # PUT /delivery_notes/1
  def update
    if @delivery_note.update(delivery_note_params)
      redirect_to @delivery_note, notice: "Delivery Note was successfully updated."
    else
      set_form_options
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /delivery_notes/1
  def destroy
    if @delivery_note.destroy
      redirect_to delivery_notes_url
    else
      redirect_to @delivery_note, alert: @delivery_note.errors.full_messages.to_sentence
    end
  end

  def publish
    publish_document { @delivery_note.publish! }
  end

  def preview
    issuer = Business.get_the_issuer!

    @pdf = DeliveryNoteRenderer.new(@delivery_note, issuer).render

    send_data @pdf, type: "application/pdf", disposition: "inline"
  end

  def pdf
    issuer = Business.get_the_issuer!

    @pdf = DeliveryNoteRenderer.new(@delivery_note, issuer).render

    filename = "#{issuer.short_name}-DeliveryNote-#{@delivery_note.document_number}.pdf"
    send_data @pdf, type: "application/pdf", disposition: "attachment", filename: filename
  end

  def unpublish
    # document_number is intentionally preserved: numbers come from a gap-free
    # sequence (see require_unnumbered). The date is left untouched here, but
    # publish! re-stamps it to the day of the next publish by design (see
    # DeliveryNote#publish!), so a republished note re-dates to its new booking
    # day rather than keeping the old one.
    @delivery_note.update!(published: false)
    flash[:notice] = "Delivery Note has been reverted to draft status."

    respond_to do |format|
      format.html { redirect_to @delivery_note }
    end
  end

  def accept_acceptance
    submission = @delivery_note.acceptance_submissions.find(integer_param(:submission_id))
    submission.accept!(by: current_user)
    redirect_to @delivery_note, notice: "Acceptance document confirmed."
  rescue AcceptanceSubmission::StaleSubmission
    redirect_to @delivery_note, alert: "A newer submission arrived — review it before accepting."
  rescue AcceptanceSubmission::AlreadyAccepted
    redirect_to @delivery_note, alert: "This note already has an accepted acceptance document."
  end

  def reject_acceptance
    submission = @delivery_note.acceptance_submissions.find(integer_param(:submission_id))
    submission.reject!(by: current_user)
    redirect_to @delivery_note, notice: "Submission rejected; the upload link is open again."
  rescue AcceptanceSubmission::StaleSubmission
    redirect_to @delivery_note, alert: "That submission is no longer pending."
  end

  def upload_acceptance
    uploaded_file = params[:acceptance_pdf]

    if (error = acceptance_pdf_error(uploaded_file))
      flash[:error] = error
      redirect_to @delivery_note and return
    end

    # If there's an existing acceptance attachment, delete it first
    if @delivery_note.acceptance_attachment.present?
      old_attachment = @delivery_note.acceptance_attachment
      @delivery_note.update!(acceptance_attachment: nil)
      old_attachment.destroy
    end

    # Create new attachment
    attachment = Attachment.new
    attachment.set_data uploaded_file.read, "application/pdf"
    attachment.filename = uploaded_file.original_filename
    attachment.title = "Acceptance Document for #{@delivery_note.display_name}"

    if attachment.save
      @delivery_note.update!(acceptance_attachment: attachment)
      flash[:notice] = "Acceptance document uploaded successfully."
    else
      flash[:error] = "Failed to upload acceptance document: #{attachment.errors.full_messages.join(', ')}"
    end

    respond_to do |format|
      format.html { redirect_to @delivery_note }
    end
  end

  def delete_acceptance
    if @delivery_note.acceptance_attachment.present?
      old_attachment = @delivery_note.acceptance_attachment
      @delivery_note.update!(acceptance_attachment: nil)
      old_attachment.destroy
      flash[:notice] = "Acceptance document deleted successfully."
    else
      flash[:error] = "No acceptance document to delete."
    end

    respond_to do |format|
      format.html { redirect_to @delivery_note }
    end
  end

  def convert_to_invoice
    invoice = DeliveryNoteInvoiceConverter.new(@delivery_note).convert!
    redirect_to invoice, notice: "Invoice draft created successfully from delivery note."
  rescue DeliveryNoteInvoiceConverter::NotConvertible
    flash[:error] = "This delivery note has already been converted to an invoice."
    redirect_to @delivery_note
  rescue StandardError => e
    flash[:error] = "Failed to convert delivery note to invoice: #{e.message}"
    redirect_to @delivery_note
  end

  def bulk_send_emails
    bulk_send_document_emails(DeliveryNote, ids_param: :delivery_note_ids, redirect_path: delivery_notes_path, noun: "delivery notes") do |delivery_notes|
      queued = skipped = 0

      # Partition by [customer_id, resolved-recipient-set]. Two DNs to the same
      # customer with different project-scoped contacts must NOT be combined,
      # otherwise we leak DN A's recipients onto DN B.
      delivery_notes.group_by { |dn| [ dn.customer_id, dn.email_recipients.sort ] }.each do |(_cid, recipients), dns|
        if recipients.empty?
          skipped += dns.length
          next
        end

        claimed = claim_for_email(dns)
        next if claimed.empty?

        if claimed.length == 1
          token = acceptance_token_for(claimed.first)
          DeliveryNoteMailer.with(delivery_note: claimed.first, acceptance_token: token).customer_email.deliver_later
        else
          acceptance_tokens = claimed.each_with_object({}) do |dn, tokens|
            token = acceptance_token_for(dn)
            tokens[dn.id.to_s] = token if token
          end
          DeliveryNoteMailer.with(delivery_notes: claimed, recipients: recipients, acceptance_tokens: acceptance_tokens).bulk_customer_email.deliver_later
        end
        queued += claimed.length
      end

      [ queued, skipped ]
    end
  end

protected
  def set_delivery_note
    @delivery_note = DeliveryNote.visible_to(current_user).find(params[:id])
  end

  def acceptance_pdf_error(file)
    case pdf_upload_error(file)
    when :missing then "Please select a PDF file to upload."
    when :too_large then "Acceptance document is too large (maximum is #{Attachment::MAX_SIZE_MB} MB)."
    when :wrong_type then "Only PDF files are allowed for acceptance documents (detected: #{Attachment.detect_content_type(file.tempfile)})."
    end
  end

  # EmailableDocument hooks.
  def email_preview_document = @delivery_note

  # Previews carry a non-persisted placeholder token; sending mints a fresh real
  # one. Keeping the two apart means previewing never rotates the live token.
  def email_preview_mail = build_customer_email(skip_attachments: false, acceptance_token: preview_acceptance_token)
  def email_preview_html_mail = build_customer_email(skip_attachments: true, acceptance_token: preview_acceptance_token)
  def email_for_sending = build_customer_email(skip_attachments: false, acceptance_token: acceptance_token_for(@delivery_note))

  def build_customer_email(skip_attachments:, acceptance_token:)
    DeliveryNoteMailer.with(delivery_note: @delivery_note, skip_attachments:, acceptance_token:).customer_email
  end

  def acceptance_token_for(delivery_note)
    return nil if Settings.customer_portal.host.blank?
    delivery_note.acceptance_attachment_id.nil? ? delivery_note.issue_acceptance_upload_token! : nil
  end

  # A non-persisted placeholder token so the email preview shows the acceptance
  # link the customer will receive, without minting or rotating a real token.
  def preview_acceptance_token
    return nil if Settings.customer_portal.host.blank?
    @delivery_note&.acceptance_attachment_id.nil? ? "preview" : nil
  end

  # Document numbers are issued from a gap-free sequence; once assigned they
  # must not vanish, even if the delivery note was later unpublished.
  def require_unnumbered
    return true if @delivery_note.document_number.blank?

    flash[:error] = "Delivery notes with an assigned document number can not be deleted."
    redirect_to @delivery_note
    false
  end

  def delivery_note_params
    params.expect(delivery_note: [
      :customer_id, :project_id, :cust_reference, :cust_order, :internal_reference, :prelude, :delivery_start_date, :delivery_end_date,
      delivery_note_lines_attributes: [ [ :id, :type, :title, :description, :position, :quantity, :_destroy ] ]
    ])
  end
end
