import { Router } from 'express';
import { asyncHandler } from '@/middleware/async-handler';
import { handleTusdHook } from '@/controllers/tusd-hooks.controller';

export const internalHooksRouter = Router();

// Mounted under `/internal` (see app.ts) — kept off `/api` so it's obvious in
// logs and gateway rules that this is a service-to-service path, not a
// client-facing one. tusd POSTs here from inside the docker network.
internalHooksRouter.post('/hooks/tusd', asyncHandler(handleTusdHook));
