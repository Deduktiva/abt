# Migrating from mod_passenger to Puma

ABT used to run as Apache + mod_passenger. The new topology runs Puma as a systemd user unit under the `abt` user, with Apache acting purely as a TLS-terminating reverse proxy. Apache reaches Puma over loopback TCP at `127.0.0.1:3000`.

`bin/production-update` handles the parts of the cutover that don't require root: installing systemd unit symlinks, running `daemon-reload`, and hot-restarting Puma. The steps below cover the things the script can't do — `apt` operations and root-owned Apache configuration.

Plan a maintenance window: there is a brief interruption when Apache moves off the old Passenger site onto the new reverse-proxy vhost.

## Prerequisites

- `loginctl enable-linger abt` already in place (the existing jobs worker depends on this; verify with `loginctl show-user abt | grep Linger=yes`).
- Recent backup (DB + `/srv/abt` filesystem snapshot, depending on infra).
- TCP port `3000` on `127.0.0.1` is free (Puma binds to it). Check with `ss -ltnp 'sport = :3000'`.

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

3. **Run `bin/production-update`.** As `abt`:
   ```bash
   /srv/abt/bin/production-update
   ```
   This bundles, symlinks the two new systemd units into `~/.config/systemd/user/`, runs `daemon-reload`, precompiles assets, migrates the DB, and attempts to reload Puma. The reload step will warn `"abt-puma.service is not installed or not enabled yet"` — that's expected on the first run.

4. **Enable and start the services.** As `abt` (one-time; subsequent deploys reuse the enable state):
   ```bash
   systemctl --user enable --now abt-puma.service abt-jobs.service
   systemctl --user status abt-puma.service abt-jobs.service
   ```
   Confirm Puma is listening on loopback:
   ```bash
   ss -ltnp 'sport = :3000'
   # LISTEN ... 127.0.0.1:3000 ... users:(("puma",...))
   ```

5. **Switch the Apache site config.** As root, in one motion — old Passenger site off, new reverse-proxy vhost on, then reload. Doing both at once avoids leaving Apache in a state where any *unrelated* reload (logrotate, certbot) would crash because Passenger has been disabled but a Passenger-referencing site is still enabled.
   ```bash
   sudo cp /srv/abt/deploy/apache/abt-vhost.conf.tpl /etc/apache2/sites-available/abt.conf
   sudo $EDITOR /etc/apache2/sites-available/abt.conf
   # Edit ServerName, SSL cert/key paths, log paths to match the host.

   sudo a2dissite <old-passenger-site>   # if applicable
   sudo a2ensite abt
   sudo apache2ctl configtest && sudo systemctl reload apache2
   ```

6. **Remove the Passenger packages** (now safe — no enabled site references Passenger):
   ```bash
   sudo apt remove libapache2-mod-passenger passenger
   ```

7. **Smoke test.**
   - `curl -I https://<your-host>/up` — expect HTTP 200.
   - `curl -I https://<your-host>/assets/<some-precompiled-asset>` — confirm `Cache-Control: public, max-age=31536000, immutable` (proves Apache is serving assets directly, not proxying to Puma).
   - Log in via the browser; create or open an invoice; preview a PDF (exercises FOP via the `FOP_EXTRA_JAR_PATH` env var injected by `abt-puma.service`).
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

## Behavior changes to be aware of

- `SOLID_QUEUE_IN_PUMA`: the `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]` line was removed from `config/puma.rb` (the dedicated `abt-jobs.service` unit always handles jobs). If you had `SOLID_QUEUE_IN_PUMA=1` set anywhere — environment file, shell profile — unset it. The variable is now silently ignored.
- `FOP_EXTRA_JAR_PATH`: previously injected into the Rails process via Apache's `SetEnv`. Under reverse-proxy that route doesn't work; it now ships inline in `deploy/systemd/abt-puma.service` and `abt-jobs.service` as `Environment=FOP_EXTRA_JAR_PATH=...`. To change the path, edit those units and `systemctl --user daemon-reload && systemctl --user restart abt-puma.service abt-jobs.service`.

## Rollback

If something is wrong and you need to fall back to Passenger:

1. As `abt`: `systemctl --user stop abt-puma.service`
2. As root: `sudo a2dissite abt`, re-enable the prior Passenger site config, reinstall the Passenger packages, `sudo systemctl reload apache2`.

The new systemd unit symlinks are harmless when stopped — leave them in place; the next forward attempt will be quicker.
