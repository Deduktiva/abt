class IssuerCompany < ApplicationRecord

  # This app requires that there is exactly *one* issuer_company in the database.
  def self.get_the_issuer!
    self.where(:active => true).first
  end
end
