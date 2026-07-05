class IssuerCompany < ApplicationRecord
  validates :short_name, presence: true
  validates :legal_name, presence: true
  validates :country_iso2, presence: true, inclusion: { in: ISO3166::Country.codes, message: "must be a valid country" }
  validates :document_accent_color,
            format: { with: /\A#[0-9a-fA-F]{3,8}\z/, message: "must be a hex color like #rrggbb" },
            allow_blank: true
  validates :vat_id_recheck_days, numericality: { only_integer: true, greater_than: 0 }
  validates :offer_validity_days, numericality: { greater_than: 0 }
  # 0..4 covers all ISO 4217 minor units (2 typical, 0 for JPY, 3 for KWD, 4 for
  # CLF). Bounding it also keeps stored values exact on SQLite's float-backed
  # decimal columns.
  validates :money_decimal_places, numericality: { only_integer: true, in: 0..4 }
  validates :reporting_email, presence: true
  validates :reporting_email, :document_email_from, :document_email_auto_bcc, :document_email_reply_to,
            format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :website_url, allow_blank: true,
            format: { with: %r{\Ahttps?://\S+\z}i, message: "must be a valid http:// or https:// URL" }
  normalizes :website_url, with: ->(url) { url.strip }

  # This app requires that there is exactly *one* issuer_company in the database.
  def self.get_the_issuer!
    self.where(active: true).first
  end
end
