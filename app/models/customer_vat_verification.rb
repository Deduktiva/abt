class CustomerVatVerification < ApplicationRecord
  belongs_to :customer
  belongs_to :performed_by_user, class_name: "User", optional: true

  scope :latest_first, -> { order(created_at: :desc) }

  def valid_per_vies?
    valid_response == true
  end

  def invalid_per_vies?
    valid_response == false
  end

  def unavailable?
    valid_response.nil?
  end
end
