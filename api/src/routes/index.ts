import { Router } from 'express';
import { authRouter } from '@/routes/auth.routes';
import { adminRouter } from '@/routes/admin.routes';
import { coursesRouter } from '@/routes/courses.routes';
import { videosRouter } from '@/routes/videos.routes';
import { cuesRouter } from '@/routes/cues.routes';
import { attemptsRouter } from '@/routes/attempts.routes';
import { voiceAttemptsRouter } from '@/routes/stubs/voice-attempts.routes';
import { feedRouter } from '@/routes/feed.routes';
import { designerApplicationsRouter } from '@/routes/designer-applications.routes';
import { enrollmentsRouter } from '@/routes/enrollments.routes';
import { eventsRouter } from '@/routes/events.routes';

export const apiRouter = Router();

apiRouter.use('/auth', authRouter);
// Admin mount — must be before the individual feature routers for admin
// paths to win over any matching sub-path ambiguity. Routes under this
// mount share the ADMIN role gate.
apiRouter.use('/admin', adminRouter);
apiRouter.use('/courses', coursesRouter);
apiRouter.use('/videos', videosRouter);
apiRouter.use('/cues', cuesRouter);
apiRouter.use('/attempts', attemptsRouter);
apiRouter.use('/voice-attempts', voiceAttemptsRouter);
apiRouter.use('/feed', feedRouter);
apiRouter.use('/designer-applications', designerApplicationsRouter);
apiRouter.use('/enrollments', enrollmentsRouter);
apiRouter.use('/events', eventsRouter);
