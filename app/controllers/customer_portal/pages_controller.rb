module CustomerPortal
  class PagesController < BaseController
    def root
      head :ok
    end

    def not_found
      head :not_found
    end
  end
end
