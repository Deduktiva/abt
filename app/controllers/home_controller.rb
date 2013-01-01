class HomeController < ApplicationController
  def index
    @stats = {
      :customers => Customer.count
    }
    respond_to do |format|
      format.html
      format.json { render :json => @stats }
    end
  end
end
