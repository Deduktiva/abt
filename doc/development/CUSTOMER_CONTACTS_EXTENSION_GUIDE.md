# Customer Contacts Extension Guide

This guide explains how to extend the customer contacts system to support new document types beyond invoices.

## Current Implementation

The system currently supports:
- **Invoices**: Uses `receives_invoices` boolean flag
- Project-specific email routing
- Automatic email settings integration

## Adding New Document Types

Follow these steps to add support for new document types (e.g., quotes, statements, etc.):

### 1. Database Migration

Create a migration to add the new document type flag:

```ruby
class AddReceivesQuotesToCustomerContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :customer_contacts, :receives_quotes, :boolean, default: false
  end
end
```

### 2. Update Model (app/models/customer_contact.rb)

Add the new method following the existing pattern:

```ruby
def receives_quotes_for_project?(project)
  return false unless receives_quotes?
  return true if projects.empty?
  projects.include?(project)
end
```

### 3. Update Controller (app/controllers/customer_contacts_controller.rb)

Add the new parameter to the permitted params:

```ruby
def customer_contact_params
  params.require(:customer_contact).permit(:name, :email, :receives_invoices, :receives_quotes)
end
```

### 4. Update UI Views

#### Table Header (app/views/customers/show.html.haml)
```haml
%th Receives Quotes
```

#### Contact Row (app/views/customers/_customer_contact_row.html.haml)
```haml
%td
  .form-check
    %input.form-check-input{
      type: 'checkbox',
      checked: contact.receives_quotes?,
      data: {field: 'receives_quotes', action: 'change->customer-contacts#updateField'}
    }
```

### 5. Update Stimulus Controller (app/javascript/controllers/customer_contacts_controller.js)

No changes needed - the existing controller handles any field updates generically.

### 6. Create New Mailer Method

Add mailer method for the new document type:

```ruby
def get_quote_recipients(quote)
  quote.customer.customer_contacts
       .select { |contact| contact.receives_quotes_for_project?(quote.project) }
       .map(&:email)
end
```

### 7. Update Application Logic

Update any scopes, filters, or business logic that determines which documents can be emailed:

```ruby
# In Invoice model or similar
scope :email_unsent, -> {
  joins(:customer)
  .where(email_sent_at: nil)
  .where("customers.invoice_email_auto_enabled = true OR EXISTS (SELECT 1 FROM customer_contacts WHERE customer_contacts.customer_id = customers.id AND customer_contacts.receives_quotes = true)")
}
```

### 8. Add Tests

Create comprehensive tests for the new document type:

```ruby
test "receives_quotes_for_project should return true when receives_quotes is true and project is associated" do
  customer = customers(:good_eu)
  project = projects(:one)
  contact = CustomerContact.create!(
    customer: customer,
    name: "Test Contact",
    email: "test@example.com",
    receives_quotes: true
  )
  contact.projects = [project]
  
  assert contact.receives_quotes_for_project?(project)
end
```

### 9. Update Seeds (if applicable)

Add sample data for the new document type in `db/seeds.rb`:

```ruby
contact1 = CustomerContact.create!(
  customer: customer,
  name: "Quote Contact",
  email: "quotes@example.com",
  receives_invoices: false,
  receives_quotes: true
)
```

## Implementation Notes

- Each document type gets its own boolean flag for maximum flexibility
- The `*_for_project?` pattern ensures consistent behavior across document types
- UI remains inline-editable for all document types
- Project associations work the same way for all document types
- No changes needed to the many-to-many project relationship

## Future Considerations

If the number of document types grows significantly (>5-6), consider refactoring to:
- JSON column with document type preferences
- Separate DocumentTypePreference model
- More sophisticated permission system

For now, the boolean flag approach provides the best balance of simplicity and functionality.