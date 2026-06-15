#!/bin/bash
# Start Redis 7 server via WSL2 docker-desktop distribution
# This script starts a persistent Redis instance on localhost:6379

echo "Starting Redis 7.2.9 server..."
wsl -d docker-desktop redis-server --bind 0.0.0.0 --port 6379 --daemonize yes

# Give it a moment to start
sleep 1

# Verify it's running
if redis-cli ping > /dev/null 2>&1; then
    echo "✓ Redis server started successfully on localhost:6379"
    redis-cli INFO server | grep redis_version
else
    echo "✗ Failed to start Redis server"
    exit 1
fi
