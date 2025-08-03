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
   ```

## Available Commands

- `./bin/postgres-dev start` - Start PostgreSQL container
- `./bin/postgres-dev stop` - Stop PostgreSQL container
- `./bin/postgres-dev setup` - Create and setup database
- `./bin/postgres-dev console` - Start Rails console with PostgreSQL
- `./bin/postgres-dev server` - Start Rails server with PostgreSQL
- `./bin/postgres-dev test` - Run tests with PostgreSQL
- `./bin/postgres-dev migrate` - Run database migrations
- `./bin/postgres-dev reset` - Drop, create, migrate and seed database
- `./bin/postgres-dev status` - Check container status

## Configuration

- **Database:** `abt_development_postgres`
- **Username:** `abt_user`
- **Password:** `abt_password`
- **Port:** `5433` (to avoid conflicts with system PostgreSQL)
- **Rails Environment:** `development_postgres`

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