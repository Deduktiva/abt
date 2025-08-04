# Container-Based Deployment for ABT

This document describes the new container-based deployment system for ABT, designed to support both the main application and future services like paperless-ngx.

## Overview

The new deployment architecture uses containers to provide:
- **Isolation**: Each service runs in its own container
- **Scalability**: Easy to scale components independently
- **Consistency**: Same environment from development to production
- **Future-proofing**: Ready for additional services like paperless-ngx

## Architecture

### Production Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Host VM (Debian Trixie)                  │
│                                                             │ 
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  │   Apache2       │  │   PostgreSQL    │  │   Tailscale     │
│  │ (Reverse Proxy) │  │  (Host Service) │  │  (Host Service) │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘
│           │                      │
│           ▼                      │
│  ┌─────────────────────────────────────────────────────────────┐
│  │              Container Network                              │
│  │                                                             │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  │ ABT WebApp  │  │ ABT Worker  │  │   Redis     │         │
│  │  │ (Apache+    │  │ (ActiveJob) │  │ (Message    │         │
│  │  │  Passenger) │  │             │  │  Broker)    │         │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │
│  │                                                             │
│  │  ┌─ Future: Paperless-NGX Containers ──────────────┐       │
│  │  │ (To be added in future iteration)               │       │
│  │  └─────────────────────────────────────────────────┘       │
│  └─────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────┘
```

### Components

1. **ABT WebApp Container**
   - Rails application with Apache2 + Passenger
   - Handles HTTP requests
   - Port 8080 (internal)

2. **ABT Worker Container**
   - Same Rails codebase as webapp
   - Runs ActiveJob workers for background tasks
   - Processes email sending, PDF generation

3. **Redis Container**
   - Message broker for ActiveJob
   - Lightweight, Alpine-based image

4. **Host Services**
   - **PostgreSQL**: Runs directly on host, shared with containers
   - **Apache2**: Reverse proxy for subdirectory routing
   - **Tailscale**: VPN access (unchanged)

## Deployment Process

### Production Deployment

1. **Initial Setup**
   ```bash
   # Copy and configure environment
   cp .env.production.example .env.production
   # Edit .env.production with your values
   
   # Ensure PostgreSQL is running on host
   systemctl status postgresql
   ```

2. **Deploy Containers**
   ```bash
   # Deploy using the automated script
   ./script/container-deploy
   ```

3. **Configure Reverse Proxy**
   ```bash
   # Copy Apache configuration
   sudo cp docker/apache2-reverse-proxy.conf /etc/apache2/sites-available/abt-proxy.conf
   
   # Enable required modules
   sudo a2enmod proxy proxy_http headers rewrite ssl
   
   # Enable site
   sudo a2ensite abt-proxy
   sudo systemctl reload apache2
   ```

### Local Development

1. **Setup Development Environment**
   ```bash
   # Initial setup (one time)
   ./script/container-dev setup
   
   # Start development environment
   ./script/container-dev start
   ```

2. **Access Services**
   - ABT webapp: http://localhost:3000
   - PostgreSQL: localhost:5433
   - Redis: localhost:6380

3. **Development Commands**
   ```bash
   ./script/container-dev shell     # Open shell in webapp container
   ./script/container-dev console   # Rails console
   ./script/container-dev test      # Run test suite
   ./script/container-dev logs      # View logs
   ```

## Container Images

### Production Images
- Built by GitHub Actions on every push to master
- Stored in GitHub Container Registry (ghcr.io)
- Automatically pulled by deployment script

### Image Types
1. **abt-webapp**: Apache + Passenger + Rails app
2. **abt-worker**: Rails app configured for ActiveJob
3. **development**: Development environment with mounted source

## Configuration

### Environment Variables

**Production** (`.env.production`):
```bash
# Database
ABT_DB_PASSWORD=secure-password

# Application
SECRET_KEY_BASE=very-long-secret-key

# Mailgun
MAILGUN_API_KEY=your-api-key
MAILGUN_DOMAIN=your-domain.com

# Company
ISSUER_COMPANY_NAME=Your Company
ISSUER_COMPANY_SHORT_NAME=YourCo
```

**Development**: Uses built-in defaults for local testing

### Subdirectory Support

The application supports running under a subdirectory path (e.g., `/abt/`) for reverse proxy deployments:

- **Automatic Detection**: Reads `X-Forwarded-Prefix` header from proxy
- **Manual Override**: Set `RAILS_RELATIVE_URL_ROOT` environment variable
- **Asset Handling**: Rails automatically adjusts asset paths

## Database Integration

### Production
- PostgreSQL runs directly on host VM
- Containers connect via `host.containers.internal`
- Existing database and user account are used
- No changes to database structure or access

### Development
- PostgreSQL runs in container
- Isolated development database
- Can be reset/recreated without affecting other environments

## Monitoring and Maintenance

### Health Checks
- All containers include health checks
- Deployment script waits for healthy status
- Automatic restart on failure

### Logs
- Centralized logging in container volumes
- Access via: `podman-compose logs -f`
- Persistent across container restarts

### Updates
```bash
# Production updates
./script/container-deploy  # Pulls latest images and redeploys

# Development updates
./script/container-dev restart  # Rebuilds and restarts
```

## Security Features

- **Containers run as non-root user** (abtuser, uid 1000)
- **Security headers** configured in Apache
- **Image scanning** via Trivy in CI/CD
- **Minimal base images** (Debian slim)
- **Network isolation** via container networks

## Future: Paperless-NGX Integration

The architecture is designed to support paperless-ngx:

1. **Shared PostgreSQL**: Paperless will use same host PostgreSQL with separate credentials
2. **Reverse Proxy**: Apache will route `/paperless/` to paperless containers
3. **Shared Secrets**: Mailgun credentials shared between services
4. **Communication**: ABT can communicate with paperless via container network

## Migration from Traditional Deployment

### What Changes
- Application runs in containers instead of directly on host
- ActiveJob workers run in separate container
- Redis added for job queue management

### What Stays the Same
- PostgreSQL database and data (unchanged)
- Apache2 on host (now as reverse proxy)
- Tailscale networking
- DNS and SSL configuration
- File system paths for logs and data

### Migration Steps
1. **Backup**: Create database backup before migration
2. **Install**: Install podman/podman-compose
3. **Configure**: Set up environment files
4. **Deploy**: Run container deployment
5. **Test**: Verify all functionality works
6. **Proxy**: Configure Apache reverse proxy
7. **Cleanup**: Remove old deployment files (optional)

## Troubleshooting

### Common Issues

**Container build fails**:
```bash
# Check available space
df -h
# Clean up old images
podman system prune -a
```

**Database connection fails**:
```bash
# Check PostgreSQL is running
systemctl status postgresql
# Verify user permissions
sudo -u postgres psql -c "\du"
```

**Permission errors**:
```bash
# Ensure correct ownership
sudo chown -R 1000:1000 /path/to/app/logs
```

### Log Locations
- **Container logs**: `podman-compose logs -f <service>`
- **Apache logs**: `/var/log/apache2/`
- **Application logs**: Container volume `abt_logs`

## Scripts Reference

### Production
- `./script/container-deploy`: Full production deployment
- `./script/production-update`: Legacy deployment (still works)

### Development  
- `./script/container-dev setup`: Initial development setup
- `./script/container-dev start/stop/restart`: Manage dev environment
- `./script/container-dev shell/console/test`: Development tools

## Performance Considerations

### Resource Usage
- **Memory**: ~500MB per Rails container
- **CPU**: Minimal when idle
- **Storage**: ~2GB for images, logs grow over time

### Scaling
- **Horizontal**: Add more webapp containers behind load balancer
- **Vertical**: Increase container resource limits
- **Database**: PostgreSQL remains on host for performance

This containerized deployment provides a robust, scalable foundation for ABT while preparing for future service integration.