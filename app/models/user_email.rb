class UserEmail < ApplicationRecord
  CONFIRMATION_VALIDITY = 48.hours

  belongs_to :user

  validates :address, presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            uniqueness: { case_sensitive: false }

  before_validation :normalize_address

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :pending, -> { where(confirmed_at: nil) }

  def confirmed?
    confirmed_at.present?
  end

  def generate_confirmation_token!
    plaintext = SecureRandom.urlsafe_base64(32)
    update!(
      confirmation_token_digest: self.class.digest_token(plaintext),
      confirmation_expires_at: CONFIRMATION_VALIDITY.from_now
    )
    plaintext
  end

  def confirm!
    update!(
      confirmed_at: Time.current,
      confirmation_token_digest: nil,
      confirmation_expires_at: nil
    )
  end

  def self.find_by_confirmation_token(plaintext)
    return nil if plaintext.blank?
    where(confirmation_token_digest: digest_token(plaintext))
      .where('confirmation_expires_at > ?', Time.current)
      .where(confirmed_at: nil)
      .first
  end

  def self.digest_token(plaintext)
    Digest::SHA256.hexdigest(plaintext)
  end

  private

  def normalize_address
    self.address = address.to_s.strip.downcase if address.present?
  end
end
