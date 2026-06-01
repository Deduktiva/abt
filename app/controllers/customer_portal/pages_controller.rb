module CustomerPortal
  class PagesController < BaseController
    def root
      render :root
    end

    def not_found
      render :not_found, status: :not_found
    end
  end
end
