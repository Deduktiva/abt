class PeriodicJobRunner
  def self.run_due_jobs
    PeriodicJob.due.find_each do |job|
      new(job).run
    end
  end

  def self.run_job(job_id)
    job = PeriodicJob.find(job_id)
    new(job).run
  end

  def initialize(periodic_job)
    @periodic_job = periodic_job
  end

  def run
    return false unless @periodic_job.runnable?

    # Prevent concurrent runs
    if has_running_execution?
      Rails.logger.warn "Skipping #{@periodic_job.name}: already running"
      return false
    end

    execution = create_execution

    begin
      Rails.logger.info "Starting periodic job: #{@periodic_job.name}"

      # Capture both stdout and job-specific output
      output_buffer = StringIO.new

      # Run the actual job
      job_instance = @periodic_job.job_class.new
      if job_instance.respond_to?(:perform)
        result = job_instance.perform
        output_buffer.puts("Job completed successfully")
        output_buffer.puts("Result: #{result}") if result
      else
        raise "Job class #{@periodic_job.class_name} must respond to #perform"
      end

      # Mark as successful
      execution.mark_as_success!(output_buffer.string)

      # Update next run time
      @periodic_job.update_next_run_time!
      @periodic_job.update!(last_run_at: execution.started_at)

      Rails.logger.info "Completed periodic job: #{@periodic_job.name}"
      true

    rescue => e
      Rails.logger.error "Failed periodic job #{@periodic_job.name}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Mark as failed
      error_message = "#{e.class.name}: #{e.message}"
      execution.mark_as_failed!(error_message, output_buffer&.string)

      # Still update next run time for retries
      @periodic_job.update_next_run_time!
      @periodic_job.update!(last_run_at: execution.started_at)

      false
    end
  end

  private

  def has_running_execution?
    @periodic_job.job_executions.running.exists?
  end

  def create_execution
    @periodic_job.job_executions.create!(
      started_at: Time.current,
      status: 'running'
    )
  end
end
