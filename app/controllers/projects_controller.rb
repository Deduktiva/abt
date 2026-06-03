class ProjectsController < ApplicationController
  include SearchableDropdownIndex

  before_action -> { require_permission!("projects.view") }, only: [ :index, :show ]
  before_action -> { require_permission!("projects.edit") }, only: [ :new, :create, :edit, :update, :destroy ]
  before_action :set_project, only: %i[show edit update destroy]
  before_action :load_customer_options, only: [ :new, :create, :edit, :update ]

  # GET /projects
  def index
    @projects = filtered_by_active(Project.visible_to(current_user))

    # The dependent project dropdown (searchable_dropdown) scopes options to the
    # chosen customer, always including reusable (customer-less) projects.
    if params[:customer_id].present?
      @projects = @projects.where("bill_to_customer_id = ? OR bill_to_customer_id IS NULL", params[:customer_id])
    end

    @projects = @projects.order(:matchcode, :description)
    respond_to_index_or_dropdown
  end

  # GET /projects/1
  def show
  end

  # GET /projects/new
  def new
    @project = Project.new
    teams_available = available_teams
    @project.team_id = teams_available.first&.id if teams_available.size == 1
  end

  # GET /projects/1/edit
  def edit
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
    if @project.update(projects_params)
      redirect_to @project, notice: "Project was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /projects/1
  def destroy
    if @project.destroy
      redirect_to projects_url, notice: "Project was successfully deleted."
    else
      redirect_to projects_url, alert: @project.errors.full_messages.join(", ")
    end
  end

private
  def set_project
    @project = Project.visible_to(current_user).find(params[:id])
  end

  def projects_params
    params.require(:project).permit(:bill_to_customer_id, :description, :matchcode, :active, :team_id, :department)
  end

  def load_customer_options
    @customer_options = Customer.visible_to(current_user).order(:name).to_a
  end
end
