import { Router } from 'express';
import { asyncHandler } from '@/middleware/async-handler';
import { tusdHookLimiter } from '@/middleware/rate-limit';
import { handleTusdHook } from '@/controllers/tusd-hooks.controller';

export const internalHooksRouter = Router();

// Mounted under `/internal` (see app.ts) — kept off `/api` so it's obvious in
// logs and gateway rules that this is a service-to-service path, not a
// client-facing one. tusd POSTs here from inside the docker network. The
// rate limit bounds the blast radius of a leaked `TUSD_HOOK_SECRET`: an
// attacker who obtains the secret still can't flood the transcode queue.
internalHooksRouter.post('/hooks/tusd', tusdHookLimiter, asyncHandler(handleTusdHook));
