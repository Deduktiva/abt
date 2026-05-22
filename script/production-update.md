# Production Deployment Scripts

This directory contains scripts for managing the ABT application in production.

## production-update

Automated production deployment script that handles the complete deployment process.

### Usage

```bash
# Run from the ABT application root directory as the application user
./script/production-update
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

4. **Asset Compilation**
   - Runs `bundle exec rails assets:precompile`

5. **Database Migration**
   - Runs `bundle exec rails db:migrate`

6. **Application Restart**
   - Creates `tmp/restart.txt` for Passenger to restart the app

7. **Jobs Worker Restart**
   - Runs `systemctl --user restart abt-jobs.service` to restart the Solid Queue worker so it picks up new code and updated recurring schedules. See "Solid Queue jobs worker" below for one-time setup.

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

### Output

The script provides colored output:
- 🔵 **[INFO]** - Status information
- 🟢 **[SUCCESS]** - Successful completion of a step  
- 🟡 **[WARNING]** - Warnings that don't stop execution
- 🔴 **[ERROR]** - Errors that stop execution

### Application Restart

The script creates `tmp/restart.txt` which tells Passenger to restart the application automatically. This handles the restart without requiring elevated privileges.

## Solid Queue jobs worker

ABT uses Solid Queue (database-backed Active Job adapter) for background work and scheduled jobs. The worker process is `bin/jobs`, which runs the queue worker, dispatcher, and recurring-job scheduler together. It is required for:

- Emails enqueued via `deliver_later`.
- The `overdue_invoices_report` recurring job (sends a bi-daily overdue-invoice report to the issuer's `document_email_auto_bcc` address; configured in `config/recurring.yml`).

The worker connects to the dedicated `queue` database defined in `config/database.yml`. The schema is in `db/queue_schema.rb` and is loaded automatically by `bin/rails db:prepare`.

### One-time setup (per host, as the application user)

1. **Enable user lingering** so user-level systemd services keep running after logout. This must be done once by an administrator with `sudo` access (the `production-update` script does not call `sudo`):

   ```bash
   sudo loginctl enable-linger <app-user>
   ```

2. **Create the systemd user unit** at `~/.config/systemd/user/abt-jobs.service`:

   ```ini
   [Unit]
   Description=ABT Solid Queue jobs worker
   After=network.target

   [Service]
   Type=simple
   WorkingDirectory=%h/abt
   Environment=RAILS_ENV=production
   Environment=PATH=%h/.rbenv/shims:/usr/local/bin:/usr/bin:/bin
   ExecStart=%h/abt/bin/jobs
   Restart=always
   RestartSec=5

   [Install]
   WantedBy=default.target
   ```

   Adjust `WorkingDirectory` and `Environment=PATH` to match the host (Ruby version manager, app path).

3. **Enable and start the service**:

   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now abt-jobs.service
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

The `production-update` script calls `systemctl --user restart abt-jobs.service` after the application restart. It is tolerant of the unit not being installed yet (prints a warning and continues) so the first deploy that introduces the worker does not abort. Once the unit is installed, every subsequent deploy restarts the worker so it picks up code changes and any updates to `config/recurring.yml`.
