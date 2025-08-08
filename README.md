Abt
===

Rails app to print invoices, basically.

Has a customer, project, product list, and invoices. Knows about tax classes.

Exports invoices to PDF.


Dependencies
------------

### System Packages

#### Debian/Ubuntu
```bash
sudo apt-get install build-essential ruby-dev libyaml-dev
```

#### macOS (Homebrew)
```bash
brew install libyaml
```

### Ruby Dependencies
```bash
bundle install
```

### Additional Software
- Apache FOP 2.10 for PDF generation (run `./script/setup-fop.sh` for automated setup)
- PostgreSQL (production)
- Web server

