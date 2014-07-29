Abt
===

Rails app to print invoices, basically.

Has a customer, project, product list, and invoices. Knows about tax classes.

Exports invoices to PDF.


Dependencies
------------

Bundler, fop, a web server.

A minimal Puppet deployment module is provided in `puppet/`. You'll need to find the fop jar files yourself.

