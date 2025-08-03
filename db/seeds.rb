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

  IssuerCompany.find_or_create_by(active: true) do |issuer|
    issuer.active = true
    issuer.short_name = 'My Example'
    issuer.legal_name = 'My Example B.V.'
    issuer.address = <<~ADDRESS.strip
      Businessstraat 123
      1234 AB Amsterdam
      Netherlands
    ADDRESS
    issuer.vat_id = 'NL123456789B01'
    issuer.bankaccount_bank = "My Bank B.V."
    issuer.bankaccount_bic = "BICBICBICBIC"
    issuer.bankaccount_number = "NL91ABNA0417164300"
    issuer.document_contact_line1 = "www.example.com      hi@example.com"
    issuer.document_contact_line2 = "voice + xxx xxxxxx"
    issuer.document_accent_color = "#0000ff"
    issuer.invoice_footer = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
  end

  # Sample customers
  good_company = Customer.find_or_create_by(matchcode: 'GOODEU') do |customer|
    customer.name = 'Good Company Poland B.V.'
    customer.address = <<~ADDRESS.strip
      Ulica Podhalańska 2
      80-322 Gdańsk
      Poland
    ADDRESS
    customer.time_budget = 1200
    customer.vat_id = 'PL0123456789'
    customer.email = 'accounting-goodeu@example.com'
    customer.notes = 'Long-term client, monthly invoicing'
    customer.sales_tax_customer_class = eu_class
  end

  local_company = Customer.find_or_create_by(matchcode: 'LOCALNAT') do |customer|
    customer.name = 'Local National Company B.V.'
    customer.address = <<~ADDRESS.strip
      Businessstraat 123
      1234 AB Amsterdam
      Netherlands
    ADDRESS
    customer.time_budget = 800
    customer.vat_id = 'NL123456789B01'
    customer.email = 'accounting-localnat@example.com'
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
    customer.email = 'ap-us@example.com'
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
  unless Invoice.exists?(customer: local_company, project: webapp_project)
    invoice = Invoice.create!(
      customer: local_company,
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

  unless Invoice.exists?(customer: good_company, project: consulting_project)
    Invoice.create!(
      customer: good_company,
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
