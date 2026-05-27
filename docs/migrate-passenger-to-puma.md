# Migrating from mod_passenger to Puma

ABT used to run as Apache + mod_passenger. The new topology runs Puma as a systemd user unit under the `abt` user, with Apache acting purely as a TLS-terminating reverse proxy.

`bin/production-update` handles the parts of the cutover that don't require root: installing systemd unit symlinks, running `daemon-reload`, and hot-restarting Puma. The steps below cover the things the script can't do — `apt` operations and root-owned Apache configuration.

Plan a maintenance window: Apache reload + first Puma start has a brief interruption.

## Prerequisites

- `loginctl enable-linger abt` already in place (the existing jobs worker depends on this; verify with `loginctl show-user abt | grep Linger=yes`).
- Recent backup (DB + `/srv/abt` filesystem snapshot, depending on infra).

## Steps

1. **Pull the new code.** As `abt`:
   ```bash
   cd /srv/abt
   git pull --rebase
   ```

2. **Enable the required Apache modules.** As root:
   ```bash
   sudo a2enmod proxy proxy_http headers
   ```

3. **Replace the Apache site config.** Disable any Passenger-enabled site that points at ABT, then install the new wrapper using [`deploy/apache/abt-vhost.conf.tpl`](../deploy/apache/abt-vhost.conf.tpl) as the starting template:
   ```bash
   sudo cp /srv/abt/deploy/apache/abt-vhost.conf.tpl /etc/apache2/sites-available/abt.conf
   sudo $EDITOR /etc/apache2/sites-available/abt.conf
   # Edit ServerName, SSL cert/key paths, log paths to match the host.
   sudo a2dissite <old-passenger-site>   # if applicable
   sudo a2ensite abt
   sudo apache2ctl configtest
   ```
   Don't reload Apache yet — the Puma socket doesn't exist.

4. **Remove the Passenger packages** (cosmetic; the Apache config no longer references Passenger):
   ```bash
   sudo apt remove libapache2-mod-passenger passenger
   ```

5. **Run `bin/production-update`.** As `abt`:
   ```bash
   /srv/abt/bin/production-update
   ```
   This bundles, symlinks the two new systemd units into `~/.config/systemd/user/`, runs `daemon-reload`, precompiles assets, migrates the DB, and attempts to reload Puma. The reload step will warn `"abt-puma.service is not installed or not enabled yet"` — that's expected on the first run.

6. **Enable and start the services.** As `abt` (one-time; subsequent deploys reuse the enable state):
   ```bash
   systemctl --user enable --now abt-puma.service abt-jobs.service
   systemctl --user status abt-puma.service abt-jobs.service
   ```
   Confirm Puma has bound `/srv/abt/tmp/sockets/puma.sock`:
   ```bash
   ls -l /srv/abt/tmp/sockets/puma.sock
   ```

7. **Reload Apache.** As root:
   ```bash
   sudo systemctl reload apache2
   ```

8. **Smoke test.**
   - `curl -I https://<your-host>/up` — expect HTTP/2 200.
   - Log in via the browser; create or open an invoice; preview a PDF.
   - Send a test bulk email and confirm the jobs worker picks it up:
     ```bash
     journalctl --user -u abt-jobs.service -n 50
     ```
   - Verify scheme detection inside the Rails console:
     ```bash
     RAILS_ENV=production bundle exec rails runner \
       'puts Rails.application.routes.url_helpers.root_url'
     ```
     Should return an `https://` URL.

## Rollback

If something is wrong and you need to fall back to Passenger:

1. As `abt`: `systemctl --user stop abt-puma.service`
2. As root: `sudo a2dissite abt`, re-enable the prior Passenger site config, reinstall the Passenger packages, `sudo systemctl reload apache2`.

The new systemd unit symlinks are harmless when stopped — leave them in place; the next forward attempt will be quicker.
