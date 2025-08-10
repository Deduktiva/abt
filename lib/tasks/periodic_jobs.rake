namespace :periodic_jobs do
  desc "Run all due periodic jobs"
  task run_due: :environment do
    puts "Checking for due periodic jobs..."

    due_jobs = PeriodicJob.due

    if due_jobs.empty?
      puts "No due jobs found."
    else
      puts "Found #{due_jobs.count} due job(s):"
      due_jobs.each do |job|
        puts "- #{job.name} (#{job.schedule})"
      end

      puts "\nRunning due jobs..."
      PeriodicJobRunner.run_due_jobs
      puts "Done."
    end
  end

  desc "List all periodic jobs with their status"
  task list: :environment do
    jobs = PeriodicJob.order(:name)

    puts "Periodic Jobs:"
    puts "=" * 80
    puts "%-30s %-10s %-15s %-20s" % ["Name", "Schedule", "Status", "Next Run"]
    puts "-" * 80

    jobs.each do |job|
      next_run = job.next_run_at ? job.next_run_at.strftime("%Y-%m-%d %H:%M") : "Not scheduled"
      puts "%-30s %-10s %-15s %-20s" % [
        job.name.truncate(28),
        job.schedule,
        job.status,
        next_run
      ]
    end

    puts "-" * 80
    puts "Total: #{jobs.count} jobs"
  end

  desc "Run a specific periodic job by name"
  task :run_job, [:name] => :environment do |t, args|
    job_name = args[:name]

    if job_name.blank?
      puts "Usage: rake periodic_jobs:run_job[job_name]"
      exit 1
    end

    job = PeriodicJob.find_by(name: job_name)

    if job.nil?
      puts "Job '#{job_name}' not found."
      puts "Available jobs:"
      PeriodicJob.pluck(:name).each { |name| puts "  - #{name}" }
      exit 1
    end

    puts "Running job: #{job.name}"
    success = PeriodicJobRunner.run_job(job.id)

    if success
      puts "Job completed successfully."
    else
      puts "Job failed or could not start."
      exit 1
    end
  end
end
