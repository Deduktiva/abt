module CustomerPortal
  # Base for all customer-facing, unauthenticated pages on the customer portal host.
  # No app auth, minimal issuer-only layout, CSRF still enforced.
  class BaseController < ActionController::Base
    protect_from_forgery with: :exception
    layout "customer_portal"

    before_action :set_issuer
    around_action :use_request_locale

    private

    def set_issuer
      @issuer = IssuerCompany.get_the_issuer!
    end

    # Customer portal pages are unauthenticated, so we localize from the
    # visitor's Accept-Language header (matched against the supported app
    # languages), independent of any per-customer language setting.
    def use_request_locale(&block)
      I18n.with_locale(preferred_locale, &block)
    end

    def preferred_locale
      supported = Language.pluck(:iso_code)
      requested = request.env["HTTP_ACCEPT_LANGUAGE"].to_s.scan(/[a-z]{2}/i).map(&:downcase)
      (requested.find { |code| supported.include?(code) } || I18n.default_locale).to_s
    end
  end
end
