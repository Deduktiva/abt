class IssuerCompany < ApplicationRecord
  validates :short_name, presence: true
  validates :legal_name, presence: true
  validates :document_accent_color,
            format: { with: /\A#[0-9a-fA-F]{3,8}\z/, message: 'must be a hex color like #rrggbb' },
            allow_blank: true

  # This app requires that there is exactly *one* issuer_company in the database.
  def self.get_the_issuer!
    self.where(:active => true).first
  end
end
