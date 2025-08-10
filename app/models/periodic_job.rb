class PeriodicJob < ApplicationRecord
  has_many :job_executions, -> { order(started_at: :desc) }, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :class_name, presence: true
  validates :schedule, presence: true
  validates :enabled, inclusion: { in: [true, false] }

  scope :enabled, -> { where(enabled: true) }
  scope :due, -> { enabled.where('next_run_at IS NULL OR next_run_at <= ?', Time.current) }

  def last_execution
    job_executions.first
  end

  def last_successful_execution
    job_executions.where(status: 'success').first
  end

  def status
    return 'disabled' unless enabled?

    last_exec = last_execution
    return 'never_run' unless last_exec

    case last_exec.status
    when 'running'
      'running'
    when 'success'
      overdue? ? 'overdue' : 'success'
    when 'failed'
      'failed'
    else
      'unknown'
    end
  end

  def overdue?
    return false unless next_run_at
    next_run_at < Time.current
  end

  def due?
    return false unless enabled?
    next_run_at.nil? || next_run_at <= Time.current
  end

  def calculate_next_run_time(from_time = Time.current)
    # Simple cron-like parsing - extend as needed
    case schedule
    when /^(\d+)m$/ # Every X minutes
      from_time + $1.to_i.minutes
    when /^(\d+)h$/ # Every X hours
      from_time + $1.to_i.hours
    when /^(\d+)d$/ # Every X days
      from_time + $1.to_i.days
    when 'hourly'
      from_time + 1.hour
    when 'daily'
      from_time + 1.day
    when 'weekly'
      from_time + 1.week
    else
      # Default to 1 hour if schedule format is not recognized
      from_time + 1.hour
    end
  end

  def update_next_run_time!
    update!(next_run_at: calculate_next_run_time)
  end

  def job_class
    @job_class ||= class_name.constantize
  rescue NameError
    nil
  end

  def runnable?
    enabled? && job_class.present?
  end
end
