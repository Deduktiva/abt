class ProjectsController < ApplicationController
  # GET /projects
  # GET /projects.json
  def index
    params[:filter] ||= 'active'

    @projects = case params[:filter]
                 when 'all'
                   Project.all
                 when 'inactive'
                   Project.inactive
                 else
                   Project.active
                 end

    # Filters for AJAX requests
    if params[:customer_id].present?
      want_reusable_projects = params[:include_reusable].present? && params[:include_reusable] == 'true'

      if want_reusable_projects
        @projects = @projects.where(
          'bill_to_customer_id = ? OR bill_to_customer_id IS NULL',
          params[:customer_id]
        )
      else
        @projects = @projects.where(bill_to_customer_id: params[:customer_id])
      end
    end

    @projects = @projects.order(:matchcode, :description)

    respond_to do |format|
      format.html # index.html.erb
      format.turbo_stream { render :filter_options }
      format.json {
        render json: @projects.map { |project|
          {
            id: project.id,
            name: project.display_name,
            matchcode: project.matchcode,
            description: project.description,
            is_reusable: project.bill_to_customer_id.nil?
          }
        }
      }
    end
  end

  # GET /projects/1
  def show
    @project = Project.find(params[:id])
  end

  # GET /projects/new
  def new
    @project = Project.new
  end

  # GET /projects/1/edit
  def edit
    @project = Project.find(params[:id])
  end

  # POST /projects
  def create
    @project = Project.new(projects_params)

    if @project.save
      redirect_to @project, notice: 'Project was successfully created.'
    else
      render :new, status: :unprocessable_content
    end
  end

  # PUT /projects/1
  def update
    @project = Project.find(params[:id])

    if @project.update(projects_params)
      redirect_to @project, notice: 'Project was successfully updated.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /projects/1
  def destroy
    @project = Project.find(params[:id])

    if @project.destroy
      redirect_to projects_url, notice: 'Project was successfully deleted.'
    else
      redirect_to projects_url, alert: @project.errors.full_messages.join(', ')
    end
  end

private
  def projects_params
    params.require(:project).permit(:bill_to_customer_id, :description, :matchcode, :active)
  end
end
