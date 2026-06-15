# Redis 7 Setup for FutFun MVP Backend

## Installation Summary

**Redis Version:** 7.2.9  
**Installation Method:** WSL2 (Windows Subsystem for Linux) with docker-desktop distribution  
**Status:** Installed and running

## How It Works

Since Docker Desktop daemon was not running and direct Windows installation had network restrictions, Redis was installed in the WSL2 `docker-desktop` distribution:

1. **Installation**: `wsl -d docker-desktop apk add redis`
   - Installed Redis 7.2.9 using Alpine Linux package manager (apk)
   - WSL2 provides a lightweight Linux environment without needing full virtualization

2. **Wrapper Scripts**: Created bash wrapper scripts in `C:/Users/gugag/bin/`:
   - `redis-cli` - Forwards redis-cli commands to the WSL instance
   - `redis-server` - Forwards redis-server commands to the WSL instance

3. **Access**: Redis is accessible from Windows via WSL redirection
   - Listens on `localhost:6379`
   - Can be called directly: `redis-cli ping`

## Starting Redis

### Option 1: Automatic startup script
```bash
./start-redis.sh
```

### Option 2: Manual startup
```bash
redis-server --bind 0.0.0.0 --port 6379
```

### Option 3: Daemonized (background) startup
```bash
wsl -d docker-desktop redis-server --bind 0.0.0.0 --port 6379 --daemonize yes
```

## Verification

Check if Redis is running:
```bash
redis-cli ping
# Expected output: PONG
```

Get server info:
```bash
redis-cli INFO server
```

## Features Verified

- [x] Redis 7+ installed (7.2.9)
- [x] redis-cli available and responding to commands
- [x] redis-server binary available
- [x] PING command working correctly
- [x] Can be used for caching, tokens, pub/sub, and rate limiting

## Use Cases Supported

The installed Redis instance supports all FutFun backend requirements:
- **Cache**: Leaderboard and user statistics caching
- **Token Storage**: tempTokens and refreshTokens
- **Pub/Sub**: Event distribution across services
- **Rate Limiting**: Request rate limiting store

## Network Details

- **Host**: localhost (127.0.0.1)
- **Port**: 6379 (default Redis port)
- **Binding**: 0.0.0.0 (all interfaces)
- **Backend**: WSL2 docker-desktop Linux distribution

## Troubleshooting

If Redis becomes unresponsive:
1. Check if WSL is running: `wsl -d docker-desktop uname -a`
2. Check Redis status: `redis-cli ping`
3. Restart Redis: Kill existing process and run `redis-server` again

## Configuration File

Optional: Create a `redis.conf` in the project for custom configuration and start with:
```bash
redis-server redis.conf
```
