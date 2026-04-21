import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { createUser } from '@tests/integration/helpers/factories';
import { prisma } from '@/config/prisma';

// tusd/BullMQ live in learn:transcode; the achievements path does NOT
// enqueue anything, but mocking here keeps the test-app wiring aligned
// with the rest of the integration suite.
jest.mock('@/queues/transcode.queue', () => ({
  enqueueTranscode: jest.fn().mockResolvedValue(undefined),
  getTranscodeQueue: jest.fn().mockReturnValue({
    client: Promise.resolve({ ping: () => Promise.resolve('PONG') }),
  }),
  TRANSCODE_QUEUE_NAME: 'transcode',
  closeTranscodeQueue: jest.fn().mockResolvedValue(undefined),
}));

describe('Achievements API (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*', 'progress:*']);

    // Seed a small catalog. Integration tests ship their own seed so
    // the behaviour doesn't depend on whether `prisma:seed` was run on
    // the dev DB.
    await prisma.achievement.upsert({
      where: { id: 'first_lesson' },
      update: {},
      create: {
        id: 'first_lesson',
        title: 'First Lesson',
        description: 'Complete your first lesson',
        iconKey: 'school',
        criteriaJson: { type: 'lessons_completed', count: 1 },
      },
    });
    await prisma.achievement.upsert({
      where: { id: 'streak_7' },
      update: {},
      create: {
        id: 'streak_7',
        title: 'Week-Long Streak',
        description: 'Learn 7 days in a row',
        iconKey: 'whatshot',
        criteriaJson: { type: 'streak', days: 7 },
      },
    });
  });

  afterAll(async () => {
    // Tear down the seeded achievements so we leave the DB as we found it.
    await prisma.achievement.deleteMany({
      where: { id: { in: ['first_lesson', 'streak_7'] } },
    });
    await closeConnections();
  });

  describe('GET /api/me/achievements', () => {
    it('requires auth (401 without bearer)', async () => {
      const app = await getTestApp();
      const res = await request(app).get('/api/me/achievements');
      expect(res.status).toBe(401);
    });

    it('happy path: fresh learner → all locked, no unlockedAt entries', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .get('/api/me/achievements')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.unlocked).toEqual([]);
      expect(res.body.locked.map((a: { id: string }) => a.id).sort()).toEqual(
        ['first_lesson', 'streak_7'],
      );
      expect(res.body.unlockedAtByAchievementId).toEqual({});
    });

    it('after seeding a UserAchievement row, it appears in unlocked', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      await prisma.userAchievement.create({
        data: {
          userId: learner.id,
          achievementId: 'first_lesson',
          unlockedAt: new Date('2026-04-15T10:00:00Z'),
        },
      });

      const res = await request(app)
        .get('/api/me/achievements')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.unlocked.map((a: { id: string }) => a.id)).toEqual([
        'first_lesson',
      ]);
      expect(res.body.locked.map((a: { id: string }) => a.id)).toEqual([
        'streak_7',
      ]);
      expect(res.body.unlockedAtByAchievementId.first_lesson).toBe(
        '2026-04-15T10:00:00.000Z',
      );
      // Locked entries have no unlockedAt.
      expect(res.body.unlockedAtByAchievementId.streak_7).toBeUndefined();
    });

    it('isolated per user: one learner\'s unlock never leaks to another', async () => {
      const app = await getTestApp();
      const a = await createUser({ role: 'LEARNER' });
      const b = await createUser({ role: 'LEARNER' });
      await prisma.userAchievement.create({
        data: { userId: a.id, achievementId: 'first_lesson' },
      });

      const resA = await request(app)
        .get('/api/me/achievements')
        .set('authorization', `Bearer ${a.accessToken}`);
      const resB = await request(app)
        .get('/api/me/achievements')
        .set('authorization', `Bearer ${b.accessToken}`);
      expect(resA.body.unlocked.map((x: { id: string }) => x.id)).toEqual([
        'first_lesson',
      ]);
      expect(resB.body.unlocked).toEqual([]);
    });
  });
});
