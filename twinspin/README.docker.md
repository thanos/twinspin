# TwinSpin Docker/Podman Setup

This guide covers running TwinSpin in containers using either Docker or Podman.

## Prerequisites

### For Docker
- Docker Engine 20.10+
- Docker Compose 2.0+

### For Podman (Recommended for rootless containers)
- Podman 4.0+
- podman-compose (install via `pip install podman-compose`)

## Quick Start

### Using Docker Compose

```bash
# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f app

# Stop services
docker-compose down

# Stop and remove volumes (WARNING: destroys data)
docker-compose down -v
```

### Using Podman Compose

```bash
# Build and start all services
podman-compose up -d

# View logs
podman-compose logs -f app

# Stop services
podman-compose down

# Stop and remove volumes (WARNING: destroys data)
podman-compose down -v
```

## Manual Build and Run

### Build the Image

#### Docker
```bash
docker build -t twinspin:latest .
```

#### Podman
```bash
podman build -t twinspin:latest .
```

### Run PostgreSQL Container

#### Docker
```bash
docker run -d \
  --name twinspin-db \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=twinspin_prod \
  -p 5432:5432 \
  -v twinspin_postgres:/var/lib/postgresql/data \
  postgres:15-alpine
```

#### Podman
```bash
podman run -d \
  --name twinspin-db \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=twinspin_prod \
  -p 5432:5432 \
  -v twinspin_postgres:/var/lib/postgresql/data \
  postgres:15-alpine
```

### Run TwinSpin Container

#### Docker
```bash
docker run -d \
  --name twinspin-app \
  --link twinspin-db:db \
  -e DATABASE_URL="ecto://postgres:postgres@db:5432/twinspin_prod" \
  -e SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  -e PHX_HOST=localhost \
  -e PORT=4000 \
  -p 4000:4000 \
  twinspin:latest
```

#### Podman
```bash
# Create a pod (Podman's equivalent to docker-compose networking)
podman pod create --name twinspin-pod -p 4000:4000 -p 5432:5432

# Run PostgreSQL in the pod
podman run -d \
  --pod twinspin-pod \
  --name twinspin-db \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=twinspin_prod \
  -v twinspin_postgres:/var/lib/postgresql/data \
  postgres:15-alpine

# Wait for PostgreSQL to be ready
sleep 10

# Run TwinSpin in the pod
podman run -d \
  --pod twinspin-pod \
  --name twinspin-app \
  -e DATABASE_HOST=localhost \
  -e DATABASE_PORT=5432 \
  -e DATABASE_USER=postgres \
  -e DATABASE_PASSWORD=postgres \
  -e DATABASE_NAME=twinspin_prod \
  -e SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  -e PHX_HOST=localhost \
  -e PORT=4000 \
  twinspin:latest
```

## Environment Variables

### Required Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `DATABASE_URL` | Full database connection URL | - | `ecto://user:pass@host:5432/db` |
| `DATABASE_HOST` | Database hostname | `db` | `localhost` or `db` |
| `DATABASE_PORT` | Database port | `5432` | `5432` |
| `DATABASE_USER` | Database username | `postgres` | `postgres` |
| `DATABASE_PASSWORD` | Database password | `postgres` | `your-secure-password` |
| `DATABASE_NAME` | Database name | `twinspin_prod` | `twinspin_prod` |
| `SECRET_KEY_BASE` | Phoenix secret key | - | Generate with `mix phx.gen.secret` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PHX_HOST` | Phoenix host | `localhost` |
| `PHX_SERVER` | Start Phoenix server | `true` |
| `PORT` | Application port | `4000` |
| `POOL_SIZE` | Database pool size | `10` |
| `OBAN_QUEUES` | Oban queue configuration | `default:10,reconciliation:5` |

## Generating SECRET_KEY_BASE

You must generate a secure secret key base before running in production:

```bash
# Using mix (requires Elixir installed locally)
mix phx.gen.secret

# Or use OpenSSL
openssl rand -base64 64
```

Update the `docker-compose.yml` file or pass via environment variable:

```bash
export SECRET_KEY_BASE="your-generated-secret-here"
```

## Accessing the Application

Once running, access TwinSpin at:
- **Local**: http://localhost:4000
- **Health check**: http://localhost:4000/

## Database Migrations

Migrations run automatically on container startup via the `entrypoint.sh` script.

To run migrations manually:

#### Docker
```bash
docker exec -it twinspin-app /app/bin/twinspin eval "Twinspin.Release.migrate"
```

#### Podman
```bash
podman exec -it twinspin-app /app/bin/twinspin eval "Twinspin.Release.migrate"
```

## Troubleshooting

### View Application Logs

#### Docker
```bash
docker logs -f twinspin-app
```

#### Podman
```bash
podman logs -f twinspin-app
```

### Access Application Shell (IEx)

#### Docker
```bash
docker exec -it twinspin-app /app/bin/twinspin remote
```

#### Podman
```bash
podman exec -it twinspin-app /app/bin/twinspin remote
```

### Database Connection Issues

1. Ensure PostgreSQL is running and healthy:
   ```bash
   docker exec twinspin-db pg_isready -U postgres
   # or
   podman exec twinspin-db pg_isready -U postgres
   ```

2. Check database logs:
   ```bash
   docker logs twinspin-db
   # or
   podman logs twinspin-db
   ```

3. Verify network connectivity (Docker Compose creates a bridge network automatically)

### Container Won't Start

1. Check if port 4000 is already in use:
   ```bash
   lsof -i :4000
   ```

2. Verify SECRET_KEY_BASE is set properly

3. Check container logs for errors

## Production Deployment

### Security Considerations

1. **Change default passwords** in `docker-compose.yml`
2. **Generate a secure SECRET_KEY_BASE** (see above)
3. **Use secrets management** instead of environment variables for sensitive data
4. **Enable SSL/TLS** for production (consider using a reverse proxy like nginx)
5. **Restrict database access** to the application network only
6. **Regular backups** of the PostgreSQL volume

### Volume Backup

#### Docker
```bash
# Backup PostgreSQL data
docker run --rm -v twinspin_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/twinspin-db-backup.tar.gz /data

# Restore
docker run --rm -v twinspin_postgres_data:/data -v $(pwd):/backup alpine tar xzf /backup/twinspin-db-backup.tar.gz -C /
```

#### Podman
```bash
# Backup PostgreSQL data
podman run --rm -v twinspin_postgres_data:/data -v $(pwd):/backup:Z alpine tar czf /backup/twinspin-db-backup.tar.gz /data

# Restore
podman run --rm -v twinspin_postgres_data:/data -v $(pwd):/backup:Z alpine tar xzf /backup/twinspin-db-backup.tar.gz -C /
```

## Rootless Podman Setup

Podman supports rootless containers out of the box. The Dockerfile creates a non-root `app` user (UID 1000).

### Enable Rootless Podman

```bash
# Install podman (varies by OS)
# Fedora/RHEL
sudo dnf install podman

# Ubuntu/Debian
sudo apt install podman

# Enable lingering for your user (allows services to run after logout)
loginctl enable-linger $USER
```

### Run Rootless

All the commands above work the same in rootless mode. Podman automatically maps user namespaces.

## Performance Tuning

### Database Connection Pool

Adjust `POOL_SIZE` based on your workload:
- Light usage: 5-10 connections
- Medium usage: 10-20 connections
- Heavy usage: 20-50 connections

### Oban Workers

Tune worker counts in `OBAN_QUEUES`:
```bash
OBAN_QUEUES="default:10,reconciliation:20"
```

More workers = more concurrent reconciliation jobs, but higher resource usage.

## Systemd Service (Podman)

For production Podman deployments, generate systemd services:

```bash
# Generate service files
podman generate systemd --new --files --name twinspin-pod

# Move to systemd directory
mkdir -p ~/.config/systemd/user/
mv *.service ~/.config/systemd/user/

# Enable and start
systemctl --user enable --now pod-twinspin-pod.service
systemctl --user enable --now container-twinspin-app.service
systemctl --user enable --now container-twinspin-db.service
