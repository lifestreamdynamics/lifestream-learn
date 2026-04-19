import { Router } from 'express';
import { authRouter } from '@/routes/auth.routes';
import { coursesRouter } from '@/routes/stubs/courses.routes';
import { videosRouter } from '@/routes/videos.routes';
import { cuesRouter } from '@/routes/stubs/cues.routes';
import { attemptsRouter } from '@/routes/stubs/attempts.routes';
import { voiceAttemptsRouter } from '@/routes/stubs/voice-attempts.routes';
import { feedRouter } from '@/routes/stubs/feed.routes';
import { designerApplicationsRouter } from '@/routes/stubs/designer-applications.routes';
import { eventsRouter } from '@/routes/stubs/events.routes';

export const apiRouter = Router();

apiRouter.use('/auth', authRouter);
apiRouter.use('/courses', coursesRouter);
apiRouter.use('/videos', videosRouter);
apiRouter.use('/cues', cuesRouter);
apiRouter.use('/attempts', attemptsRouter);
apiRouter.use('/voice-attempts', voiceAttemptsRouter);
apiRouter.use('/feed', feedRouter);
apiRouter.use('/designer-applications', designerApplicationsRouter);
apiRouter.use('/events', eventsRouter);
