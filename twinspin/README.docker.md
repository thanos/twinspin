# TwinSpin Docker Deployment Guide

This guide covers deploying TwinSpin using Docker and Docker Compose with full ODBC driver support for PostgreSQL, DB2, and Oracle databases.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Configuration](#configuration)
4. [ODBC Driver Setup](#odbc-driver-setup)
5. [Building and Running](#building-and-running)
6. [Production Deployment](#production-deployment)
7. [Monitoring and Maintenance](#monitoring-and-maintenance)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

- **Docker** 20.10+ or **Podman** 3.0+
- **Docker Compose** 2.0+ (or podman-compose)
- Minimum 2GB RAM available
- Minimum 10GB disk space

### Optional for DB2/Oracle Support

- IBM DB2 client libraries (for DB2 ODBC driver)
- Oracle Instant Client (for Oracle ODBC driver)

## Quick Start

### 1. Generate Secret Key Base

Before deploying, generate a secure secret key base:

```bash
# Generate a random secret key
openssl rand -base64 64 | tr -d '\n'
```

Save this value - you'll need it for the `SECRET_KEY_BASE` environment variable.

### 2. Configure Environment

Create a `.env` file in the project root:

```bash
# Required
SECRET_KEY_BASE=your_generated_secret_key_here
PHX_HOST=localhost

# Optional
POOL_SIZE=10
PORT=4000
```

### 3. Start the Application

```bash
# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f app

# Stop services
docker-compose down

# Stop and remove volumes (WARNING: deletes database data)
docker-compose down -v
```

The application will be available at http://localhost:4000

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SECRET_KEY_BASE` | Yes | - | Phoenix secret key (generate with `openssl rand -base64 64`) |
| `DATABASE_URL` | No | `ecto://postgres:postgres@postgres:5432/twinspin_prod` | PostgreSQL connection URL |
| `PHX_HOST` | No | `localhost` | Hostname for Phoenix endpoints |
| `PORT` | No | `4000` | HTTP port to listen on |
| `POOL_SIZE` | No | `10` | Database connection pool size |

### Docker Compose Override

For custom configurations, create a `docker-compose.override.yml`:

```yaml
version: '3.8'

services:
  app:
    environment:
      POOL_SIZE: 20
      PHX_HOST: twinspin.example.com
    ports:
      - "8080:4000"
```

## ODBC Driver Setup
### DB2 ODBC Driver (Optional)

To add DB2 support:

1. Download IBM DB2 client from IBM's website
2. Run the installation script inside the container:

```bash
docker-compose exec app /bin/bash
sh docker/scripts/install_db2_driver.sh
```

3. Follow the script prompts to complete installation
4. Update DSN settings in `docker/odbc/odbc.ini`
5. Restart the container: `docker-compose restart app`


To add DB2 support:

1. Download IBM DB2 client from IBM's website
2. Place the `libdb2o.so` file in `docker/odbc/drivers/`
3. Update `Dockerfile` to copy the driver:

```dockerfile
# In the runtime stage, add:
COPY --chown=app:app docker/odbc/drivers/libdb2o.so /opt/ibm/db2/clidriver/lib/
```

4. Uncomment the DB2 section in `docker/odbc/odbcinst.ini`
5. Update DSN settings in `docker/odbc/odbc.ini`

### Oracle ODBC Driver (Optional)

To add Oracle support:

1. Download Oracle Instant Client from Oracle's website
2. Run the installation script inside the container:

```bash
docker-compose exec app /bin/bash
sh docker/scripts/install_oracle_driver.sh
```

3. Follow the script prompts to complete installation
4. Update DSN settings in `docker/odbc/odbc.ini`
5. Restart the container: `docker-compose restart app`


To add Oracle support:

1. Download Oracle Instant Client from Oracle's website
2. Place the `libsqora.so.19.1` file in `docker/odbc/drivers/`
3. Update `Dockerfile` to copy the driver:

```dockerfile
# In the runtime stage, add:
COPY --chown=app:app docker/odbc/drivers/libsqora.so.19.1 /usr/lib/oracle/19.3/client64/lib/
```

4. Uncomment the Oracle section in `docker/odbc/odbcinst.ini`
5. Update DSN settings in `docker/odbc/odbc.ini`

### Configuring Data Sources

Edit `docker/odbc/odbc.ini` to add your database connections:

```ini
[MyDB2Connection]
Description = My DB2 Database
Driver = IBM DB2 ODBC DRIVER
Database = MYDB
Hostname = db2.example.com
Port = 50000
Protocol = TCPIP
UID = db2user
PWD = secret_password
```

**Security Note**: For production, use Docker secrets or environment variable substitution instead of hardcoding passwords.

## Building and Running

### Development Build

```bash
# Build the image
docker-compose build

# Start services
docker-compose up

# Or in detached mode
docker-compose up -d
```

### Production Build

```bash
# Build with production optimizations
docker-compose build --no-cache

# Start with production settings
docker-compose -f docker-compose.yml up -d
```

### Podman Alternative

If using Podman instead of Docker:

```bash
# Build
podman-compose build

# Run
podman-compose up -d

# Or run rootless
podman-compose --podman-run-args="--userns=keep-id" up -d
```

## Production Deployment

### Pre-Deployment Checklist

- [ ] Generate and set `SECRET_KEY_BASE`
- [ ] Configure `PHX_HOST` for your domain
- [ ] Update ODBC DSN configurations with production credentials
- [ ] Set up SSL/TLS termination (reverse proxy recommended)
- [ ] Configure firewall rules
- [ ] Set up backup strategy for PostgreSQL volume
- [ ] Configure monitoring and alerting

### Using a Reverse Proxy (Recommended)

Use Nginx, Caddy, or Traefik as a reverse proxy:

**Nginx Example:**

```nginx
server {
    listen 80;
    server_name twinspin.example.com;

    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Scaling Considerations

For high-load scenarios:

1. **Horizontal Scaling**: Run multiple app containers behind a load balancer
2. **Database Connection Pooling**: Increase `POOL_SIZE` based on load
3. **External PostgreSQL**: Use managed database service instead of container

Example scaling with Docker Compose:

```bash
docker-compose up -d --scale app=3
```

### Health Checks

The container includes a built-in health check that pings the root endpoint every 30 seconds:

```bash
# Check container health
docker ps
# Look for "healthy" status

# View health check logs
docker inspect --format='{{json .State.Health}}' twinspin-app | jq
```

## Monitoring and Maintenance

### Viewing Logs

```bash
# All logs
docker-compose logs

# Follow app logs
docker-compose logs -f app

# Follow PostgreSQL logs
docker-compose logs -f postgres

# Last 100 lines
docker-compose logs --tail=100 app
```

### Database Migrations

Migrations run automatically on container startup via `entrypoint.sh`. To run manually:

```bash
# Run pending migrations
docker-compose exec app bin/twinspin eval "Twinspin.Release.migrate"

# Rollback one migration
docker-compose exec app bin/twinspin eval "Twinspin.Release.rollback(Twinspin.Repo, 20240101120000)"
```

### Database Backups

**Automated Backup Script:**

```bash
#!/bin/bash
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose exec -T postgres pg_dump -U postgres twinspin_prod > "$BACKUP_DIR/twinspin_$DATE.sql"
```

**Restore from Backup:**

```bash
docker-compose exec -T postgres psql -U postgres twinspin_prod < /path/to/backup.sql
```

### Volume Management

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect twinspin_postgres_data

# Backup volume
docker run --rm -v twinspin_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_data_backup.tar.gz /data

# Restore volume
docker run --rm -v twinspin_postgres_data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres_data_backup.tar.gz -C /
```

### Updating the Application

```bash
# Pull latest changes
git pull

# Rebuild and restart
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Check logs for successful startup
docker-compose logs -f app
```

## Troubleshooting

### Container Won't Start

**Check logs:**
```bash
docker-compose logs app
```

**Common issues:**
- Missing `SECRET_KEY_BASE` - Set in `.env` file
- PostgreSQL not ready - Container will retry automatically
- Port 4000 already in use - Change `PORT` environment variable

### ODBC Connection Failures

**Test ODBC configuration:**
```bash
# Enter container
docker-compose exec app bash

# Test ODBC drivers
odbcinst -q -d

# Test DSN connection
isql -v PostgreSQL-Production
```

**Common issues:**
- Driver not found - Check `/etc/odbcinst.ini` paths
- DSN not found - Check `/app/odbc/odbc.ini` configuration
- Connection refused - Verify host/port in DSN settings

### Database Connection Issues

**Check PostgreSQL status:**
```bash
docker-compose exec postgres pg_isready -U postgres
```

**Check DATABASE_URL format:**
```
ecto://username:password@hostname:port/database
```

### Performance Issues

**Check container resources:**
```bash
docker stats twinspin-app
```

**Recommendations:**
- Increase `POOL_SIZE` for high concurrency
- Scale horizontally with `--scale app=N`
- Use external PostgreSQL for better performance
- Add Redis for caching (future enhancement)

### Migration Failures

**View migration status:**
```bash
docker-compose exec app bin/twinspin eval "Ecto.Migrator.migrations(Twinspin.Repo)"
```

**Force migration:**
```bash
docker-compose exec app bin/twinspin eval "Twinspin.Release.migrate"
```

## Security Best Practices

1. **Never commit sensitive data** - Use environment variables or Docker secrets
2. **Run as non-root** - Container runs as UID 1000 (already configured)
3. **Keep base images updated** - Rebuild regularly with `--no-cache`
4. **Use TLS** - Always deploy behind HTTPS reverse proxy
5. **Restrict network access** - Use firewall rules or Docker networks
6. **Rotate secrets** - Change `SECRET_KEY_BASE` periodically
7. **Audit ODBC configs** - Never store passwords in `odbc.ini` for production

## Support

For issues or questions:
- Check application logs: `docker-compose logs -f app`
- Review this documentation
- Check container health: `docker ps`

## License

TwinSpin - Database Reconciliation Platform

