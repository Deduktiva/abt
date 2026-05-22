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


Authentication setup
--------------------

ABT uses GitHub OAuth for sign-in. There are no passwords — users are
created via invite links, and each user is linked to a GitHub account.

### 1. Register a GitHub OAuth app

Go to **GitHub → Settings → Developer settings → OAuth Apps → New OAuth
App** (personal: https://github.com/settings/developers, or under an
organization's developer settings).

- **Application name** — anything, e.g. `ABT` (or `ABT (staging)`)
- **Homepage URL** — your deployment URL, e.g. `https://abt.example.com`
  (use `http://localhost:3000` for local development)
- **Authorization callback URL** — must exactly match the path the app
  uses:
  - Development: `http://localhost:3000/auth/github/callback`
  - Production: `https://abt.example.com/auth/github/callback`

  GitHub supports multiple callback URLs on one app; you can register
  dev + prod on the same app, or use separate apps per environment
  (cleaner for secret rotation). Mismatch causes a `redirect_uri_mismatch`
  error from GitHub on sign-in.

After creating the app, copy the **Client ID** and generate a **Client
secret** (shown only once — copy it immediately).

### 2. Store the credentials

Add them to Rails encrypted credentials:

```bash
bin/rails credentials:edit
```

Add:

```yaml
github:
  client_id: Iv1.abcdef1234567890
  client_secret: 0123456789abcdef0123456789abcdef01234567
```

`config/master.key` must be present in any environment where the app
runs. It is gitignored — copy it to production hosts out-of-band, or
set `RAILS_MASTER_KEY` as an environment variable.

### 3. Create the first user

There are no users yet, so no one can log in or create invites through
the UI. Bootstrap the first user with the rake task that prints an
invite URL:

```bash
bundle exec rails users:invite
# => http://localhost:3000/invites/bOgEgh57stifNleFL7rLQvNt8OFIcewwbN8utCukHds
```

The task prints a URL using `ENV["APP_HOST"]` (defaults to
`http://localhost:3000`). For production:

```bash
APP_HOST=https://abt.example.com bundle exec rails users:invite
```

Open the URL in a browser, click **Continue with GitHub**, approve the
OAuth consent, then pick a username and full name. You are now signed
in. Subsequent users can be onboarded the same way by clicking
**Invites → Create invite** in the Configuration menu and sharing the
resulting URL.

Invite links are single-use and expire 24 hours after creation.

### 4. Passkey configuration

Passkeys (WebAuthn / FIDO2) let users sign in with a security key, phone,
or laptop biometric instead of GitHub. Each user can register multiple
passkeys from their **My profile → My passkeys** page.

WebAuthn pins the credential to a specific **origin** (scheme + host +
port) for anti-phishing. Configure it per-environment in `config/settings/`:

- `config/settings/development.yml` — `webauthn.origin: 'http://localhost:3000'` (already set).
- `config/settings/test.yml` — `webauthn.origin: 'http://www.example.com'` (already set).
- `config/settings/production.yml` — copy from `production.yml.tpl` and
  edit `webauthn.origin` to match your deployment's public URL exactly.

The app refuses to boot when `webauthn.origin` is blank — silently
defaulting would defeat the anti-phishing property.
