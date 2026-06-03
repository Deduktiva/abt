module CustomerPortal
  class AcceptancesController < BaseController
    before_action :load_delivery_note

    def show
      return render(:closed) unless @delivery_note&.acceptance_upload_open?
      render :show
    end

    def create
      return render(:closed) unless @delivery_note&.acceptance_upload_open?

      uploaded = params[:acceptance_pdf]
      if (error = file_error(uploaded))
        flash.now[:error] = error
        return render(:show, status: :unprocessable_content)
      end

      begin
        AcceptanceSubmission.submit!(delivery_note: @delivery_note, uploaded_file: uploaded, ip: request.remote_ip)
      rescue AcceptanceSubmission::CapReached
        @closed_reason = :capped
        return render(:closed)
      rescue AcceptanceSubmission::NotOpen
        return render(:closed)
      end

      AcceptanceSubmissionMailer.with(delivery_note: @delivery_note).submitted.deliver_later
      render :success
    end

    private

    def load_delivery_note
      @delivery_note = DeliveryNote.find_by_acceptance_upload_token(params[:token])
    end

    # Returns a user-facing error string, or nil when the file is an acceptable PDF.
    def file_error(file)
      return t("customer_portal.acceptance.errors.missing") if file.blank?
      return t("customer_portal.acceptance.errors.too_large", max: Attachment::MAX_SIZE_BYTES / 1.megabyte) if file.size > Attachment::MAX_SIZE_BYTES
      return t("customer_portal.acceptance.errors.not_pdf") if Attachment.detect_content_type(file.tempfile) != "application/pdf"
      nil
    end
  end
end
