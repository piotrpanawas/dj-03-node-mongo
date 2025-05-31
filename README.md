# Production-Ready Node.js Docker Compose Stack

A comprehensive, production-ready Docker Compose configuration for a Node.js application stack with MongoDB, Redis, and admin interfaces.

## 🏗️ Architecture Overview

This stack provides a complete microservices architecture with:

- **Express App**: Node.js application server (Port 3000)
- **MongoDB**: Primary database with authentication (Port 27018)
- **Mongo Express**: Web-based MongoDB admin interface (Port 8081)
- **Redis**: Caching layer with persistence (Port 6380)
- **Redis Insight**: Web-based Redis management interface (Port 8080)

## 🔒 Security Features

### Network Segmentation
- **Frontend Network**: Client-facing services (Express App)
- **Backend Network**: Database and cache services
- **Admin Network**: Management interfaces (isolated from production traffic)

### Security Best Practices
- ✅ Docker secrets for credential management
- ✅ Non-root user execution where possible
- ✅ Non-standard port mappings for security
- ✅ Network isolation with custom bridges
- ✅ Resource limits and constraints
- ✅ Comprehensive health checks
- ✅ Security-hardened container configurations
- ✅ No hardcoded secrets in configuration files

## 🚀 Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+
- Linux/macOS/Windows with WSL2

### Installation

1. **Clone or create the project directory**
   ```bash
   mkdir nodejs-docker-stack
   cd nodejs-docker-stack
   ```

2. **Run the setup script**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Deploy the stack**
   ```bash
   ./deploy.sh
   ```

4. **Verify deployment**
   ```bash
   docker-compose ps
   ```

## 📁 Project Structure

```
nodejs-docker-stack/
├── docker-compose.yml          # Main compose configuration
├── setup.sh                    # Environment setup script
├── deploy.sh                   # Deployment script
├── mongodb-init-script.js      # MongoDB initialization
├── secrets/                    # Docker secrets (auto-generated)
│   ├── mongodb_root_password.txt
│   ├── mongodb_app_password.txt
│   ├── redis_password.txt
│   └── mongo_express_password.txt
├── mongodb/
│   ├── init/                   # Database initialization scripts
│   └── config/                 # MongoDB configuration
├── redis/
│   └── config/                 # Redis configuration
├── redis-insight/
│   └── data/                   # RedisInsight persistent data
├── src/                        # Application source code
│   ├── app.js                  # Sample Node.js application
│   └── package.json            # Node.js dependencies
└── logs/                       # Application logs
```

## 🔧 Configuration

### Environment Variables

The stack uses environment variables for configuration. Key variables include:

```bash
NODE_ENV=production
PORT=3000
MONGODB_URI=mongodb://app_user:${MONGODB_APP_PASSWORD}@mongodb:27017/products
REDIS_URL=redis://redis:6379
LOG_LEVEL=info
```

### MongoDB Configuration

- **Database**: `products`
- **Application User**: `app_user`
- **Collections**: products, categories, users, orders
- **Indexes**: Optimized for common queries
- **Authentication**: Required for all connections

### Redis Configuration

- **Persistence**: AOF + RDB snapshots
- **Memory Policy**: allkeys-lru
- **Max Memory**: 512MB
- **Authentication**: Password-protected

## 🌐 Access URLs

After deployment, access the services at:

| Service | URL | Credentials |
|---------|-----|-------------|
| Application | http://localhost:3000 | None |
| Mongo Express | http://localhost:8081 | admin / (generated password) |
| Redis Insight | http://localhost:8080 | None (auto-connect) |

## 📊 Health Monitoring

### Health Check Endpoints

All services include comprehensive health checks:

- **Express App**: `GET /health`
- **MongoDB**: `mongosh ping` command
- **Redis**: `redis-cli ping` command
- **Admin Interfaces**: HTTP connectivity checks

### Monitoring Commands

```bash
# Check service status
docker-compose ps

# View service logs
docker-compose logs -f [service-name]

# Check individual container health
docker inspect <container-name> --format='{{.State.Health.Status}}'

# Monitor resource usage
docker stats
```

## 🛠️ Management Commands

### Basic Operations

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Restart a specific service
docker-compose restart express-app

# Scale the application
docker-compose up -d --scale express-app=3

# View logs for all services
docker-compose logs -f

# Update and restart services
docker-compose pull && docker-compose up -d
```

### Database Operations

```bash
# Connect to MongoDB
docker-compose exec mongodb mongosh -u admin -p

# Backup MongoDB
docker-compose exec mongodb mongodump --out /data/backup

# Connect to Redis
docker-compose exec redis redis-cli -a "$(cat secrets/redis_password.txt)"

# Redis backup
docker-compose exec redis redis-cli -a "$(cat secrets/redis_password.txt)" BGSAVE
```

## 🔄 Development Workflow

### Local Development

1. **Modify source code** in the `src/` directory
2. **Restart the application** container:
   ```bash
   docker-compose restart express-app
   ```

### Production Deployment

1. **Update configurations** as needed
2. **Test in staging** environment first
3. **Deploy with zero downtime**:
   ```bash
   docker-compose pull
   docker-compose up -d --no-deps express-app
   ```

## 📈 Scaling Considerations

### Horizontal Scaling

Scale application instances:
```bash
docker-compose up -d --scale express-app=5
```

### Resource Optimization

The stack includes predefined resource limits:

- **Express App**: 1 CPU, 512MB RAM
- **MongoDB**: 2 CPU, 2GB RAM
- **Redis**: 1 CPU, 512MB RAM
- **Admin Interfaces**: 0.5 CPU, 256MB RAM

## 🔒 Security Hardening

### Production Security Checklist

- [ ] Rotate all generated passwords
- [ ] Configure firewall rules
- [ ] Set up SSL/TLS certificates
- [ ] Enable Docker security scanning
- [ ] Configure log aggregation
- [ ] Set up monitoring and alerting
- [ ] Review and audit access logs
- [ ] Implement backup and disaster recovery

### Security Updates

```bash
# Update base images
docker-compose pull

# Restart with new images
docker-compose up -d

# Check for vulnerabilities
docker scout quickview
```

## 🐛 Troubleshooting

### Common Issues

**Services not starting**
```bash
# Check logs
docker-compose logs [service-name]

# Check disk space
df -h

# Check Docker daemon
systemctl status docker
```

**Database connection issues**
```bash
# Verify MongoDB is healthy
docker-compose exec mongodb mongosh --eval "db.adminCommand('ping')"

# Check network connectivity
docker-compose exec express-app ping mongodb
```

**Performance issues**
```bash
# Monitor resource usage
docker stats

# Check service health
docker-compose ps
```

### Log Analysis

```bash
# Application logs
docker-compose logs -f express-app

# Database logs
docker-compose logs -f mongodb

# Cache logs
docker-compose logs -f redis
```

## 📋 Maintenance

### Regular Maintenance Tasks

1. **Weekly**: Review logs and performance metrics
2. **Monthly**: Update Docker images and rotate passwords
3. **Quarterly**: Review and update security configurations
4. **As needed**: Scale resources based on usage patterns

### Backup Strategy

```bash
# Automated backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)

# MongoDB backup
docker-compose exec -T mongodb mongodump --archive | gzip > "backup_mongodb_${DATE}.gz"

# Redis backup
docker-compose exec -T redis redis-cli --rdb - | gzip > "backup_redis_${DATE}.gz"

# Application data backup
tar -czf "backup_app_${DATE}.tar.gz" src/ logs/
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
- Check the troubleshooting section
- Review Docker Compose logs
- Open an issue with detailed information

---

**Note**: This configuration is designed for production use but should be customized based on your specific requirements and security policies.