class JobsStatusController < ApplicationController
  before_action -> { require_permission!("jobs_status.view") }

  STALE_HEARTBEAT_THRESHOLD = 1.minute
  RECENT_FAILED_LIMIT = 20
  RECENT_FINISHED_LIMIT = 10

  def show
    @processes = SolidQueue::Process.order(:kind, :name).to_a
    @stale_threshold = STALE_HEARTBEAT_THRESHOLD.ago

    @counts = {
      ready: SolidQueue::ReadyExecution.count,
      scheduled: SolidQueue::ScheduledExecution.count,
      claimed: SolidQueue::ClaimedExecution.count,
      blocked: SolidQueue::BlockedExecution.count,
      failed: SolidQueue::FailedExecution.count,
      finished: SolidQueue::Job.finished.count
    }

    @recurring_tasks = SolidQueue::RecurringTask.order(:key).to_a

    @failed_jobs = SolidQueue::FailedExecution
                     .includes(:job)
                     .order(created_at: :desc)
                     .limit(RECENT_FAILED_LIMIT)

    @recent_finished_jobs = SolidQueue::Job
                              .finished
                              .order(finished_at: :desc)
                              .limit(RECENT_FINISHED_LIMIT)

    @queue_adapter = Rails.application.config.active_job.queue_adapter
  end
end
