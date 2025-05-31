#!/bin/bash

# Deployment script for production Docker Compose stack

echo "🚀 Deploying Production Stack..."

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose is not installed"
    exit 1
fi

# Check if all required files exist
required_files=("docker-compose.yml" "secrets/mongodb_root_password.txt" "secrets/redis_password.txt")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Required file missing: $file"
        echo "Please run ./setup.sh first"
        exit 1
    fi
done

# Pull latest images
echo "📥 Pulling latest Docker images..."
docker-compose pull

# Start services
echo "🔄 Starting services..."
docker-compose up -d --remove-orphans

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 30

# Check service status
echo "📊 Service Status:"
docker-compose ps

echo ""
echo "✅ Deployment completed!"
echo ""
echo "🌐 Access URLs:"
echo "   Application:     http://localhost:3000"
echo "   Mongo Express:   http://localhost:8081"
echo "   Redis Insight:   http://localhost:8080"
echo ""
echo "📋 Management Commands:"
echo "   View logs:       docker-compose logs -f [service]"
echo "   Stop services:   docker-compose down"
echo "   Restart:         docker-compose restart [service]"
echo "   Scale service:   docker-compose up -d --scale express-app=3"

