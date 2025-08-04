KNOWN BUGS
----------

Issuer Company page
~~~~~~~~~~~~~~~~~~~

* "Contact Line 1" and "Contact Line 2" fold whitespace on the show page, but this whitespace is significant.

Customers
~~~~~~~~~

* Customers which have been used are allowed to be deleted by the UI, however they should not be.
* Customers which have ever been used cannot be marked inactive, so the list when creating a new invoice is always very long.

Old pages
~~~~~~~~~

* The "Customer", "Project", "Product" show pages do not match their nice edit equivalents.

Sending emails fails but email is sent
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On the email preview page, clicking "Send E-Mail" ends in an error. Log from production server:

```
I, [2025-08-04T01:26:08.284802 #54959]  INFO -- : [81271d2e-57ef-466e-8786-4e88e80ed209] [ActiveJob] Enqueued ActionMailer::MailDeliveryJob (Job ID: 13ab958b-4f28-4e84-a410-aa61737989a2) to Async(default) with arguments: "InvoiceMailer", "customer_email", "deliver_now", {:params=>{:invoice=>#<GlobalID:0x0000ffff675669b0 @uri=#<URI::GID gid://abt/Invoice/340>>}, :args=>[]}
I, [2025-08-04T01:26:08.287434 #54959]  INFO -- : [81271d2e-57ef-466e-8786-4e88e80ed209] Completed 500 Internal Server Error in 10ms (ActiveRecord: 1.0ms | Allocations: 2663)
F, [2025-08-04T01:26:08.288767 #54959] FATAL -- : [81271d2e-57ef-466e-8786-4e88e80ed209]
[81271d2e-57ef-466e-8786-4e88e80ed209] ArgumentError (Unrecognized status code :sent):
[81271d2e-57ef-466e-8786-4e88e80ed209]
[81271d2e-57ef-466e-8786-4e88e80ed209] app/controllers/invoices_controller.rb:259:in `block (2 levels) in send_email'
[81271d2e-57ef-466e-8786-4e88e80ed209] app/controllers/invoices_controller.rb:257:in `send_email'
```
