# Periodic Jobs System

This application includes a custom periodic jobs system for running background tasks on a schedule.

## Features

- **Database-driven job definitions**: Jobs are stored in the database with schedule, status tracking
- **Execution history**: Every job run is logged with output, duration, and status
- **Web UI**: Monitor and manually trigger jobs through the web interface
- **Manual execution**: Run jobs on-demand via web UI or rake tasks
- **Flexible scheduling**: Simple schedule syntax (30m, 2h, daily, etc.)

## Job Management

### Web Interface

- Visit `/periodic_jobs` to view all jobs and their status
- Click on a job to see detailed execution history
- Use "Run Now" button to manually trigger jobs

### Command Line

```bash
# List all jobs with status
bundle exec rake periodic_jobs:list

# Run all due jobs (use this in cron)
bundle exec rake periodic_jobs:run_due

# Run a specific job by name
bundle exec rake periodic_jobs:run_job["Job Name"]
```

## Cron Setup

Add to your crontab to run due jobs every 5 minutes:

```bash
# Check for due periodic jobs every 5 minutes
*/5 * * * * cd /path/to/abt && bundle exec rake periodic_jobs:run_due >> log/periodic_jobs.log 2>&1
```

Or every minute for more frequent checks:

```bash
# Check for due periodic jobs every minute
* * * * * cd /path/to/abt && bundle exec rake periodic_jobs:run_due >> log/periodic_jobs.log 2>&1
```

## Schedule Format

The system supports simple schedule formats:

- `30m` - Every 30 minutes
- `2h` - Every 2 hours
- `daily` - Every day
- `hourly` - Every hour
- `weekly` - Every week

## Creating New Jobs

1. Create a job class inheriting from `BasePeriodicJob`:

```ruby
class MyCustomJob < BasePeriodicJob
  def perform
    log "Starting my custom job"
    
    # Your job logic here
    result = do_something()
    
    log "Job completed successfully"
    result # Optional return value
  end
  
  private
  
  def do_something
    # Implementation
  end
end
```

2. Add the job to the database:

```ruby
PeriodicJob.create!(
  name: 'My Custom Job',
  description: 'Does something important periodically',
  class_name: 'MyCustomJob',
  schedule: '30m',
  enabled: true,
  next_run_at: 1.hour.from_now
)
```

## Job Status

Jobs can have the following statuses:

- **disabled** - Job is disabled and won't run
- **never_run** - Job has been created but never executed
- **running** - Job is currently executing
- **success** - Last execution was successful
- **failed** - Last execution failed
- **overdue** - Job missed its scheduled run time

## Execution History

The system maintains a complete history of job executions including:

- Start and finish times
- Execution duration
- Status (running/success/failed)
- Output logs
- Error messages (if failed)

This information is available in the web interface and can be queried programmatically through the `JobExecution` model.

## Monitoring

- Use the web interface to monitor job health and execution history
- Failed jobs are highlighted in red
- Overdue jobs show warning indicators
- Detailed output and error logs are available for each execution

## Best Practices

1. **Idempotency**: Design jobs to be safe to run multiple times
2. **Logging**: Use `log()` and `log_error()` methods for proper output capture
3. **Error handling**: Let exceptions bubble up to be caught by the runner
4. **Timeouts**: Keep job execution time reasonable to avoid blocking
5. **Monitoring**: Regularly check job status through the web interface
