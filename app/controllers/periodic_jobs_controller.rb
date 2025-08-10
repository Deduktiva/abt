class PeriodicJobsController < ApplicationController
  before_action :set_periodic_job, only: [:show, :run]

  def index
    @periodic_jobs = PeriodicJob.order(:name)
  end

  def show
    @recent_executions = @periodic_job.job_executions.recent.limit(20)
  end

  def run
    begin
      success = PeriodicJobRunner.run_job(@periodic_job.id)

      if success
        flash[:notice] = "Job '#{@periodic_job.name}' started successfully."
      else
        flash[:alert] = "Failed to start job '#{@periodic_job.name}'. Check if it's already running or has configuration issues."
      end
    rescue => e
      flash[:alert] = "Error starting job: #{e.message}"
    end

    redirect_to @periodic_job
  end

  private

  def set_periodic_job
    @periodic_job = PeriodicJob.find(params[:id])
  end
end
