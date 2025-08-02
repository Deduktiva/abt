# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

# Essential data needed for all environments
puts "🌱 Creating essential data..."

# Document number configuration for invoices
DocumentNumber.find_or_create_by(code: 'invoice') do |dn|
  dn.format = '%{year}%<number>04d'
  dn.sequence = 0
  dn.last_number = nil
  dn.last_date = nil
end

# Sales tax customer classes (required for the system to work)
national_class = SalesTaxCustomerClass.find_or_create_by(name: 'National') do |stcc|
  stcc.invoice_note = ''
end

eu_class = SalesTaxCustomerClass.find_or_create_by(name: 'EU') do |stcc|
  stcc.invoice_note = 'Reverse Charge - VAT is payable by the customer'
end

export_class = SalesTaxCustomerClass.find_or_create_by(name: 'EXPORT') do |stcc|
  stcc.invoice_note = 'EXPORT TO NON-EU COUNTRY'
end

# Sales tax product classes
standard_product = SalesTaxProductClass.find_or_create_by(name: 'Standard Goods') do |stpc|
  stpc.indicator_code = 'STD'
end

# Sales tax rates (connecting customer and product classes)
SalesTaxRate.find_or_create_by(
  sales_tax_customer_class: national_class,
  sales_tax_product_class: standard_product
) do |str|
  str.rate = 20.0
end

SalesTaxRate.find_or_create_by(
  sales_tax_customer_class: eu_class,
  sales_tax_product_class: standard_product
) do |str|
  str.rate = 0.0
end

SalesTaxRate.find_or_create_by(
  sales_tax_customer_class: export_class,
  sales_tax_product_class: standard_product
) do |str|
  str.rate = 0.0
end

puts "✅ Essential data created"

# Development sample data (only in development environment)
if Rails.env.development?
  puts "🧪 Creating development sample data..."
  
  # Sample customers
  good_company = Customer.find_or_create_by(matchcode: 'GOODEU') do |customer|
    customer.name = 'Good Company Europe B.V.'
    customer.address = <<~ADDRESS.strip
      Businessstraat 123
      1234 AB Amsterdam
      Netherlands
    ADDRESS
    customer.time_budget = 1200
    customer.vat_id = 'NL123456789B01'
    customer.email = 'accounting@goodcompany.eu'
    customer.notes = 'Long-term client, monthly invoicing'
    customer.sales_tax_customer_class = eu_class
  end
  
  local_company = Customer.find_or_create_by(matchcode: 'LOCALNAT') do |customer|
    customer.name = 'Local National Company Ltd.'
    customer.address = <<~ADDRESS.strip
      High Street 45
      SW1A 1AA London
      United Kingdom
    ADDRESS
    customer.time_budget = 800
    customer.vat_id = 'GB999999999'
    customer.email = 'finance@localcompany.co.uk'
    customer.notes = 'Project-based work'
    customer.sales_tax_customer_class = national_class
  end
  
  export_company = Customer.find_or_create_by(matchcode: 'USACORP') do |customer|
    customer.name = 'USA Corporation Inc.'
    customer.address = <<~ADDRESS.strip
      123 Business Ave
      New York, NY 10001
      United States
    ADDRESS
    customer.time_budget = 2000
    customer.email = 'ap@usacorp.com'
    customer.notes = 'US-based client, quarterly invoicing'
    customer.sales_tax_customer_class = export_class
  end
  
  # Sample projects
  webapp_project = Project.find_or_create_by(matchcode: 'WEBAPP') do |project|
    project.description = 'Web Application Development'
    project.time_budget = 160
    project.bill_to_customer = good_company
  end
  
  consulting_project = Project.find_or_create_by(matchcode: 'CONSULT') do |project|
    project.description = 'IT Consulting Services'
    project.time_budget = 80
    project.bill_to_customer = local_company
  end
  
  api_project = Project.find_or_create_by(matchcode: 'APIDEV') do |project|
    project.description = 'API Development and Integration'
    project.time_budget = 120
    project.bill_to_customer = export_company
  end
  
  # Sample products
  Product.find_or_create_by(title: 'Software Development') do |product|
    product.description = 'Custom software development services per hour'
    product.rate = 85.00
    product.sales_tax_product_class = standard_product
  end
  
  Product.find_or_create_by(title: 'Technical Consulting') do |product|
    product.description = 'Technical consulting and architecture services per hour'
    product.rate = 95.00
    product.sales_tax_product_class = standard_product
  end
  
  Product.find_or_create_by(title: 'Project Management') do |product|
    product.description = 'Project management and coordination services per hour'
    product.rate = 75.00
    product.sales_tax_product_class = standard_product
  end
  
  # Sample invoices (unpublished for testing)
  unless Invoice.exists?(customer: good_company, project: webapp_project)
    invoice = Invoice.create!(
      customer: good_company,
      project: webapp_project,
      cust_reference: 'PO-2025-001',
      cust_order: 'ORDER-WEB-2025',
      prelude: 'Development work for Q1 2025 web application project',
      date: 1.week.ago.to_date,
      published: false
    )
    
    # Add invoice lines
    invoice.invoice_lines.create!(
      type: 'item',
      title: 'Frontend Development',
      description: 'React.js frontend development work',
      quantity: 24.0,
      rate: 85.00,
      sales_tax_product_class: standard_product
    )
    
    invoice.invoice_lines.create!(
      type: 'item',
      title: 'Backend API Development',
      description: 'Node.js backend API development',
      quantity: 32.0,
      rate: 85.00,
      sales_tax_product_class: standard_product
    )
    
    invoice.invoice_lines.create!(
      type: 'item',
      title: 'Project Planning',
      description: 'Initial project planning and architecture',
      quantity: 8.0,
      rate: 95.00,
      sales_tax_product_class: standard_product
    )
  end
  
  unless Invoice.exists?(customer: local_company, project: consulting_project)
    Invoice.create!(
      customer: local_company,
      project: consulting_project,
      cust_reference: 'REF-CONSULT-2025',
      prelude: 'Technical consulting services for infrastructure upgrade',
      date: 3.days.ago.to_date,
      published: false
    )
  end
  
  puts "✅ Development sample data created"
  puts ""
  puts "📊 Sample Data Summary:"
  puts "  Customers: #{Customer.count}"
  puts "  Projects: #{Project.count}"
  puts "  Products: #{Product.count}"
  puts "  Invoices: #{Invoice.count}"
  puts "  Tax Classes: #{SalesTaxCustomerClass.count} customer, #{SalesTaxProductClass.count} product"
  puts "  Tax Rates: #{SalesTaxRate.count}"
  puts ""
  puts "🚀 You can now:"
  puts "  - Browse customers at /customers"
  puts "  - Create new invoices"
  puts "  - Test PDF generation with sample data"
end
