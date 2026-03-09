#!/bin/bash

echo "🧹 Stopping and removing all containers..."
docker-compose down -v --remove-orphans

echo "🗑️ Removing all images..."
docker-compose down --rmi all

echo "🧽 Pruning Docker system (removing cache)..."
docker system prune -af --volumes

echo "🔨 Building images without cache..."
docker-compose build --no-cache --pull

echo "🚀 Starting services..."
docker-compose up -d

echo "⏳ Waiting for services to be ready..."
sleep 30

echo "✅ Services should be running with fresh code!"
docker-compose ps
