# Docker Setup for Svix Webhooks

This directory contains a comprehensive Docker setup for the Svix Webhooks project, making it easy to run, develop, and deploy the entire stack.

## 🚀 Quick Start

### Production Setup

Start the complete Svix stack with one command:

```bash
# Build and start all core services
docker compose up -d

# View logs
docker compose logs -f svix-server

# Check service health
docker compose ps
```

### Development Setup

For development with hot reloading and debugging:

```bash
# Start development environment
docker compose -f docker-compose.dev.yml up -d

# Start with monitoring tools
docker compose -f docker-compose.dev.yml --profile monitoring up -d

# View development logs
docker compose -f docker-compose.dev.yml logs -f svix-server-dev
```

## 📋 Services Overview

### Core Services

| Service | Port | Description |
|---------|------|-------------|
| **svix-server** | 8071 | Main Svix webhook server |
| **postgres** | 5432 | PostgreSQL database |
| **redis** | 6379 | Redis for caching and queuing |
| **pgbouncer** | 6432 | Connection pooling for PostgreSQL |

### Optional Services (Profiles)

| Service | Port | Profile | Description |
|---------|------|---------|-------------|
| **svix-bridge** | 5000 | `bridge` | Bridge for external integrations |
| **redis-commander** | 8081 | `monitoring` | Redis web UI |
| **pgadmin** | 8080 | `monitoring` | PostgreSQL web UI |
| **webhook-tester** | 8082 | `testing` | Webhook testing service |

## 🛠 Usage Examples

### Starting Different Configurations

```bash
# Core services only
docker compose up -d

# With bridge
docker compose --profile bridge up -d

# With monitoring tools
docker compose --profile monitoring up -d

# Everything
docker compose --profile monitoring --profile bridge --profile testing up -d
```

### Using the Svix CLI

```bash
# Generate JWT token
docker compose exec svix-server svix-server jwt generate

# Generate JWT for specific org
docker compose exec svix-server svix-server jwt generate org_23rb8YdGqMT0qIzpgGwdXfHirMu

# Use Svix CLI
docker compose exec svix-server svix --help
docker compose exec svix-server svix login
```

### Database Operations

```bash
# Connect to PostgreSQL directly
docker compose exec postgres psql -U postgres -d svix

# Run migrations
docker compose exec svix-server svix-server --run-migrations

# Access database via pgAdmin (with monitoring profile)
# Navigate to http://localhost:8080
# Email: admin@svix.local, Password: admin
```

### Redis Operations

```bash
# Connect to Redis CLI
docker compose exec redis redis-cli

# Access Redis via web UI (with monitoring profile)
# Navigate to http://localhost:8081
# User: admin, Password: admin
```

## 🔧 Development Workflow

### Hot Reloading Development

The development setup includes automatic code reloading:

```bash
# Start development environment
docker compose -f docker-compose.dev.yml up -d

# Code changes in server/ will automatically restart the server
# Code changes in bridge/ will automatically restart the bridge
```

### Running Tests

```bash
# Run all tests
docker compose -f docker-compose.dev.yml --profile testing up test

# Run specific tests
docker compose -f docker-compose.dev.yml exec svix-server-dev cargo test

# Run tests with coverage
docker compose -f docker-compose.dev.yml exec svix-server-dev cargo test -- --nocapture
```

### Development Tools

Access the development tools container:

```bash
# Start tools container
docker compose -f docker-compose.dev.yml --profile tools up -d dev-tools

# Access the container
docker compose -f docker-compose.dev.yml exec dev-tools bash

# Inside the container, you have access to:
# - server     # Run Svix server
# - bridge     # Run Svix bridge  
# - cli        # Run Svix CLI
# - test-all   # Run all tests
# - fmt        # Format code
# - check      # Check code
# - clippy     # Run clippy linter
```

## ⚙️ Configuration

### Environment Variables

The Docker setup uses the following key environment variables:

#### Database Configuration
- `SVIX_DB_DSN`: PostgreSQL connection string
- `SVIX_DB_POOL_MAX_SIZE`: Database connection pool size (default: 100)

#### Redis Configuration  
- `SVIX_REDIS_DSN`: Redis connection string
- `SVIX_QUEUE_TYPE`: Queue backend type (redis/memory)
- `SVIX_REDIS_POOL_MAX_SIZE`: Redis connection pool size (default: 100)

#### Security Configuration
- `SVIX_JWT_SECRET`: JWT signing secret (⚠️ **CHANGE IN PRODUCTION!**)
- `SVIX_WHITELIST_SUBNETS`: Allowed IP subnets for webhooks

#### Logging Configuration
- `SVIX_LOG_LEVEL`: Log level (debug/info/warn/error)
- `SVIX_LOG_FORMAT`: Log format (json/pretty)

### Custom Configuration

To use custom configuration:

1. **Environment variables**: Create `.env` file in the root directory
2. **Configuration file**: Mount custom `config.toml` into the container
3. **Override compose**: Create `docker-compose.override.yml`

Example `.env` file:
```env
SVIX_JWT_SECRET=your-super-secret-key-here
SVIX_LOG_LEVEL=debug
SVIX_WHITELIST_SUBNETS=["10.0.0.0/8", "192.168.0.0/16"]
```

## 🔐 Security Considerations

### JWT Secret
**⚠️ IMPORTANT**: Change the default JWT secret before production use:

```bash
# Generate a secure JWT secret
openssl rand -base64 32

# Update in docker-compose.yml or .env file
SVIX_JWT_SECRET=your-generated-secret-here
```

### Network Security
- Services communicate over a private Docker network
- Only necessary ports are exposed to the host
- Database and Redis are not exposed by default (only via internal network)

### Production Recommendations
- Use Docker secrets for sensitive configuration
- Enable TLS/SSL for external connections
- Set up proper firewall rules
- Use a reverse proxy (nginx, traefik) for SSL termination
- Regular security updates of base images

## 📊 Monitoring and Debugging

### Health Checks

All services include health checks:

```bash
# Check service health
docker compose ps

# View health check logs
docker compose logs pgbouncer
```

### Monitoring Stack

With the monitoring profile enabled:

- **PostgreSQL Admin**: http://localhost:8080 (admin@svix.local / admin)
- **Redis Commander**: http://localhost:8081 (admin / admin)

### Performance Monitoring

```bash
# View resource usage
docker stats

# Monitor logs
docker compose logs -f --tail=100 svix-server

# Check database performance
docker compose exec postgres psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

## 🚨 Troubleshooting

### Common Issues

#### Services won't start
```bash
# Check service logs
docker compose logs svix-server

# Verify dependencies
docker compose ps
```

#### Database connection issues
```bash
# Check PostgreSQL status
docker compose exec postgres pg_isready -U postgres

# Verify database connection
docker compose exec svix-server svix-server healthcheck http://localhost:8071
```

#### Performance issues
```bash
# Check resource usage
docker stats

# Increase connection pools in docker-compose.yml:
SVIX_DB_POOL_MAX_SIZE=200
SVIX_REDIS_POOL_MAX_SIZE=200
```

#### Hot reloading not working (dev mode)
```bash
# Rebuild development image
docker compose -f docker-compose.dev.yml build svix-server-dev

# Check file permissions
ls -la # Ensure files are readable by container user
```

### Debug Mode

Enable debug logging:

```bash
# Add to docker-compose.yml environment:
SVIX_LOG_LEVEL=debug
RUST_BACKTRACE=full
RUST_LOG=debug

# Restart services
docker compose up -d
```

### Reset Everything

To completely reset the environment:

```bash
# Stop and remove everything
docker compose down -v --remove-orphans

# Remove images
docker compose down --rmi all

# Restart from scratch
docker compose up -d
```

## 🎯 Production Deployment

### Docker Swarm

```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.yml svix

# Scale services
docker service scale svix_svix-server=3
```

### Kubernetes

Convert to Kubernetes manifests using Kompose:

```bash
# Install kompose
curl -L https://github.com/kubernetes/kompose/releases/download/v1.26.0/kompose-linux-amd64 -o kompose

# Convert
./kompose convert -f docker-compose.yml
```

### Environment-Specific Configs

Create environment-specific compose files:

- `docker-compose.prod.yml` - Production overrides
- `docker-compose.staging.yml` - Staging overrides  
- `docker-compose.local.yml` - Local development overrides

## 📚 Additional Resources

- [Svix Documentation](https://docs.svix.com)
- [Svix API Reference](https://api.svix.com)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Svix Server Configuration](./server/README.md)

## 🤝 Contributing

When modifying the Docker setup:

1. Test both production and development configurations
2. Update this README with any new services or configuration options
3. Verify security implications of any changes
4. Test on different platforms (Linux, macOS, Windows)

---

**Need help?** Open an issue or join the [Svix Community Slack](https://www.svix.com/slack/)!