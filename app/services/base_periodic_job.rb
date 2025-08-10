class BasePeriodicJob
  def perform
    raise NotImplementedError, "Subclasses must implement #perform"
  end

  protected

  def log(message)
    Rails.logger.info "[#{self.class.name}] #{message}"
    puts message # This will be captured by the runner
  end

  def log_error(message)
    Rails.logger.error "[#{self.class.name}] #{message}"
    puts "ERROR: #{message}" # This will be captured by the runner
  end
end
