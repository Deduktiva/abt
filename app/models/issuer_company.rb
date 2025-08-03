class IssuerCompany < ApplicationRecord
  validates :short_name, presence: true
  validates :legal_name, presence: true

  # This app requires that there is exactly *one* issuer_company in the database.
  def self.get_the_issuer!
    self.where(:active => true).first
  end
end
