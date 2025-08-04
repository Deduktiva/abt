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