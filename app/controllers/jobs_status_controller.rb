class JobsStatusController < ApplicationController
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
    @next_recurring_runs = SolidQueue::RecurringExecution
                             .where(task_key: @recurring_tasks.map(&:key))
                             .group(:task_key)
                             .minimum(:run_at)

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
