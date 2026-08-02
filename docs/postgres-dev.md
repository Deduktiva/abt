# PostgreSQL Development Environment

This setup allows you to test against PostgreSQL locally using containers, which mirrors the production environment more closely than SQLite.

## Prerequisites

You need either:
- **Podman** with `podman-compose` (recommended)
- **Docker** with `docker-compose`

## Quick Start

1. **Start PostgreSQL container:**
   ```bash
   ./bin/postgres-dev start
   ```

2. **Setup database:**
   ```bash
   ./bin/postgres-dev setup
   ```

3. **Run Rails server with PostgreSQL:**
   ```bash
   ./bin/postgres-dev server
   ```

4. **Run tests with PostgreSQL:**
   ```bash
   ./bin/postgres-dev test
   ./bin/postgres-dev test test/models/invoice_test.rb   # extra args go to `rails test`
   ```

## Available Commands

- `./bin/postgres-dev start` - Start PostgreSQL container
- `./bin/postgres-dev stop` - Stop PostgreSQL container
- `./bin/postgres-dev setup` - Create and setup development database
- `./bin/postgres-dev console` - Start Rails console with PostgreSQL
- `./bin/postgres-dev server` - Start Rails server with PostgreSQL
- `./bin/postgres-dev test` - Run tests against PostgreSQL
- `./bin/postgres-dev system-test` - Run system tests against PostgreSQL, headless
- `./bin/postgres-dev test-reset` - Drop and recreate the PostgreSQL test database
- `./bin/postgres-dev migrate` - Run database migrations
- `./bin/postgres-dev reset` - Drop, create, migrate and seed development database
- `./bin/postgres-dev status` - Check container status

## Configuration

- **Database:** `abt_development` (dev lane), `abt_test` (test lane)
- **Username:** `abt_user`
- **Password:** `abt_password`
- **Port:** `5433` (to avoid conflicts with system PostgreSQL)
- **Rails Environment:** `development_postgres` (dev lane), `test` (test lane)

## The Test Lane

The test lane deliberately mirrors `.github/workflows/ci.yml`: it runs with
`RAILS_ENV=test` and points `DATABASE_URL` at the container. Rails applies
`DATABASE_URL` to the **primary** database only, so the Solid Cache and Solid
Queue databases stay on SQLite here exactly as they do in CI.

A separate `test_postgres` environment is not an option — `test/test_helper.rb`
sets `ENV["RAILS_ENV"] = "test"` unconditionally, so any other `RAILS_ENV`
passed to a test run is silently discarded and the suite lands back on SQLite.
`DATABASE_URL` is the only override that survives that.

This is the only lane that exercises row locking. Rails' SQLite adapter silently
drops the lock clause — `Invoice.lock.to_sql` yields `SELECT "invoices".* FROM
"invoices"` on SQLite and `... FOR UPDATE` on PostgreSQL — so `with_lock` /
`lock!` in `InvoicePublisher`, `OfferMilestoneConverter`, `DocumentNumber` and
friends still opens a transaction in the default `bundle exec rails test` run but
takes no row lock. Any change to a lock or a concurrency guard should be checked
here.

`db:prepare` runs before every test invocation: it creates and seeds `abt_test`
on first use and applies pending migrations afterwards. Use `test-reset` to
start over.

On macOS the lane exports `PGGSSENCMODE=disable`. Without it the precompiled
`pg` darwin gem segfaults in `PG::Connection#connect_start` in every worker as
soon as the suite crosses the 50-test parallelisation threshold and Rails forks
— libpq reaches into the macOS GSS framework, which is not fork-safe. CI runs on
Linux and never hits this.

Migrating a non-development environment no longer rewrites `db/schema.rb`
(`config.active_record.dump_schema_after_migration` in `config/application.rb`),
so the PostgreSQL lanes can't leave the SQLite lane with a schema it cannot load.

## Database Connection

The PostgreSQL container runs on port 5433 to avoid conflicts with any system PostgreSQL installation on the default port 5432.

## Data Persistence

Database data is persisted in a Docker/Podman volume named `postgres_dev_data`, so your data will survive container restarts.

## Troubleshooting

1. **Container won't start:** Check if port 5433 is already in use
2. **Connection refused:** Wait for the container to fully start (health check takes ~30s)
3. **Permission errors:** Make sure the postgres-dev script is executable: `chmod +x bin/postgres-dev`

## Why Use This?

- **Production parity:** PostgreSQL behavior matches production
- **Catch database-specific issues early:** Avoid SQLite vs PostgreSQL differences
- **Test migrations:** Ensure migrations work on PostgreSQL
- **Performance testing:** PostgreSQL performance characteristics
