module CustomerPortal
  class AcceptancesController < BaseController
    include UploadChecks

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
      case pdf_upload_error(file)
      when :missing then t("customer_portal.acceptance.errors.missing")
      when :too_large then t("customer_portal.acceptance.errors.too_large", max: Attachment::MAX_SIZE_MB)
      when :wrong_type then t("customer_portal.acceptance.errors.not_pdf")
      end
    end
  end
end
