import { Router } from 'express';
import { NotImplementedError } from '@/utils/errors';

/**
 * Phase-2 scaffold: every unimplemented resource gets a router that answers
 * all paths/methods with 501 Not Implemented. Replaced by real routers in
 * Phase 3+ per IMPLEMENTATION_PLAN.md §5.
 */
export function makeStubRouter(resource: string): Router {
  const router = Router();
  router.all('*', (_req, _res, next) => {
    next(new NotImplementedError(`${resource} endpoints are not implemented yet`));
  });
  return router;
}
