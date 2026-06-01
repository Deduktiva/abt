module CustomerPortal
  # Base for all customer-facing, unauthenticated pages on the customer portal host.
  # No app auth, minimal issuer-only layout, CSRF still enforced.
  class BaseController < ActionController::Base
    protect_from_forgery with: :exception
    layout "customer_portal"

    before_action :set_issuer

    private

    def set_issuer
      @issuer = IssuerCompany.get_the_issuer!
    end
  end
end
