import rateLimit from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import { env } from '@/config/env';
import { redis } from '@/config/redis';

const makeStore = (prefix: string) =>
  new RedisStore({
    prefix,
    // rate-limit-redis v4 expects a variadic (...args: string[]) => Promise<...>
    // that forwards to an ioredis-compatible client. ioredis `call` accepts
    // (command: string, ...args: string[]); we cast to satisfy its overload
    // signature while preserving the rate-limit-redis contract.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    sendCommand: (...args: string[]) => redis.call(...(args as [string, ...string[]])) as Promise<any>,
  });

export const signupLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_SIGNUP_WINDOW_MS,
  limit: env.RATE_LIMIT_SIGNUP_MAX,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:auth:signup:'),
  message: { error: 'RATE_LIMITED', message: 'Too many signup attempts' },
});

export const loginLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_LOGIN_WINDOW_MS,
  limit: env.RATE_LIMIT_LOGIN_MAX,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:auth:login:'),
  message: { error: 'RATE_LIMITED', message: 'Too many login attempts' },
});

export const refreshLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_REFRESH_WINDOW_MS,
  limit: env.RATE_LIMIT_REFRESH_MAX,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  store: makeStore('rl:auth:refresh:'),
  message: { error: 'RATE_LIMITED', message: 'Too many refresh attempts' },
});
