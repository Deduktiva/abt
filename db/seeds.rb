# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

# Essential data needed for all environments
puts "🌱 Creating essential data..."

# Built-in Admin group (all permissions, bypasses team scoping). Idempotent for
# fresh installs that loaded schema.rb without running the migration's seed.
admin_group = Group.find_or_create_by!(builtin: true, name: Group::ADMIN_NAME) do |g|
  g.description = "Built-in administrator group with all permissions"
  g.bypass_team_scoping = true
end
Permission::ALL_KEYS.each do |perm|
  admin_group.group_permissions.find_or_create_by!(permission: perm)
end

# Built-in Default team. Every newly-created User auto-joins this team
# (lookup goes through Team.default, which uses the `default: true` flag).
Team.find_or_create_by!(builtin: true, name: Team::DEFAULT_NAME) do |t|
  t.description = "Built-in default team. Every new user starts here."
  t.default = true
end

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

# Document number configuration for delivery notes
DocumentNumber.find_or_create_by(code: 'delivery_note') do |dn|
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
  stcc.vat_id_required = false
end

# Sales tax product classes
standard_product = SalesTaxProductClass.find_or_create_by(name: 'Standard Goods') do |stpc|
  stpc.indicator_code = 'STD'
  stpc.is_default = true
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

  default_team = Team.default || raise("Built-in Default team missing; run db:migrate first")

  # Sample customers
  good_company = Customer.find_or_create_by(matchcode: 'GOODEU') do |customer|
    customer.name = 'Good Company Poland B.V.'
    customer.address = <<~ADDRESS.strip
      Ulica Podhalańska 2
      80-322 Gdańsk
      Poland
    ADDRESS
    customer.vat_id = 'PL0123456789'
    customer.notes = 'Long-term client, monthly invoicing'
    customer.sales_tax_customer_class = eu_class
    customer.language = english
    customer.team = default_team
    customer.invoice_email_auto_enabled = true
    customer.invoice_email_auto_to = 'invoices-good-eu@example.com'
    customer.invoice_email_auto_subject_template = 'Invoice $CUST_REF$ ($CUST_ORDER$)'
    customer.invoice_email_auto_contact_mode = 'cc_contacts'
  end

  local_company = Customer.find_or_create_by(matchcode: 'LOCALNAT') do |customer|
    customer.name = 'Local National Company B.V.'
    customer.address = <<~ADDRESS.strip
      Businessstraat 123
      1234 AB Amsterdam
      Netherlands
    ADDRESS
    customer.vat_id = 'NL123456789B01'
    customer.notes = 'Project-based work'
    customer.sales_tax_customer_class = national_class
    customer.language = german
    customer.team = default_team
  end

  export_company = Customer.find_or_create_by(matchcode: 'USACORP') do |customer|
    customer.name = 'USA Corporation Inc.'
    customer.address = <<~ADDRESS.strip
      123 Business Ave
      New York, NY 10001
      United States
    ADDRESS
    customer.notes = 'US-based client, quarterly invoicing'
    customer.sales_tax_customer_class = export_class
    customer.language = english
    customer.team = default_team
  end

  # Former customer, kept for historical invoice references but no longer
  # billable. Demonstrates the Inactive state in the UI.
  Customer.find_or_create_by(matchcode: 'OLDCLIENT') do |customer|
    customer.name = 'Old Client GmbH'
    customer.address = <<~ADDRESS.strip
      Hauptstraße 1
      1010 Wien
      Austria
    ADDRESS
    customer.vat_id = 'ATU99999999'
    customer.notes = 'Engagement ended 2024'
    customer.sales_tax_customer_class = eu_class
    customer.language = german
    customer.team = default_team
    customer.active = false
  end

  # Sample projects
  webapp_project = Project.find_or_create_by(matchcode: 'WEBAPP') do |project|
    project.description = 'Web Application Development'
    project.bill_to_customer = good_company
    project.team = default_team
  end

  consulting_project = Project.find_or_create_by(matchcode: 'CONSULT') do |project|
    project.description = 'IT Consulting Services'
    project.bill_to_customer = local_company
    project.team = default_team
  end

  api_project = Project.find_or_create_by(matchcode: 'APIDEV') do |project|
    project.description = 'API Development and Integration'
    project.bill_to_customer = export_company
    project.team = default_team
  end

  # Reusable projects (no customer assigned)
  training_project = Project.find_or_create_by(matchcode: 'TRAINING') do |project|
    project.description = 'Technical Training & Workshops'
    project.bill_to_customer = nil  # Reusable project
    project.team = default_team
  end

  Project.find_or_create_by(matchcode: 'MAINT') do |project|
    project.description = 'System Maintenance & Support'
    project.bill_to_customer = nil  # Reusable project
    project.team = default_team
  end

  Project.find_or_create_by(matchcode: 'RESEARCH') do |project|
    project.description = 'R&D and Technology Research'
    project.bill_to_customer = nil  # Reusable project
    project.team = default_team
  end

  # Two extra projects for GOODEU to demonstrate project-scoped contacts.
  audit_project = Project.find_or_create_by(matchcode: 'AUDIT2026') do |project|
    project.description = 'Audit 2026'
    project.bill_to_customer = good_company
    project.team = default_team
  end

  migration_project = Project.find_or_create_by(matchcode: 'MIGR2026') do |project|
    project.description = 'Migration 2026'
    project.bill_to_customer = good_company
    project.team = default_team
  end

  # Discontinued reusable project, kept for historical reference. Demonstrates
  # the Inactive state.
  Project.find_or_create_by(matchcode: 'LEGACY') do |project|
    project.description = 'Legacy System (decommissioned)'
    project.bill_to_customer = nil
    project.team = default_team
    project.active = false
  end

  # Customer contacts.
  # GOODEU: three contacts demonstrating the project-scoping rules.
  unless good_company.customer_contacts.exists?
    good_company.customer_contacts.create!(
      name: 'Accounting',
      email: 'accounting-goodeu@example.com',
      receives_invoice_emails: true,
      receives_delivery_note_emails: true
    )
    good_company.customer_contacts.create!(
      name: 'Audit Lead',
      email: 'audit-lead@example.com',
      receives_invoice_emails: true,
      receives_delivery_note_emails: false,
      projects: [ audit_project, migration_project ]
    )
    good_company.customer_contacts.create!(
      name: 'Migration PM',
      email: 'pm-migration@example.com',
      receives_invoice_emails: false,
      receives_delivery_note_emails: true,
      projects: [ migration_project ]
    )
  end

  unless local_company.customer_contacts.exists?
    local_company.customer_contacts.create!(
      name: 'Buchhaltung',
      email: 'accounting-localnat@example.com',
      receives_invoice_emails: true,
      receives_delivery_note_emails: true
    )
  end

  # USACORP is intentionally left without contacts to exercise the
  # "no recipient" UX path.

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

    invoice.save!
  end

  unless Invoice.exists?(customer: local_company, project: consulting_project)
    license_invoice = Invoice.create!(
      customer: local_company,
      project: consulting_project,
      cust_reference: 'REF-LICENSE-2025',
      prelude: 'Software license keys delivery for enterprise deployment',
      published: false
    )

    # Add license key data as plaintext item
    license_keys = <<~LICENSE_KEYS.strip
      Enterprise License Keys - Version 2025.1

      Primary License: ABX9-7YT2-KL45-MN89-QW12-ER34
      Secondary License: CD56-FG78-HI90-JK12-LM34-NP56
      Development License: QR78-ST90-UV12-WX34-YZ56-AB78
      Testing License: EF90-GH12-IJ34-KL56-MN78-OP90
      Staging License: QR12-ST34-UV56-WX78-YZ90-AB12
      Production License: CD34-EF56-GH78-IJ90-KL12-MN34
      Backup License: OP56-QR78-ST90-UV12-WX34-YZ56

      Valid until: December 31, 2025
      Max concurrent users: 500
      Deployment environments: Production, Staging, Development, Testing
    LICENSE_KEYS

    license_invoice.invoice_lines.create!(
      type: 'plain',
      title: 'Enterprise License Keys',
      description: license_keys,
      position: 1
    )

    license_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Enterprise Software License',
      description: 'Annual enterprise license with full feature access',
      quantity: 1.0,
      rate: 15000.00,
      sales_tax_product_class: standard_product,
      position: 2
    )

    license_invoice.invoice_lines.create!(
      type: 'item',
      title: 'Support & Maintenance',
      description: 'Premium support and maintenance package',
      quantity: 1.0,
      rate: 3000.00,
      sales_tax_product_class: standard_product,
      position: 3
    )

    license_invoice.save!
  end

  # Sample invoice using a reusable project
  unless Invoice.exists?(customer: export_company, project: training_project)
    Invoice.create!(
      customer: export_company,
      project: training_project,
      cust_reference: 'TRAIN-2025-001',
      cust_order: 'TRAINING-ORDER-001',
      prelude: 'Technical training workshop for development team',
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

    complex_invoice.save!
  end

  # Published invoice for 2025
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

    # Properly initialize the invoice by running the publish process
    current_year_invoice.save! # Trigger before_save callbacks
    current_year_invoice.due_date = Date.new(2025, 2, 14)

    current_year_invoice.published = true # Now publish the invoice

    pdf_path = Rails.root.join('db', 'seed_data', 'invoice_20250001.pdf')
    current_year_invoice.attachment = Attachment.new
    current_year_invoice.attachment.set_data File.binread(pdf_path), 'application/pdf'
    current_year_invoice.attachment.filename = 'My_Example-Invoice-20250001.pdf'
    current_year_invoice.attachment.title = 'My Example Invoice 20250001'
    current_year_invoice.attachment.save!

    current_year_invoice.paid_at = Date.new(2025, 2, 10)
    current_year_invoice.save!
  end

  # Published invoice for last year (2024)
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

    # save! triggers before_save :update_sums, which auto-creates the
    # InvoiceTaxClass row for the customer's product class and computes
    # sum_net / sum_total from the lines.
    last_year_invoice.save!
    last_year_invoice.due_date = last_year_invoice.date + last_year_invoice.customer.payment_terms_days.days
    last_year_invoice.token = 'lastyr2024tkn'
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

    last_year_invoice.paid_at = Date.new(2025, 1, 20)
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

  # Sample delivery notes
  unless DeliveryNote.exists?(customer: good_company, project: webapp_project)
    delivery_note = DeliveryNote.create!(
      customer: good_company,
      project: webapp_project,
      cust_reference: 'PO-2025-001',
      cust_order: 'ORDER-WEB-2025',
      prelude: 'Delivery of completed web application components for Q1 2025 project',
      date: 1.week.ago.to_date,
      delivery_start_date: 2.weeks.ago.to_date,
      delivery_end_date: 1.week.ago.to_date,
      published: false
    )

    # Add delivery note lines
    delivery_note.delivery_note_lines.create!(
      type: 'subheading',
      title: 'Frontend Components',
      position: 1
    )

    delivery_note.delivery_note_lines.create!(
      type: 'item',
      title: 'User Dashboard',
      description: 'Complete dashboard interface with analytics widgets and responsive design',
      quantity: 1,
      position: 2
    )

    delivery_note.delivery_note_lines.create!(
      type: 'item',
      title: 'Authentication System',
      description: 'Login/logout functionality with password reset and multi-factor authentication',
      quantity: 1,
      position: 3
    )

    delivery_note.delivery_note_lines.create!(
      type: 'text',
      title: 'All frontend components tested and approved by client QA team.',
      position: 4
    )

    delivery_note.delivery_note_lines.create!(
      type: 'subheading',
      title: 'Backend Services',
      position: 5
    )

    delivery_note.delivery_note_lines.create!(
      type: 'item',
      title: 'REST API Endpoints',
      description: 'Complete set of CRUD operations for user management and data processing',
      quantity: 12,
      position: 6
    )

    delivery_note.delivery_note_lines.create!(
      type: 'item',
      title: 'Database Schema',
      description: 'Optimized database structure with proper indexing and relationships',
      quantity: 1,
      position: 7
    )

    delivery_note.delivery_note_lines.create!(
      type: 'text',
      title: 'All backend services deployed to staging environment and performance tested.',
      position: 8
    )

    delivery_note.delivery_note_lines.create!(
      type: 'subheading',
      title: 'Documentation & Training',
      position: 9
    )

    delivery_note.delivery_note_lines.create!(
      type: 'item',
      title: 'Technical Documentation',
      description: 'Complete API documentation and deployment guides',
      quantity: 1,
      position: 10
    )

    delivery_note.delivery_note_lines.create!(
      type: 'item',
      title: 'User Training Session',
      description: 'On-site training for administrative users and system operators',
      quantity: 1,
      position: 11
    )
  end

  # Sample delivery note for German customer
  unless DeliveryNote.exists?(customer: local_company, project: consulting_project)
    delivery_note_de = DeliveryNote.create!(
      customer: local_company,
      project: consulting_project,
      cust_reference: 'REF-CONSULTING-2025',
      cust_order: 'ORDER-CONSULT-2025-001',
      prelude: 'Lieferung der Beratungsleistungen und Implementierungskonzepte für das IT-Infrastruktur-Projekt',
      date: 5.days.ago.to_date,
      delivery_start_date: 2.weeks.ago.to_date,
      delivery_end_date: 5.days.ago.to_date,
      published: false
    )

    delivery_note_de.delivery_note_lines.create!(
      type: 'item',
      title: 'Infrastruktur-Analyse',
      description: 'Vollständige Bewertung der bestehenden IT-Infrastruktur mit Empfehlungen',
      quantity: 1,
      position: 1
    )

    delivery_note_de.delivery_note_lines.create!(
      type: 'item',
      title: 'Sicherheitskonzept',
      description: 'Detailliertes Sicherheitskonzept mit Implementierungsplan',
      quantity: 1,
      position: 2
    )

    delivery_note_de.delivery_note_lines.create!(
      type: 'item',
      title: 'Migrationsstrategie',
      description: 'Schritt-für-Schritt-Plan für die Migration zur neuen Infrastruktur',
      quantity: 1,
      position: 3
    )

    delivery_note_de.delivery_note_lines.create!(
      type: 'text',
      title: 'Alle Lieferungen wurden termingerecht und entsprechend den Spezifikationen erbracht.',
      position: 4
    )

    delivery_note_de.update!(published: true, document_number: 'LN20250001')
  end

  # Delivery note that has been converted to an invoice. Pairs with the
  # API-DEV-2025-Q1 draft invoice above (same customer/project), so the
  # Invoice link on the dn detail page and the Source link on the invoice
  # detail page both render.
  unless DeliveryNote.exists?(customer: export_company, project: api_project)
    converted_dn = DeliveryNote.create!(
      customer: export_company,
      project: api_project,
      cust_reference: 'API-DEV-2025-Q1',
      cust_order: 'PO-API-5589',
      prelude: 'Delivery of completed API development work — phases 1 through 3',
      date: 3.days.ago.to_date,
      delivery_start_date: 6.weeks.ago.to_date,
      delivery_end_date: 3.days.ago.to_date,
      published: false
    )

    converted_dn.delivery_note_lines.create!(
      type: 'subheading',
      title: 'Phase 1: Setup and Planning',
      position: 1
    )

    converted_dn.delivery_note_lines.create!(
      type: 'item',
      title: 'Repository, CI/CD, and API design',
      description: 'Project scaffolding, OpenAPI specification, deployment pipelines',
      quantity: 1,
      position: 2
    )

    converted_dn.delivery_note_lines.create!(
      type: 'subheading',
      title: 'Phase 2: Core Development',
      position: 3
    )

    converted_dn.delivery_note_lines.create!(
      type: 'item',
      title: 'Authentication and CRUD endpoints',
      description: 'JWT, role-based access, validation, error handling',
      quantity: 1,
      position: 4
    )

    converted_dn.delivery_note_lines.create!(
      type: 'subheading',
      title: 'Phase 3: Integration and Testing',
      position: 5
    )

    converted_dn.delivery_note_lines.create!(
      type: 'item',
      title: 'Integration tests and project handover',
      description: 'End-to-end tests, third-party integrations, delivery coordination',
      quantity: 1,
      position: 6
    )

    converted_dn.delivery_note_lines.create!(
      type: 'text',
      title: 'All deliverables accepted by the client.',
      position: 7
    )

    converted_dn.update!(published: true, document_number: 'LN20250002')

    api_invoice = Invoice.find_by(customer: export_company, project: api_project, cust_reference: 'API-DEV-2025-Q1')
    converted_dn.update!(invoice: api_invoice) if api_invoice
  end

  # Update document number sequence for delivery notes
  dn_delivery = DocumentNumber.find_by_code('delivery_note')
  if dn_delivery && dn_delivery.last_date.nil?
    # Initialize the sequence with the seeded delivery note numbers
    dn_delivery.last_date = 3.days.ago.to_date
    dn_delivery.sequence = 2 # Next number after LN20250002 would be LN20250003
    dn_delivery.last_number = 'LN20250002'
    dn_delivery.save!
  end

  puts "✅ Development sample data created"
  puts ""
  puts "📊 Sample Data Summary:"
  puts "  Customers: #{Customer.count}"
  puts "  Projects: #{Project.count}"
  puts "  Products: #{Product.count}"
  puts "  Invoices: #{Invoice.count}"
  puts "  Delivery Notes: #{DeliveryNote.count}"
  puts "  Tax Classes: #{SalesTaxCustomerClass.count} customer, #{SalesTaxProductClass.count} product"
  puts "  Tax Rates: #{SalesTaxRate.count}"
  puts ""
  puts "🚀 You can now:"
  puts "  - Browse customers at /customers"
  puts "  - Create new invoices and delivery notes"
  puts "  - Test PDF generation with sample data"
end
