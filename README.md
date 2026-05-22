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


Authentication
--------------

ABT uses passkeys (WebAuthn) for authentication. No passwords are stored anywhere. Users are created by invitation only.

### Bootstrapping the first user

Run the rake task to generate an invite URL, then open it in a browser to register the first passkey:

```bash
bundle exec rails users:invite
```

The task prints a one-time URL that is valid for 24 hours. Copy it to a browser, fill in username/full name/email, and register a passkey. After that the new user is signed in and can create further invites from the **Configuration → Users** menu.

### WebAuthn configuration

WebAuthn requires three settings in `config/settings.yml` (override per environment as needed in `config/settings/<env>.yml`):

- `app.host` / `app.protocol` — used by the rake task and email links to build absolute URLs.
- `webauthn.rp_id` — the **registrable domain** the app is served from (e.g. `app.example.com`). Must NOT include scheme or port.
- `webauthn.origin` — the exact `scheme://host[:port]` the browser uses. Must match the address bar exactly, including port.
- `webauthn.rp_name` — display name shown by the authenticator (e.g. "ABT").

Defaults are configured for `http://localhost:3000`. Update for staging and production deployments.

### Day-to-day usage

- Each user can manage their own passkeys, emails, sessions, and audit log under **My account** in the top-right nav.
- All authenticated users can administer other users via **Configuration → Users**: invite new users, block/unblock, replace emails, reset passkeys.
- Blocking a user immediately terminates every active session. Reset-passkeys deletes all of the user's passkeys and emails them a one-time invite to register a new one (which also auto-unblocks them).
