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
# For system tests (Chrome dependencies)
sudo apt-get install libatk1.0-0 libatk-bridge2.0-0 libdrm2 libgtk-3-0 libgbm1 libasound2
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

### Pre-commit Hooks (Optional)
For automatic whitespace cleanup and code quality checks:
```bash
# Install pre-commit
# Debian/Ubuntu:
sudo apt install pre-commit
# macOS with Homebrew:
brew install pre-commit
# or with pip:
pip install pre-commit

# Install the hooks (run from repository root)
pre-commit install

# Optional: run on all existing files
pre-commit run --all-files
```
