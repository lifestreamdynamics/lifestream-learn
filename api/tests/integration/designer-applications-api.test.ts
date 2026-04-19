import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRedisKeys } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';
import { prisma } from '@/config/prisma';
import {
  createDesignerApplication,
  createUser,
} from '@tests/integration/helpers/factories';

jest.mock('@/queues/transcode.queue', () => ({
  enqueueTranscode: jest.fn().mockResolvedValue(undefined),
  getTranscodeQueue: jest.fn().mockReturnValue({
    client: Promise.resolve({ ping: () => Promise.resolve('PONG') }),
  }),
  TRANSCODE_QUEUE_NAME: 'transcode',
  closeTranscodeQueue: jest.fn().mockResolvedValue(undefined),
}));

describe('Designer Applications API (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRedisKeys(['rl:*', 'bull:*']);
  });

  afterAll(async () => {
    await closeConnections();
  });

  describe('POST /api/designer-applications', () => {
    it('learner applies (201) and cannot re-apply while PENDING (409)', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const r1 = await request(app)
        .post('/api/designer-applications')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ note: 'pls' });
      expect(r1.status).toBe(201);
      expect(r1.body.status).toBe('PENDING');

      const r2 = await request(app)
        .post('/api/designer-applications')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ note: 'again' });
      expect(r2.status).toBe(409);
    });

    it('403 for existing designers', async () => {
      const app = await getTestApp();
      const designer = await createUser({ role: 'COURSE_DESIGNER' });
      const res = await request(app)
        .post('/api/designer-applications')
        .set('authorization', `Bearer ${designer.accessToken}`)
        .send({});
      expect(res.status).toBe(403);
    });

    it('resurrects REJECTED application to PENDING', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      await createDesignerApplication(learner.id, {
        status: 'REJECTED',
        reviewedBy: learner.id, // any uuid
        reviewerNote: 'nope',
      });
      const res = await request(app)
        .post('/api/designer-applications')
        .set('authorization', `Bearer ${learner.accessToken}`)
        .send({ note: 'second try' });
      expect(res.status).toBe(201);
      expect(res.body.status).toBe('PENDING');
      expect(res.body.reviewedBy).toBeNull();
      expect(res.body.reviewerNote).toBeNull();
    });
  });

  describe('GET /api/designer-applications/me', () => {
    it('404 when the authed user has no application', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      const res = await request(app)
        .get('/api/designer-applications/me')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(404);
    });

    it('returns the caller own application when one exists', async () => {
      const app = await getTestApp();
      const learner = await createUser({ role: 'LEARNER' });
      await createDesignerApplication(learner.id, {
        status: 'PENDING',
      });
      const res = await request(app)
        .get('/api/designer-applications/me')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('PENDING');
      expect(res.body.userId).toBe(learner.id);
    });

    it('never returns another users application', async () => {
      const app = await getTestApp();
      const owner = await createUser({ role: 'LEARNER' });
      const other = await createUser({ role: 'LEARNER' });
      await createDesignerApplication(owner.id, { status: 'PENDING' });
      const res = await request(app)
        .get('/api/designer-applications/me')
        .set('authorization', `Bearer ${other.accessToken}`);
      expect(res.status).toBe(404);
    });

    it('401 without a bearer token', async () => {
      const app = await getTestApp();
      const res = await request(app).get('/api/designer-applications/me');
      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/admin/designer-applications', () => {
    it('admin lists; non-admin is forbidden', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const learner = await createUser({ role: 'LEARNER' });
      await createDesignerApplication(learner.id, { status: 'PENDING' });

      const res = await request(app)
        .get('/api/admin/designer-applications')
        .set('authorization', `Bearer ${admin.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.items).toHaveLength(1);

      const denied = await request(app)
        .get('/api/admin/designer-applications')
        .set('authorization', `Bearer ${learner.accessToken}`);
      expect(denied.status).toBe(403);
    });

    it('filters by status', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const l1 = await createUser({ role: 'LEARNER' });
      const l2 = await createUser({ role: 'LEARNER' });
      await createDesignerApplication(l1.id, { status: 'PENDING' });
      await createDesignerApplication(l2.id, { status: 'REJECTED' });

      const res = await request(app)
        .get('/api/admin/designer-applications?status=REJECTED')
        .set('authorization', `Bearer ${admin.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.items).toHaveLength(1);
      expect(res.body.items[0].status).toBe('REJECTED');
    });
  });

  describe('PATCH /api/admin/designer-applications/:id', () => {
    it('APPROVED: user role flips to COURSE_DESIGNER atomically', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const learner = await createUser({ role: 'LEARNER' });
      const appRow = await createDesignerApplication(learner.id, {
        status: 'PENDING',
      });

      const res = await request(app)
        .patch(`/api/admin/designer-applications/${appRow.id}`)
        .set('authorization', `Bearer ${admin.accessToken}`)
        .send({ status: 'APPROVED', reviewerNote: 'ok' });
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('APPROVED');
      expect(res.body.reviewedBy).toBe(admin.id);
      expect(res.body.reviewerNote).toBe('ok');

      const after = await prisma.user.findUnique({ where: { id: learner.id } });
      expect(after?.role).toBe('COURSE_DESIGNER');
    });

    it('APPROVED: does not downgrade an ADMIN', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      // Target starts as ADMIN (via direct creation — the service still flips
      // only LEARNERs). This is a belt-and-braces test of the updateMany
      // WHERE clause.
      const target = await createUser({ role: 'ADMIN' });
      const appRow = await createDesignerApplication(target.id, {
        status: 'PENDING',
      });
      const res = await request(app)
        .patch(`/api/admin/designer-applications/${appRow.id}`)
        .set('authorization', `Bearer ${admin.accessToken}`)
        .send({ status: 'APPROVED' });
      expect(res.status).toBe(200);
      const after = await prisma.user.findUnique({ where: { id: target.id } });
      expect(after?.role).toBe('ADMIN');
    });

    it('REJECTED: role untouched, reviewerNote stored', async () => {
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const learner = await createUser({ role: 'LEARNER' });
      const appRow = await createDesignerApplication(learner.id, {
        status: 'PENDING',
      });
      const res = await request(app)
        .patch(`/api/admin/designer-applications/${appRow.id}`)
        .set('authorization', `Bearer ${admin.accessToken}`)
        .send({ status: 'REJECTED', reviewerNote: 'insufficient portfolio' });
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('REJECTED');
      expect(res.body.reviewerNote).toBe('insufficient portfolio');
      const after = await prisma.user.findUnique({ where: { id: learner.id } });
      expect(after?.role).toBe('LEARNER');
    });

    it('APPROVED with simulated transaction failure: application unchanged', async () => {
      // The atomicity guarantee comes from prisma.$transaction. We simulate
      // a mid-transaction failure by spying on prisma.$transaction and
      // making it reject. Because the service only commits on success, the
      // DesignerApplication row should still be PENDING afterward.
      const app = await getTestApp();
      const admin = await createUser({ role: 'ADMIN' });
      const learner = await createUser({ role: 'LEARNER' });
      const appRow = await createDesignerApplication(learner.id, {
        status: 'PENDING',
      });

      const spy = jest
        .spyOn(prisma, '$transaction')
        .mockRejectedValueOnce(new Error('simulated failure'));

      const res = await request(app)
        .patch(`/api/admin/designer-applications/${appRow.id}`)
        .set('authorization', `Bearer ${admin.accessToken}`)
        .send({ status: 'APPROVED' });
      expect(res.status).toBe(500);

      const after = await prisma.designerApplication.findUnique({
        where: { id: appRow.id },
      });
      expect(after?.status).toBe('PENDING');
      const learnerAfter = await prisma.user.findUnique({
        where: { id: learner.id },
      });
      expect(learnerAfter?.role).toBe('LEARNER');

      spy.mockRestore();
    });
  });
});
