# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is "ABT", a Rails 8 application for invoice management. Features modern Bootstrap 5 UI, Turbo-powered interactions, email automation, and PDF generation via Apache FOP.

## Common Commands

### Setup and Dependencies
- `bundle install` - Install Ruby gem dependencies (requires Ruby >= 3.3)
- `bundle exec rails db:migrate` - Run database migrations
- `bundle exec rails db:seed` - Load seed data

### Development
- `bundle exec rails server` - Start the development server
- `bundle exec rails console` - Open Rails console (use for testing helpers and models)
- `bundle exec rails test` - Run the test suite (NEVER use `rails test` - it doesn't handle migrations properly)

### Database
- `bundle exec rails db:create` - Create database
- `bundle exec rails db:setup` - Create database and load schema
- `bundle exec rails db:reset` - Drop, recreate, and reseed database

### PostgreSQL Development Environment
For testing against PostgreSQL (matches production environment):
- `./bin/postgres-dev start` - Start PostgreSQL container
- `./bin/postgres-dev setup` - Create and setup PostgreSQL database
- `./bin/postgres-dev server` - Run Rails server with PostgreSQL
- `./bin/postgres-dev test` - Run tests with PostgreSQL
- See `POSTGRES_DEV.md` for complete documentation

## Architecture Overview

### Core Models
- **Invoice** (`app/models/invoice.rb`) - Central model with customer, project associations and nested invoice lines
- **Customer** (`app/models/customer.rb`) - Customer management with sales tax classes
- **InvoiceLine** (`app/models/invoice_line.rb`) - Line items for invoices with different types (item, text, subheading)
- **Product** (`app/models/product.rb`) - Product catalog
- **Project** (`app/models/project.rb`) - Project tracking

### Tax System
- **SalesTaxCustomerClass** - Customer tax classification
- **SalesTaxProductClass** - Product tax classification
- **SalesTaxRate** - Tax rates by customer/product class combination
- **InvoiceTaxClass** - Applied tax calculations per invoice

### Invoice Processing Pipeline
1. **InvoicesController** - Standard CRUD + special actions (preview, book, bulk email)
2. **InvoiceBooker** - Business logic for "booking" invoices (calculating taxes, assigning document numbers, publishing)
3. **InvoiceRenderer** - PDF generation using Apache FOP with XML/XSL transformation
4. **Email System** - Automated email sending with tracking and bulk operations

### PDF Generation
- Uses Apache FOP (Formatting Objects Processor) for PDF generation
- XML template in `lib/foptemplate/invoice.xsl`
- Requires external FOP binary configured in `settings.yml`

### Key Workflow
1. Create draft invoice with lines
2. Preview generates temporary PDF without saving
3. "Book" finalizes invoice (assigns document number, calculates final taxes, publishes)
4. Published invoices cannot be modified
5. Email invoices individually or in bulk batches

## Configuration

### Database
- Development: SQLite3
- Production: PostgreSQL 17
- Template files: `config/database.yml.tpl`, `config/secrets.yml.tpl`

### Settings
- Configuration via `config/settings.yml` and environment-specific files
- FOP binary path must be configured for PDF generation
- Payment URL template for invoice tokens

## External Dependencies

### Required Software
- Ruby >= 3.3
- Apache FOP 2.10 for PDF generation
- Database (SQLite3 for dev, PostgreSQL for production and in CI)

### Font Files
- Open Sans fonts in `lib/foptemplate/open-sans/` for PDF rendering

## Key Files for Modifications
- Invoice business logic: `app/controllers/invoice_book_controller.rb`
- PDF template: `lib/foptemplate/invoice.xsl`
- Invoice model: `app/models/invoice.rb`
- Main invoice controller: `app/controllers/invoices_controller.rb`
- UI helpers: `app/helpers/application_helper.rb`

## Development Preferences

### Template Language
- **PREFER HAML** over ERB for all new view templates
- HAML is more concise, readable, and less error-prone than ERB
- All existing templates have been converted to HAML for consistency
- Use `.html.haml` extension for view files

### UI Framework
- Bootstrap 5 for responsive design and components
- Turbo for SPA-like interactions without JavaScript complexity
- Stimulus controllers for interactive components (bulk-select, email-preview)
- European-style date/time formatting throughout

## Development Best Practices

### Running rails
- Always use `bundle exec rails` to run `rails`

### Testing Guidelines
- Write simple unit tests when implementing new features
- Test database auto-migrates via `ActiveRecord::Migration.maintain_test_schema!` in test_helper.rb
- **NEVER use `assigns()` in tests** - it has been extracted to a gem in modern Rails. Use `assert_select` or other response testing methods instead
- **Run UI tests headless by default before declaring frontend/UI tasks complete** when making frontend/UI changes
- **NEVER use `sleep` in system tests** - use Capybara's waiting methods instead (`assert_selector`, `assert_text`, `assert_no_text` with `wait:` option)

### UI Testing Commands
- Run all system tests: `bundle exec rails test test/system/`
- Run specific system test file: `bundle exec rails test test/system/filename_test.rb`
- Run specific test method: `bundle exec rails test test/system/filename_test.rb -n test_method_name`
- System tests use Cuprite (headless Chrome) driver configured in ApplicationSystemTestCase
- Screenshots saved to `tmp/capybara/` on test failures for debugging

### Multi-Region Compatibility
- This app supports multiple regions - NEVER hardcode currency symbols like $ or USD
- Use IssuerCompany.currency field for currency configuration (defaults to EUR)
- Currency formatting handled by ApplicationHelper#format_currency
- Date formatting via ApplicationHelper#format_date and #format_datetime

### Formatting Standards
- ALWAYS use European date formats: DD.MM.YYYY for dates, DD.MM.YYYY HH:MM for datetimes
- Use DD.MM for short dates when year is implied
- NEVER use American MM/DD/YYYY or MM-DD formats

### UI Helper Methods
- `action_buttons_wrapper` - Container for action button groups
- `action_button(text, path, type)` - Styled buttons (primary, secondary, success, info, warning, danger)
- `destroy_link(resource, confirm_text)` - Smart delete links (trashcan on index, "Delete" on detail pages)
- `list_action_link(text, path, type)` - Compact buttons for table actions
- `page_header_with_new_button` - Standard page headers with + New button

### JavaScript/Stimulus Controllers
- **ALWAYS implement `disconnect()` method** in Stimulus controllers that add event listeners
- Store bound function references (e.g., `this.boundHandler = this.method.bind(this)`) for proper cleanup
- Remove event listeners in `disconnect()` using the same bound reference used in `addEventListener`
- When re-attaching listeners to dynamically created elements, remove existing listeners first to prevent duplicates
- Document event listeners are particularly important to clean up to prevent memory leaks
- **Run `npm run lint` after writing Stimulus controllers** to check for event listener memory leaks
- **NEVER use relative imports** like `import Controller from "./other_controller"` - use importmap paths like `import Controller from "controllers/other_controller"` to ensure proper resolution in production
- **NEVER hardcode absolute URL paths** in JavaScript - use Rails URL helpers passed via data attributes to ensure proper subdirectory deployment compatibility

### Communication Style
- Use direct, technical language in all communications
- Avoid management/business buzzwords and corporate speak
- Be concise and specific rather than verbose or promotional
- Focus on technical implementation details rather than high-level benefits
- Use imperative mood for instructions (e.g. "Run the test" not "We should run the test")
- Avoid phrases like "let's", "we need to", "going forward", "best practices", "leverage", "stakeholders"
- Be factual and precise rather than enthusiastic or salesy

### Code Quality
- When refactoring or fixing bugs, follow DRY principles but don't overdo it
- Prefer clarity and maintainability over excessive abstraction

### Git Commit Message Style
- Use concise, direct subject lines (e.g. "Auto-resize textareas")
- Brief functional description in body (one sentence explaining main functionality)
- Key implementation details as short, factual bullet points
- Include practical context when relevant (demo content, examples)
- Maintain Claude Code attribution footer
- Avoid verbose technical explanations or excessive detail in commit messages

### System Administration
- **NEVER run `sudo` commands**
- If system packages need to be installed, explain what is needed and ask the user to install them

### Git and Version Control
- **NEVER check in screenshots or temporary image files**
- Screenshots are typically for debugging or demonstration purposes only
- Use `.gitignore` to exclude temporary files and screenshots from commits

- when refactoring or fixing bugs try to follow DRY principles, but dont overdo it

### Development Commands
- **ALWAYS run `pre-commit run --all-files` before committing** to ensure code formatting and linting
- **Use `pkill -f puma` to kill running `rails server`** when needed to stop development server
