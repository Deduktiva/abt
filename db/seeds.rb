# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

# Essential data needed for all environments
puts "🌱 Creating essential data..."

# Languages (required for customer language selection)
english = Language.find_or_create_by(iso_code: 'en') do |lang|
  lang.title = 'English'
end

german = Language.find_or_create_by(iso_code: 'de') do |lang|
  lang.title = 'German'
end

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

  issuer_company = IssuerCompany.find_or_create_by(active: true) do |issuer|
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
    issuer.document_accent_color = "#3366cc"
    issuer.invoice_footer = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
  end

  # Load example logos if they don't exist yet
  if issuer_company.pdf_logo.blank?
    pdf_logo_path = Rails.root.join('test', 'fixtures', 'files', 'example_logo.pdf')
    png_logo_path = Rails.root.join('test', 'fixtures', 'files', 'example_logo.png')

    issuer_company.update!(
      pdf_logo: File.binread(pdf_logo_path),
      pdf_logo_width: "53.0mm",
      pdf_logo_height: "16.0mm",
      png_logo: File.binread(png_logo_path)
    )
    puts "📊 Loaded example logos for issuer company"
  end

  # Sample customers
  good_company = Customer.find_or_create_by(matchcode: 'GOODEU') do |customer|
    customer.name = 'Good Company Poland B.V.'
    customer.address = <<~ADDRESS.strip
      Ulica Podhalańska 2
      80-322 Gdańsk
      Poland
    ADDRESS
    customer.vat_id = 'PL0123456789'
    customer.email = 'accounting-goodeu@example.com'
    customer.notes = 'Long-term client, monthly invoicing'
    customer.sales_tax_customer_class = eu_class
    customer.language = english
  end

  local_company = Customer.find_or_create_by(matchcode: 'LOCALNAT') do |customer|
    customer.name = 'Local National Company B.V.'
    customer.address = <<~ADDRESS.strip
      Businessstraat 123
      1234 AB Amsterdam
      Netherlands
    ADDRESS
    customer.vat_id = 'NL123456789B01'
    customer.email = 'accounting-localnat@example.com'
    customer.notes = 'Project-based work'
    customer.sales_tax_customer_class = national_class
    customer.language = german
  end

  export_company = Customer.find_or_create_by(matchcode: 'USACORP') do |customer|
    customer.name = 'USA Corporation Inc.'
    customer.address = <<~ADDRESS.strip
      123 Business Ave
      New York, NY 10001
      United States
    ADDRESS
    customer.email = 'ap-us@example.com'
    customer.notes = 'US-based client, quarterly invoicing'
    customer.sales_tax_customer_class = export_class
    customer.language = english
  end

  # Sample projects
  webapp_project = Project.find_or_create_by(matchcode: 'WEBAPP') do |project|
    project.description = 'Web Application Development'
    project.bill_to_customer = good_company
  end

  consulting_project = Project.find_or_create_by(matchcode: 'CONSULT') do |project|
    project.description = 'IT Consulting Services'
    project.bill_to_customer = local_company
  end

  api_project = Project.find_or_create_by(matchcode: 'APIDEV') do |project|
    project.description = 'API Development and Integration'
    project.bill_to_customer = export_company
  end

  # Reusable projects (no customer assigned)
  training_project = Project.find_or_create_by(matchcode: 'TRAINING') do |project|
    project.description = 'Technical Training & Workshops'
    project.bill_to_customer = nil  # Reusable project
  end

  maintenance_project = Project.find_or_create_by(matchcode: 'MAINT') do |project|
    project.description = 'System Maintenance & Support'
    project.bill_to_customer = nil  # Reusable project
  end

  research_project = Project.find_or_create_by(matchcode: 'RESEARCH') do |project|
    project.description = 'R&D and Technology Research'
    project.bill_to_customer = nil  # Reusable project
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

  # Sample invoice using a reusable project
  unless Invoice.exists?(customer: export_company, project: training_project)
    Invoice.create!(
      customer: export_company,
      project: training_project,
      cust_reference: 'TRAIN-2025-001',
      cust_order: 'TRAINING-ORDER-001',
      prelude: 'Technical training workshop for development team',
      date: 5.days.ago.to_date,
      published: false
    )
  end

  # Complex draft invoice with different line types
  unless Invoice.exists?(customer: export_company, project: api_project)
    complex_invoice = Invoice.create!(
      customer: export_company,
      project: api_project,
      cust_reference: 'API-DEV-2025-Q1',
      cust_order: 'PO-API-5589',
      prelude: 'API development project with multiple deliverables and milestone phases',
      date: 2.weeks.ago.to_date,
      published: false
    )

    # Add different types of invoice lines
    complex_invoice.invoice_lines.create!(
      type: 'subheading',
      title: 'Phase 1: Initial Setup and Planning',
      position: 1
    )

    complex_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Project Setup',
      description: 'Repository setup, CI/CD configuration, and development environment',
      quantity: 8.0,
      rate: 95.00,
      sales_tax_product_class: standard_product,
      position: 2
    )

    complex_invoice.invoice_lines.create!(
      type: 'item',
      title: 'API Design and Documentation',
      description: 'OpenAPI specification, endpoint design, and technical documentation',
      quantity: 16.0,
      rate: 85.00,
      sales_tax_product_class: standard_product,
      position: 3
    )

    complex_invoice.invoice_lines.create!(
      type: 'text',
      title: 'Phase 1 completed on schedule with all deliverables approved by client.',
      position: 4
    )

    complex_invoice.invoice_lines.create!(
      type: 'subheading',
      title: 'Phase 2: Core Development',
      position: 5
    )

    complex_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Authentication & Authorization',
      description: 'JWT implementation, role-based access control, and security middleware',
      quantity: 24.0,
      rate: 85.00,
      sales_tax_product_class: standard_product,
      position: 6
    )

    complex_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Core API Endpoints',
      description: 'CRUD operations, data validation, and error handling',
      quantity: 40.0,
      rate: 85.00,
      sales_tax_product_class: standard_product,
      position: 7
    )

    complex_invoice.invoice_lines.create!(
      type: 'text',
      title: 'All endpoints tested and documented. Performance requirements exceeded.',
      position: 8
    )

    complex_invoice.invoice_lines.create!(
      type: 'subheading',
      title: 'Phase 3: Integration and Testing',
      position: 9
    )

    complex_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Integration Testing',
      description: 'End-to-end testing, third-party API integration, and performance testing',
      quantity: 20.0,
      rate: 85.00,
      sales_tax_product_class: standard_product,
      position: 10
    )

    complex_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Project Management',
      description: 'Sprint planning, stakeholder communication, and delivery coordination',
      quantity: 12.0,
      rate: 75.00,
      sales_tax_product_class: standard_product,
      position: 11
    )
  end

  # Booked invoice for 2025
  unless Invoice.exists?(document_number: '20250001')
    current_year_invoice = Invoice.create!(
      customer: good_company,
      project: webapp_project,
      cust_reference: 'WEBAPP-2025-001',
      cust_order: 'ORDER-WEB-2025-001',
      prelude: 'Web application development services - January 2025',
      date: Date.new(2025, 1, 15),
      published: false, # Create as unpublished first
      document_number: '20250001',
      token: 'hxrwlxsspur',
      tax_note: 'Reverse Charge - VAT is payable by the customer',
    )

    current_year_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Frontend Development',
      description: 'React.js component development and UI implementation',
      quantity: 40.0,
      rate: 85.00,
      sales_tax_product_class: standard_product,
      position: 1
    )

    current_year_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Backend Development',
      description: 'Database design and REST API implementation',
      quantity: 32.0,
      rate: 85.00,
      sales_tax_product_class: standard_product,
      position: 2
    )

    current_year_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Project Management',
      description: 'Sprint planning and client communication',
      quantity: 8.0,
      rate: 75.00,
      sales_tax_product_class: standard_product,
      position: 3
    )

    # Properly initialize the invoice by running the booking process
    current_year_invoice.save! # Trigger before_save callbacks
    current_year_invoice.due_date = Date.new(2025, 2, 14)

    current_year_invoice.published = true # Now publish the invoice

    pdf_path = Rails.root.join('db', 'seed_data', 'invoice_20250001.pdf')
    current_year_invoice.attachment = Attachment.new
    current_year_invoice.attachment.set_data File.binread(pdf_path), 'application/pdf'
    current_year_invoice.attachment.filename = 'My_Example-Invoice-20250001.pdf'
    current_year_invoice.attachment.title = 'My Example Invoice 20250001'
    current_year_invoice.attachment.save!

    current_year_invoice.save!
  end

  # Booked invoice for last year (2024)
  unless Invoice.exists?(document_number: '20240145')
    last_year_invoice = Invoice.create!(
      customer: local_company,
      project: consulting_project,
      cust_reference: 'CONSULT-2024-Q4',
      cust_order: 'ORDER-CONSULT-2024-045',
      prelude: 'Technical consulting services - December 2024',
      date: Date.new(2024, 12, 20),
      published: false, # Create as unpublished first
      document_number: '20240145'
    )

    last_year_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Infrastructure Consulting',
      description: 'Cloud architecture review and optimization recommendations',
      quantity: 24.0,
      rate: 95.00,
      sales_tax_product_class: standard_product,
      position: 1
    )

    last_year_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Security Assessment',
      description: 'Security audit and penetration testing',
      quantity: 16.0,
      rate: 95.00,
      sales_tax_product_class: standard_product,
      position: 2
    )

    last_year_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Documentation',
      description: 'Technical documentation and implementation guides',
      quantity: 8.0,
      rate: 85.00,
      sales_tax_product_class: standard_product,
      position: 3
    )

    # Properly initialize the invoice by running the booking process
    last_year_invoice.save! # Trigger before_save callbacks
    last_year_invoice.due_date = last_year_invoice.date + last_year_invoice.customer.payment_terms_days.days

    # Calculate and set tax classes for the booked invoice
    net_amount = (24.0 * 95.00) + (16.0 * 95.00) + (8.0 * 85.00)
    tax_amount = net_amount * 0.20 # 20% for national customer

    last_year_invoice.invoice_tax_classes.create!(
      sales_tax_product_class: standard_product,
      name: standard_product.name,
      indicator_code: standard_product.indicator_code,
      rate: 20.0, # National customer has 20% VAT
      net: net_amount,
      value: tax_amount,
      total: net_amount + tax_amount
    )

    # Set invoice totals and generate token, then publish
    last_year_invoice.sum_net = net_amount
    last_year_invoice.sum_total = net_amount + tax_amount # National customer with 20% VAT
    last_year_invoice.token = Rfc4648Base32.i_to_s((SecureRandom.random_number(100).to_s + (last_year_invoice.customer.id + 100000).to_s + last_year_invoice.document_number.to_s).to_i)
    last_year_invoice.published = true # Now publish the invoice

    # Create a sample PDF attachment
    sample_pdf_path = Rails.root.join('test', 'fixtures', 'files', 'example_logo.pdf')
    if File.exist?(sample_pdf_path)
      last_year_invoice.attachment = Attachment.new
      last_year_invoice.attachment.set_data File.binread(sample_pdf_path), 'application/pdf'
      last_year_invoice.attachment.filename = "#{issuer_company.short_name}-Invoice-#{last_year_invoice.document_number}.pdf"
      last_year_invoice.attachment.title = "#{issuer_company.short_name} Invoice #{last_year_invoice.document_number}"
      last_year_invoice.attachment.save!
    end

    last_year_invoice.save!
  end

  # Update document number sequence to account for seeded invoices
  dn = DocumentNumber.find_by_code('invoice')
  if dn && dn.last_date.nil?
    # Initialize the sequence with the seeded invoice numbers
    dn.last_date = Date.new(2025, 1, 15) # Date of the latest seeded invoice
    dn.sequence = 1 # Next number after 20250001 would be 20250002
    dn.last_number = '20250001'
    dn.save!
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
