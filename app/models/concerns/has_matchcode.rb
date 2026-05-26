module HasMatchcode
  extend ActiveSupport::Concern

  MATCHCODE_FORMAT = /\A\S{2,}\z/

  included do
    validates :matchcode, presence: true, uniqueness: { case_sensitive: false },
              format: { with: MATCHCODE_FORMAT }
  end
end
