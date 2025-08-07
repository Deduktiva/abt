// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Enable Turbo Streams
import { Turbo } from "@hotwired/turbo-rails"
Turbo.config.drive.progressBarDelay = 100

// Customer contact editing functions
window.saveContact = function(contactId) {
  const row = document.querySelector(`[data-contact-id="${contactId}"]`);
  if (!row) return;

  const name = row.querySelector('input[name="name"]').value;
  const email = row.querySelector('input[name="email"]').value;
  const receives_invoices = row.querySelector('input[name="receives_invoices"]').checked;

  const formData = new FormData();
  formData.append('customer_contact[name]', name);
  formData.append('customer_contact[email]', email);
  formData.append('customer_contact[receives_invoices]', receives_invoices);

  // Handle project IDs
  const projectSelect = row.querySelector('select[name="project_ids[]"]');
  if (projectSelect) {
    const selectedOptions = Array.from(projectSelect.selectedOptions);
    selectedOptions.forEach(option => {
      formData.append('customer_contact[project_ids][]', option.value);
    });
  }

  fetch(`/customer_contacts/${contactId}`, {
    method: 'PATCH',
    headers: {
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
      'Accept': 'text/vnd.turbo-stream.html'
    },
    body: formData
  })
  .then(response => {
    if (response.ok) {
      return response.text().then(html => {
        // Process turbo-stream response manually
        Turbo.renderStreamMessage(html);
      });
    } else {
      // Handle validation errors
      return response.text().then(html => {
        // Still process the turbo-stream response even for validation errors
        Turbo.renderStreamMessage(html);
      });
    }
  })
  .catch(error => {
    console.error('Error saving contact:', error);
    alert('An error occurred while saving the contact.');
  });
}
