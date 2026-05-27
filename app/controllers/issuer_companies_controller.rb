class IssuerCompaniesController < ApplicationController
  MAX_LOGO_SIZE_BYTES = 2.megabytes

  before_action -> { require_permission!("issuer_company.view") }, only: [ :show, :png_logo ]
  before_action -> { require_permission!("issuer_company.edit") }, only: [ :edit, :update ]
  before_action :set_issuer_company

  def show
  end

  def png_logo
    if @issuer_company.png_logo.present?
      response.set_header("X-Content-Type-Options", "nosniff")
      send_data @issuer_company.png_logo, type: "image/png", disposition: "inline"
    else
      head :not_found
    end
  end

  def edit
  end

  def update
    # Handle file uploads
    params_hash = issuer_company_params.to_h

    # Handle PDF logo upload
    if params[:issuer_company][:pdf_logo_file].present?
      data = read_validated_logo(params[:issuer_company][:pdf_logo_file], "application/pdf", "PDF") or return
      params_hash[:pdf_logo] = data
    end

    # Handle PNG logo upload
    if params[:issuer_company][:png_logo_file].present?
      data = read_validated_logo(params[:issuer_company][:png_logo_file], "image/png", "PNG") or return
      params_hash[:png_logo] = data
    end

    if @issuer_company.update(params_hash)
      redirect_to issuer_company_path, notice: "Issuer company was successfully updated."
    else
      render :edit
    end
  end

  private

  def read_validated_logo(file, expected_type, label)
    if file.size > MAX_LOGO_SIZE_BYTES
      redirect_to edit_issuer_company_path,
                  alert: "#{label} logo is too large (maximum is #{MAX_LOGO_SIZE_BYTES / 1.megabyte} MB)."
      return nil
    end
    detected = Attachment.detect_content_type(file.tempfile)
    if detected != expected_type
      redirect_to edit_issuer_company_path,
                  alert: "#{label} logo: file content is not #{expected_type} (detected: #{detected})."
      return nil
    end
    file.read
  end

  def set_issuer_company
    @issuer_company = IssuerCompany.get_the_issuer! || IssuerCompany.new
  end

  def issuer_company_params
    params.require(:issuer_company).permit(
      :short_name, :legal_name, :vat_id, :address, :country_iso2,
      :bankaccount_bank, :bankaccount_bic, :bankaccount_number,
      :document_contact_line1, :document_contact_line2,
      :document_accent_color,
      :invoice_footer,
      :currency,
      :document_email_from,
      :document_email_auto_bcc,
      :pdf_logo_width, :pdf_logo_height,
      :vat_id_recheck_days
    )
  end
end
