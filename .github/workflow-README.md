# GitHub Workflows

This directory contains GitHub Actions workflows for the ABT invoice system.

## Workflows

### `ci.yml` - Continuous Integration
- **Triggers**: Push to master, pull requests to master
- **Jobs**:
  - **Lint and Security**: Runs bundler-audit and Brakeman security scanning
  - **Test Suite**: Runs full test suite for Ruby 3.3 with PostgreSQL
  - **FOP Container**: Tests the Apache FOP Docker container functionality


### `dependabot.yml` - Dependabot Auto-merge
- **Triggers**: Dependabot pull requests
- **Purpose**: Automatically approve and merge minor/patch dependency updates
- **Features**: Auto-approval for safe updates, squash merge strategy

## Dependabot Configuration

Located at `.github/dependabot.yml`, this configures automated dependency updates for:
- **Ruby gems** (bundler)
- **GitHub Actions**
- **Docker base images**

Updates are scheduled weekly on Mondays at 8:00 AM.

## FOP Integration

The workflows include Apache FOP support by:
1. Building the `Dockerfile.fop` container
2. Creating a wrapper script that uses Docker to run FOP
3. Adding the wrapper to the system PATH
4. Configuring test settings to use the FOP wrapper

This ensures that PDF generation tests work correctly in the CI environment.

## Requirements

- PostgreSQL 15 service for database tests
- Docker for FOP container
- Ruby 3.2 or 3.3 with bundler
- Node.js 18 for asset compilation (if needed)

## Test Configuration

The workflows automatically create a `config/settings/test.yml` file with:
- FOP binary path pointing to the Docker wrapper
- Test payment URL configuration

This ensures tests run consistently across different environments.
