class IssuerCompaniesController < ApplicationController
  before_action :set_issuer_company

  def show
  end

  def png_logo
    if @issuer_company.png_logo.present?
      send_data @issuer_company.png_logo, type: 'image/png', disposition: 'inline'
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
      file = params[:issuer_company][:pdf_logo_file]
      params_hash[:pdf_logo] = file.read
    end

    # Handle PNG logo upload
    if params[:issuer_company][:png_logo_file].present?
      file = params[:issuer_company][:png_logo_file]
      params_hash[:png_logo] = file.read
    end

    if @issuer_company.update(params_hash)
      redirect_to issuer_company_path, notice: 'Issuer company was successfully updated.'
    else
      render :edit
    end
  end

  private

  def set_issuer_company
    @issuer_company = IssuerCompany.get_the_issuer! || IssuerCompany.new
  end

  def issuer_company_params
    params.require(:issuer_company).permit(
      :short_name, :legal_name, :vat_id, :address,
      :bankaccount_bank, :bankaccount_bic, :bankaccount_number,
      :document_contact_line1, :document_contact_line2,
      :document_accent_color,
      :invoice_footer,
      :currency,
      :document_email_from,
      :document_email_auto_bcc,
      :pdf_logo, :pdf_logo_width, :pdf_logo_height, :png_logo
    )
  end
end
