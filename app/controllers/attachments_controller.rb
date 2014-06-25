class AttachmentsController < ApplicationController
  def show
    @attachment = Attachment.find(params[:id])
    send_data @attachment.data,
              :filename => @attachment.filename,
              :type => @attachment.content_type,
              :title => @attachment.title
  end

  def create
    return if params[:attachment].blank? or params[:attachment][:attachment].blank?

    @attachment = Attachment.new
    @attachment.uploaded_file = params[:attachment][:attachment]
    @attachment.title = params[:attachment][:title]

    if @attachment.save
      flash[:notice] = "Attachment created."
      redirect_to :action => "index"  # FIXME: do something useful
    else
      flash[:error] = "Saving attachment failed."
      render :action => "new"
    end
  end

  def new
    @attachment = Attachment.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @customer }
    end
  end
end
