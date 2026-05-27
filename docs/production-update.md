# Production Deployment

`bin/production-update` is the automated deployment script for the ABT application in production. Production runs **Puma** behind **Apache 2.4** as a TLS-terminating reverse proxy; both Puma and the Solid Queue jobs worker are supervised as systemd **user** units under the application user. The unit files live in [`deploy/systemd/`](../deploy/systemd/) and the Apache include lives in [`deploy/apache/`](../deploy/apache/).

For a first-time cutover from the previous mod_passenger setup, see [`migrate-passenger-to-puma.md`](./migrate-passenger-to-puma.md).

## production-update

Automated production deployment script that handles the complete deployment process.

### Usage

```bash
# Run from the ABT application root directory as the application user
./bin/production-update
```

### What it does

The script sets `RAILS_ENV=production` for the entire session and performs the following steps in order:

1. **Validation Checks**
   - Verifies it's running in the correct ABT application directory
   - Checks user permissions for writing to application files
   - Warns about uncommitted changes

2. **Code Update**
   - Runs `git pull --rebase` to get latest code

3. **Dependencies**
   - Runs `bundle install` to install/update Ruby gems

4. **Systemd Unit Install**
   - Symlinks every `*.service` file in `deploy/systemd/` into `~/.config/systemd/user/` and runs `systemctl --user daemon-reload`. Idempotent — re-runs on every deploy so unit drift can't accumulate. Skips (and warns about) targets that already exist as non-symlinks so operator customizations aren't clobbered. Tolerant of an unreachable user systemd bus.

5. **Asset Compilation**
   - Runs `bundle exec rails assets:precompile`

6. **Database Migration**
   - Runs `bundle exec rails db:migrate`

7. **Application Restart**
   - Runs `systemctl --user reload abt-puma.service`, which `ExecReload`s `SIGUSR2` for a Puma hot-restart. Sub-second window where the listener is briefly closed; Apache buffers the request and retries.

8. **Jobs Worker Restart**
   - Runs `systemctl --user restart abt-jobs.service` to restart the Solid Queue worker so it picks up new code and updated recurring schedules.

### Requirements

- Must be run as the application user (user with write access to the app directory)
- Must be run from the ABT application root directory
- Git repository should be clean or user must confirm to continue

### Error Handling

The script will stop immediately if any step fails (`set -e`). Common issues:

- **Permission errors**: Make sure you're running as the application user
- **Git conflicts**: Resolve any merge conflicts manually before running
- **Bundle errors**: Check Ruby version and gem dependencies
- **Asset compilation errors**: Check for JavaScript/CSS syntax errors
- **Migration errors**: Check database connectivity and migration files

The systemd unit-install and restart steps are deliberately tolerant — they warn but do not abort the deploy — so a host without systemd reachable (or with units not yet enabled) still gets code/assets/migrations applied.

### Output

The script provides colored output:
- 🔵 **[INFO]** - Status information
- 🟢 **[SUCCESS]** - Successful completion of a step
- 🟡 **[WARNING]** - Warnings that don't stop execution
- 🔴 **[ERROR]** - Errors that stop execution

### Application Restart

`systemctl --user reload abt-puma.service` sends `SIGUSR2` (configured via `ExecReload` in the unit), triggering Puma's hot restart: the master forks a new process tree, boots a fresh app, and atomically swaps the listening socket. The single-worker setup has a sub-second window where new connections briefly fail; Apache's `ProxyPass` is configured to retry, so clients shouldn't notice.

If you changed `config/puma.rb` itself, or upgraded the Puma gem, a hot reload won't pick up boot-time settings. Use a full restart instead:

```bash
systemctl --user restart abt-puma.service
```

## Apache reverse proxy

Apache terminates TLS on `*:443` and reverse-proxies all dynamic requests to Puma over a Unix socket at `/srv/abt/tmp/sockets/puma.sock`. Precompiled assets (`/assets`, `/packs`, root-level `favicon.ico` etc.) are served by Apache directly.

App-owned directives live in [`deploy/apache/abt-app.conf`](../deploy/apache/abt-app.conf) and are pulled into a thin host-specific VirtualHost via `Include`. The template for that wrapper is [`deploy/apache/abt-vhost.conf.tpl`](../deploy/apache/abt-vhost.conf.tpl).

One-time setup on a fresh host:

```bash
sudo a2enmod proxy proxy_http headers
sudo cp deploy/apache/abt-vhost.conf.tpl /etc/apache2/sites-available/abt.conf
# edit ServerName, SSL cert paths, log paths in /etc/apache2/sites-available/abt.conf
sudo a2ensite abt
sudo apache2ctl configtest && sudo systemctl reload apache2
```

The `RequestHeader set X-Forwarded-Proto "https"` line in `abt-app.conf` is load-bearing — `config.action_dispatch.trusted_proxies` + `config.force_ssl` in `config/environments/production.rb` depend on it being set (not setifempty). Don't edit either file in isolation.

## Solid Queue jobs worker

ABT uses Solid Queue (database-backed Active Job adapter) for background work and scheduled jobs. The worker process is `bin/jobs`, which runs the queue worker, dispatcher, and recurring-job scheduler together. It is required for:

- Emails enqueued via `deliver_later`.
- The `overdue_invoices_report` recurring job (sends a bi-daily overdue-invoice report to the issuer's `document_email_auto_bcc` address; configured in `config/recurring.yml`).

The worker connects to the dedicated `queue` database defined in `config/database.yml`. The schema is in `db/queue_schema.rb` and is loaded automatically by `bin/rails db:prepare`.

### One-time setup (per host, as the application user)

1. **Enable user lingering** so user-level systemd services keep running after logout *and* so `/run/user/<uid>` exists for non-login shells (deploys, cron). The `production-update` script relies on this to find the user systemd bus — without it, `systemctl --user` from the deploy shell will fail with "Failed to connect to bus" and the script will warn that the unit cannot be reached. Run this once as an administrator with `sudo`:

   ```bash
   sudo loginctl enable-linger <app-user>
   ```

   Verify with `loginctl show-user <app-user> | grep Linger=yes` and confirm `/run/user/$(id -u <app-user>)/bus` exists.

2. **Run `bin/production-update` once** — it symlinks `deploy/systemd/abt-jobs.service` (and `abt-puma.service`) into `~/.config/systemd/user/` and runs `daemon-reload`. The first run will warn that `abt-puma.service` and `abt-jobs.service` aren't enabled yet; that's expected.

3. **Enable and start the services** (one-time; subsequent deploys reuse the enable state):

   ```bash
   systemctl --user enable --now abt-puma.service abt-jobs.service
   ```

### Running manually

If you need to run the worker by hand (e.g. for a one-off test before systemd is set up), always pass `RAILS_ENV=production`. Without it `bin/jobs` boots in development mode and Bundler tries to load gems that production deployments don't install:

```bash
RAILS_ENV=production bin/jobs
```

### Verifying the worker

```bash
systemctl --user status abt-jobs.service
journalctl --user -u abt-jobs.service -n 50
```

Confirm the recurring task is registered (after the worker has started at least once):

```bash
RAILS_ENV=production bundle exec rails runner \
  'puts SolidQueue::RecurringTask.pluck(:key, :schedule).inspect'
```

You should see `overdue_invoices_report` in the output alongside any other recurring tasks.

### Updates and restarts

The `production-update` script calls `systemctl --user restart abt-jobs.service` after the Puma reload. It is tolerant of the unit not being installed yet (prints a warning and continues) so the first deploy that introduces the worker does not abort. Once the unit is installed, every subsequent deploy restarts the worker so it picks up code changes and any updates to `config/recurring.yml`.
