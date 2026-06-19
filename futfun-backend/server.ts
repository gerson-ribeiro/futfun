import 'dotenv/config';
import { createServer } from 'http';
import { parse } from 'url';
import next from 'next';
import { initializeContainer, getContainer } from './src/infrastructure/container/container';
import { applyStartupMigrations } from './src/infrastructure/db/startupMigrations';

// Prevent SIGPIPE from crashing the process (e.g. when a client disconnects mid-response)
process.on('SIGPIPE', () => {});

const dev = process.env.NODE_ENV !== 'production';
const hostname = 'localhost';
const port = parseInt(process.env.PORT || '4000', 10);

const app = next({ dev, hostname, port });
const handle = app.getRequestHandler();

app.prepare().then(async () => {
  // Initialize DI container
  initializeContainer();

  const { prisma, matchSyncJob } = getContainer();

  // Apply idempotent schema migrations at startup (avoids Cloud Run Job permission issues)
  await applyStartupMigrations(prisma);

  matchSyncJob.start();

  const server = createServer(async (req, res) => {
    try {
      const parsedUrl = parse(req.url!, true);
      await handle(req, res, parsedUrl);
    } catch (err) {
      console.error('Error handling request:', err);
      res.statusCode = 500;
      res.end('Internal server error');
    }
  });

  server.listen(port, (err?: Error) => {
    if (err) throw err;
    console.log(`> FutFun API listening at http://${hostname}:${port}`);
  });
});
