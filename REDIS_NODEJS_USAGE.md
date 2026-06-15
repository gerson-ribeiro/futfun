# Using Redis with FutFun Node.js Backend

## Installation

Install the Redis client for Node.js:
```bash
npm install redis
```

For TypeScript support:
```bash
npm install redis @types/redis
```

## Basic Connection

```javascript
import { createClient } from 'redis';

// Create a Redis client
const client = createClient({
  host: 'localhost',
  port: 6379
});

// Connect
await client.connect();

// Verify connection
const pong = await client.ping();
console.log(pong); // 'PONG'

// Close connection when done
await client.quit();
```

## Common Operations

### Caching (Leaderboard Example)
```javascript
// Set cache with expiration (1 hour = 3600 seconds)
await client.setEx('cache:leaderboard:top10', 3600, JSON.stringify(leaderboardData));

// Get from cache
const cached = await client.get('cache:leaderboard:top10');
const leaderboardData = JSON.parse(cached);

// Check if exists
const exists = await client.exists('cache:leaderboard:top10');
```

### Token Storage
```javascript
// Store temporary access token (10 minute expiration = 600 seconds)
await client.setEx(`token:temp:${userId}`, 600, accessToken);

// Store refresh token (7 day expiration = 604800 seconds)
await client.setEx(`token:refresh:${userId}`, 604800, refreshToken);

// Retrieve token
const token = await client.get(`token:temp:${userId}`);

// Revoke token
await client.del(`token:temp:${userId}`);
```

### Pub/Sub for Event Distribution
```javascript
// Publisher
await client.publish('events:user-update', JSON.stringify({
  userId: 123,
  newRating: 2150
}));

// Subscriber
const subscriber = client.duplicate();
await subscriber.subscribe('events:user-update', (message) => {
  const event = JSON.parse(message);
  console.log('Received event:', event);
});
```

### Rate Limiting
```javascript
// Increment request counter for rate limiting
const key = `ratelimit:${userId}:${Math.floor(Date.now() / 60000)}`; // per minute
const requests = await client.incr(key);

// Set expiration on first creation
if (requests === 1) {
  await client.expire(key, 60); // 1 minute window
}

// Check if exceeded limit (e.g., 100 requests per minute)
if (requests > 100) {
  throw new Error('Rate limit exceeded');
}
```

## Error Handling

```javascript
client.on('error', (err) => {
  console.error('Redis client error:', err);
});

client.on('connect', () => {
  console.log('Redis client connected');
});

client.on('disconnect', () => {
  console.log('Redis client disconnected');
});
```

## Connection Pooling

For production, consider using a connection pool:
```javascript
import { createPool } from 'redis';

const pool = createPool({
  host: 'localhost',
  port: 6379,
  max: 10 // maximum number of connections
});

// Use pool for connections
const client = await pool.acquire();
try {
  await client.ping();
} finally {
  await pool.release(client);
}
```

## Environment Configuration

Add to `.env`:
```
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD= # leave empty if no password
REDIS_DB=0 # optional: select specific database
```

## Testing Redis Connection

Create a simple test file:
```javascript
import { createClient } from 'redis';

const client = createClient({
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379
});

client.on('error', (err) => console.error('Redis error:', err));
client.on('connect', () => console.log('Redis connected'));

await client.connect();
const result = await client.ping();
console.log('Redis ping:', result);
await client.quit();
```

Run with:
```bash
node test-redis.js
```

Expected output:
```
Redis connected
Redis ping: PONG
```

## References

- [redis npm package](https://www.npmjs.com/package/redis)
- [Redis commands reference](https://redis.io/commands)
- [Redis best practices](https://redis.io/topics/client-side-caching)
