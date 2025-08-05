class ProjectsController < ApplicationController
  # GET /projects
  # GET /projects.json
  def index
    params[:filter] ||= 'active'
    @projects = case params[:filter]
                 when 'all'
                   Project.order(:matchcode)
                 when 'inactive'
                   Project.inactive.order(:matchcode)
                 else
                   Project.active.order(:matchcode)
                 end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @projects }
    end
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    @project = Project.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @project }
    end
  end

  # GET /projects/new
  # GET /projects/new.json
  def new
    @project = Project.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @project }
    end
  end

  # GET /projects/1/edit
  def edit
    @project = Project.find(params[:id])
  end

  # POST /projects
  # POST /projects.json
  def create
    @project = Project.new(projects_params)

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("projects", partial: "projects/project", locals: { project: @project }) }
        format.json { render json: @project, status: :created, location: @project }
      else
        format.html { render :new, status: :unprocessable_content }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("project_form", partial: "projects/form", locals: { project: @project }) }
        format.json { render json: @project.errors, status: :unprocessable_content }
      end
    end
  end

  # PUT /projects/1
  # PUT /projects/1.json
  def update
    @project = Project.find(params[:id])

    respond_to do |format|
      if @project.update(projects_params)
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@project), partial: "projects/project", locals: { project: @project }) }
        format.json { head :no_content }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("project_form", partial: "projects/form", locals: { project: @project }) }
        format.json { render json: @project.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    @project = Project.find(params[:id])

    respond_to do |format|
      if @project.destroy
        format.html { redirect_to projects_url, notice: 'Project was successfully deleted.' }
        format.json { head :no_content }
      else
        format.html { redirect_to projects_url, alert: @project.errors.full_messages.join(', ') }
        format.json { render json: @project.errors, status: :unprocessable_content }
      end
    end
  end

private
  def projects_params
    params.require(:project).permit(:bill_to_customer_id, :description, :matchcode, :active)
  end
end
