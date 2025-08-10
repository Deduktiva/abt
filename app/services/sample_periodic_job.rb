class SamplePeriodicJob < BasePeriodicJob
  def perform
    log "Sample periodic job starting at #{Time.current}"

    # Simulate some work
    sleep 1

    # Example: count some records
    invoice_count = Invoice.count
    customer_count = Customer.count

    log "System status: #{invoice_count} invoices, #{customer_count} customers"

    # Simulate random success/failure for testing
    if rand(10) == 0 # 10% chance of failure for testing
      raise "Random test failure!"
    end

    log "Sample periodic job completed successfully"

    {
      invoices: invoice_count,
      customers: customer_count,
      timestamp: Time.current
    }
  end
end
