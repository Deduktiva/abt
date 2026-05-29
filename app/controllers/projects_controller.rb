class ProjectsController < ApplicationController
  before_action -> { require_permission!("projects.view") }, only: [ :index, :show ]
  before_action -> { require_permission!("projects.edit") }, only: [ :new, :create, :edit, :update, :destroy ]
  before_action :load_customer_options, only: [ :new, :create, :edit, :update ]

  # GET /projects
  def index
    params[:filter] ||= "active"

    base = Project.visible_to(current_user)
    @projects = case params[:filter]
    when "all"
      base
    when "inactive"
      base.where(active: false)
    else
      base.where(active: true)
    end

    # Filters for AJAX requests
    if params[:customer_id].present?
      want_reusable_projects = params[:include_reusable].present? && params[:include_reusable] == "true"

      if want_reusable_projects
        @projects = @projects.where(
          "bill_to_customer_id = ? OR bill_to_customer_id IS NULL",
          params[:customer_id]
        )
      else
        @projects = @projects.where(bill_to_customer_id: params[:customer_id])
      end
    end

    @projects = @projects.order(:matchcode, :description)

    respond_to do |format|
      format.html # index.html.erb
      # Only the searchable_dropdown Stimulus controller hits this branch; it sets
      # X-Requested-With explicitly. Turbo's navigation Accept also lists turbo_stream,
      # so without this guard the post-delete redirect would render dropdown options
      # into a missing target and leave the index page stale.
      format.turbo_stream { render :filter_options } if request.xhr?
    end
  end

  # GET /projects/1
  def show
    @project = Project.visible_to(current_user).find(params[:id])
  end

  # GET /projects/new
  def new
    @project = Project.new
    teams_available = available_teams
    @project.team_id = teams_available.first&.id if teams_available.size == 1
  end

  # GET /projects/1/edit
  def edit
    @project = Project.visible_to(current_user).find(params[:id])
  end

  # POST /projects
  def create
    @project = Project.new(projects_params)

    if @project.save
      redirect_to @project, notice: "Project was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PUT /projects/1
  def update
    @project = Project.visible_to(current_user).find(params[:id])

    if @project.update(projects_params)
      redirect_to @project, notice: "Project was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /projects/1
  def destroy
    @project = Project.visible_to(current_user).find(params[:id])

    if @project.destroy
      redirect_to projects_url, notice: "Project was successfully deleted."
    else
      redirect_to projects_url, alert: @project.errors.full_messages.join(", ")
    end
  end

private
  def projects_params
    params.require(:project).permit(:bill_to_customer_id, :description, :matchcode, :active, :team_id, :department)
  end

  def load_customer_options
    @customer_options = Customer.visible_to(current_user).order(:name).to_a
  end
end
