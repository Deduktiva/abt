class AttachmentsController < ApplicationController
  INLINE_CONTENT_TYPES = %w[application/pdf].freeze

  def show
    @attachment = Attachment.find(params[:id])
    served_type = @attachment.safe_content_type
    disposition = INLINE_CONTENT_TYPES.include?(served_type) ? 'inline' : 'attachment'
    response.set_header('X-Content-Type-Options', 'nosniff')
    send_data @attachment.data,
              filename: @attachment.filename,
              type: served_type,
              disposition: disposition
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
      flash[:error] = "Saving attachment failed: #{@attachment.errors.full_messages.join(', ')}"
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
