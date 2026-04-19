import type { Express } from 'express';

let cachedApp: Express | undefined;

/**
 * Returns a cached Express app built by `createApp()` — re-use across tests
 * so helmet/cors/rate-limit middleware are initialised once per worker.
 */
export async function getTestApp(): Promise<Express> {
  if (!cachedApp) {
    const mod = await import('@/app');
    cachedApp = mod.createApp();
  }
  return cachedApp;
}
