#!/bin/bash

# Production Docker Compose Setup Script
# This script creates the necessary directory structure and secret files
# for the Node.js application stack

set -e

echo "🚀 Setting up Production Docker Compose Environment"
echo "=================================================="

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to generate secure random passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to create directory if it doesn't exist
create_directory() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        echo -e "${GREEN}✓${NC} Created directory: $1"
    else
        echo -e "${YELLOW}⚠${NC} Directory already exists: $1"
    fi
}

# Function to create file with content if it doesn't exist
create_file() {
    local file_path="$1"
    local content="$2"
    
    if [ ! -f "$file_path" ]; then
        echo "$content" > "$file_path"
        echo -e "${GREEN}✓${NC} Created file: $file_path"
    else
        echo -e "${YELLOW}⚠${NC} File already exists: $file_path"
    fi
}

echo "📁 Creating directory structure..."

# Create main directories
create_directory "secrets"
create_directory "mongodb/init"
create_directory "mongodb/config"
create_directory "redis/config"
create_directory "redis-insight/data"
create_directory "src"
create_directory "logs"

echo ""
echo "🔐 Generating secure passwords and creating secret files..."

# Generate passwords
MONGODB_ROOT_PASSWORD=$(generate_password)
MONGODB_APP_PASSWORD=$(generate_password)
REDIS_PASSWORD=$(generate_password)
MONGO_EXPRESS_PASSWORD=$(generate_password)

# Create secret files
create_file "secrets/mongodb_root_password.txt" "$MONGODB_ROOT_PASSWORD"
create_file "secrets/mongodb_app_password.txt" "$MONGODB_APP_PASSWORD"
create_file "secrets/redis_password.txt" "$REDIS_PASSWORD"
create_file "secrets/mongo_express_password.txt" "$MONGO_EXPRESS_PASSWORD"

# Set appropriate permissions for secret files
chmod 600 secrets/*.txt
echo -e "${GREEN}✓${NC} Set secure permissions (600) for secret files"

echo ""
echo "📄 Creating configuration files..."

# Create MongoDB configuration file
create_file "mongodb/config/mongod.conf" "# MongoDB Configuration File
# For production deployment

storage:
  dbPath: /data/db
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen

net:
  port: 27017
  bindIp: 0.0.0.0

security:
  authorization: enabled

operationProfiling:
  slowOpThresholdMs: 100

setParameter:
  enableLocalhostAuthBypass: false"

# Create Redis configuration file
create_file "redis/config/redis.conf" "# Redis Configuration File
# For production deployment

# Network
bind 0.0.0.0
port 6379
tcp-keepalive 60
timeout 300

# Memory Management
maxmemory 512mb
maxmemory-policy allkeys-lru

# Persistence
save 900 1
save 300 10
save 60 10000
appendonly yes
appendfsync everysec
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# Security
protected-mode yes
# requirepass will be set via command line

# Logging
loglevel notice
syslog-enabled yes
syslog-ident redis

# Client Management
tcp-backlog 511
maxclients 10000"

# Create environment file template
create_file ".env.example" "# Environment Variables Template
# Copy this file to .env and update values as needed

# Application Settings
NODE_ENV=production
PORT=3000
LOG_LEVEL=info

# Database Settings
MONGODB_ROOT_PASSWORD=your_mongodb_root_password
MONGODB_APP_PASSWORD=your_mongodb_app_password

# Cache Settings
REDIS_PASSWORD=your_redis_password

# Admin Interface Settings
MONGO_EXPRESS_PASSWORD=your_mongo_express_password

# Optional: Custom port mappings
MONGODB_PORT=27018
REDIS_PORT=6380
MONGO_EXPRESS_PORT=8081
REDIS_INSIGHT_PORT=8080"

# Create a sample Node.js app file
create_file "src/package.json" "{
  \"name\": \"nodejs-docker-app\",
  \"version\": \"1.0.0\",
  \"description\": \"Production Node.js application with Docker\",
  \"main\": \"app.js\",
  \"scripts\": {
    \"start\": \"node app.js\",
    \"dev\": \"nodemon app.js\",
    \"test\": \"jest\"
  },
  \"dependencies\": {
    \"express\": \"^4.18.2\",
    \"mongoose\": \"^7.6.0\",
    \"redis\": \"^4.6.0\",
    \"helmet\": \"^7.1.0\",
    \"cors\": \"^2.8.5\",
    \"dotenv\": \"^16.3.1\",
    \"compression\": \"^1.7.4\",
    \"morgan\": \"^1.10.0\"
  },
  \"devDependencies\": {
    \"nodemon\": \"^3.0.1\",
    \"jest\": \"^29.7.0\"
  },
  \"keywords\": [\"nodejs\", \"docker\", \"mongodb\", \"redis\", \"express\"],
  \"author\": \"Your Name\",
  \"license\": \"MIT\"
}"

create_file "src/app.js" "const express = require('express');
const mongoose = require('mongoose');
const redis = require('redis');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// MongoDB connection
const connectMongoDB = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/products');
    console.log('✅ Connected to MongoDB');
  } catch (error) {
    console.error('❌ MongoDB connection error:', error);
    process.exit(1);
  }
};

// Redis connection
const connectRedis = async () => {
  try {
    const redisClient = redis.createClient({
      url: process.env.REDIS_URL || 'redis://localhost:6379',
      password: process.env.REDIS_PASSWORD
    });
    
    await redisClient.connect();
    console.log('✅ Connected to Redis');
    return redisClient;
  } catch (error) {
    console.error('❌ Redis connection error:', error);
    process.exit(1);
  }
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// API routes
app.get('/api/products', async (req, res) => {
  try {
    // Sample response - implement your business logic here
    res.json({
      success: true,
      data: [],
      message: 'Products retrieved successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    error: 'Something went wrong!'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found'
  });
});

// Start server
const startServer = async () => {
  await connectMongoDB();
  await connectRedis();
  
  app.listen(PORT, '0.0.0.0', () => {
    console.log(\`🚀 Server running on port \${PORT}\`);
    console.log(\`📊 Environment: \${process.env.NODE_ENV || 'development'}\`);
  });
};

startServer().catch(console.error);"

# Create deployment script
create_file "deploy.sh" "#!/bin/bash

# Deployment script for production Docker Compose stack

echo \"🚀 Deploying Production Stack...\"

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo \"❌ docker-compose is not installed\"
    exit 1
fi

# Check if all required files exist
required_files=(\"docker-compose.yml\" \"secrets/mongodb_root_password.txt\" \"secrets/redis_password.txt\")
for file in \"\${required_files[@]}\"; do
    if [ ! -f \"\$file\" ]; then
        echo \"❌ Required file missing: \$file\"
        echo \"Please run ./setup.sh first\"
        exit 1
    fi
done

# Pull latest images
echo \"📥 Pulling latest Docker images...\"
docker-compose pull

# Start services
echo \"🔄 Starting services...\"
docker-compose up -d --remove-orphans

# Wait for services to be healthy
echo \"⏳ Waiting for services to be healthy...\"
sleep 30

# Check service status
echo \"📊 Service Status:\"
docker-compose ps

echo \"\"
echo \"✅ Deployment completed!\"
echo \"\"
echo \"🌐 Access URLs:\"
echo \"   Application:     http://localhost:3000\"
echo \"   Mongo Express:   http://localhost:8081\"
echo \"   Redis Insight:   http://localhost:8080\"
echo \"\"
echo \"📋 Management Commands:\"
echo \"   View logs:       docker-compose logs -f [service]\"
echo \"   Stop services:   docker-compose down\"
echo \"   Restart:         docker-compose restart [service]\"
echo \"   Scale service:   docker-compose up -d --scale express-app=3\"
"

# Make scripts executable
chmod +x deploy.sh

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo -e "${GREEN}Generated Passwords:${NC}"
echo "  MongoDB Root:    $MONGODB_ROOT_PASSWORD"
echo "  MongoDB App:     $MONGODB_APP_PASSWORD"
echo "  Redis:           $REDIS_PASSWORD"
echo "  Mongo Express:   $MONGO_EXPRESS_PASSWORD"
echo ""
echo -e "${YELLOW}⚠️  Important Security Notes:${NC}"
echo "  • Store these passwords securely"
echo "  • The secret files have been created with 600 permissions"
echo "  • Consider using external secret management for production"
echo "  • Review and customize configuration files as needed"
echo ""
echo "📖 Next Steps:"
echo "  1. Review the generated configuration files"
echo "  2. Customize src/app.js for your application"
echo "  3. Run './deploy.sh' to start the stack"
echo "  4. Access services using the URLs shown after deployment"
echo ""
echo -e "${GREEN}🚀 Ready for deployment!${NC}"