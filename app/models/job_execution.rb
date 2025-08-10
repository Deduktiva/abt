class JobExecution < ApplicationRecord
  belongs_to :periodic_job

  validates :status, presence: true, inclusion: { in: %w[running success failed] }
  validates :started_at, presence: true

  scope :recent, -> { order(started_at: :desc) }
  scope :successful, -> { where(status: 'success') }
  scope :failed, -> { where(status: 'failed') }
  scope :running, -> { where(status: 'running') }

  def duration
    return nil unless finished_at
    finished_at - started_at
  end

  def duration_humanized
    return 'N/A' unless duration
    return "#{duration.round(2)}s" if duration < 60
    return "#{(duration / 60).round(1)}m" if duration < 3600
    "#{(duration / 3600).round(1)}h"
  end

  def running?
    status == 'running'
  end

  def success?
    status == 'success'
  end

  def failed?
    status == 'failed'
  end

  def mark_as_success!(output = nil)
    update!(
      status: 'success',
      finished_at: Time.current,
      output: output,
      error_message: nil
    )
  end

  def mark_as_failed!(error_message, output = nil)
    update!(
      status: 'failed',
      finished_at: Time.current,
      output: output,
      error_message: error_message
    )
  end
end
