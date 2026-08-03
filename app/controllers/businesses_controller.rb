class BusinessesController < ApplicationController
  include UploadChecks

  MAX_LOGO_SIZE_BYTES = 2.megabytes

  allow_without_permission_check only: [ :png_logo ]
  before_action -> { require_permission!("business.view") }, only: [ :show ]
  before_action -> { require_permission!("business.edit") }, only: [ :edit, :update ]
  before_action :set_business

  def show
  end

  def png_logo
    if @business.png_logo.present?
      response.set_header("X-Content-Type-Options", "nosniff")
      send_data @business.png_logo, type: "image/png", disposition: "inline"
    else
      head :not_found
    end
  end

  def edit
  end

  def update
    # Handle file uploads
    params_hash = business_params.to_h

    # Handle PDF logo upload
    if params[:business][:pdf_logo_file].present?
      data = read_validated_logo(params[:business][:pdf_logo_file], "application/pdf", "PDF") or return
      params_hash[:pdf_logo] = data
    end

    # Handle PNG logo upload
    if params[:business][:png_logo_file].present?
      data = read_validated_logo(params[:business][:png_logo_file], "image/png", "PNG") or return
      params_hash[:png_logo] = data
    end

    if @business.update(params_hash)
      redirect_to business_path, notice: "Business was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def read_validated_logo(file, expected_type, label)
    error = logo_upload_error(file, expected_type, label)
    if error
      redirect_to edit_business_path, alert: error
      return nil
    end
    file.read
  end

  def logo_upload_error(file, expected_type, label)
    case upload_error(file, expected_type:, max_bytes: MAX_LOGO_SIZE_BYTES)
    when :missing then "#{label} logo: please select a #{label} file to upload."
    when :too_large then "#{label} logo is too large (maximum is #{MAX_LOGO_SIZE_BYTES / 1.megabyte} MB)."
    when :wrong_type then "#{label} logo: file content is not #{expected_type} (detected: #{Attachment.detect_content_type(file.tempfile)})."
    end
  end

  def set_business
    @business = Business.get_the_issuer! ||
      raise(ActiveRecord::RecordNotFound, "No active business; run bin/rails db:seed to create one")
  end

  def business_params
    params.require(:business).permit(
      :short_name, :legal_name, :vat_id, :address, :country_iso2,
      :bankaccount_bank, :bankaccount_bic, :bankaccount_number,
      :document_contact_line1, :document_contact_line2,
      :document_accent_color,
      :invoice_footer,
      :offer_validity_days, :offer_footer,
      :currency,
      :money_decimal_places,
      :document_email_from,
      :document_email_reply_to,
      :document_email_auto_bcc,
      :pdf_logo_width, :pdf_logo_height,
      :vat_id_recheck_days,
      :reporting_email,
      :website_url
    )
  end
end
