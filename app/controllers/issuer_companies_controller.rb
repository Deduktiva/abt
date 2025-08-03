class IssuerCompaniesController < ApplicationController
  before_action :set_issuer_company

  def show
  end

  def edit
  end

  def update
    if @issuer_company.update(issuer_company_params)
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
    params.require(:issuer_company).permit(:active, :short_name, :legal_name, :vat_id, :address,
                                           :bankaccount_bank, :bankaccount_bic, :bankaccount_number,
                                           :document_contact_line1, :document_contact_line2,
                                           :document_accent_color, :invoice_footer, :currency)
  end
end
