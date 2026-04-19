import request from 'supertest';
import { getTestApp } from '@tests/integration/helpers/test-app';
import { resetDb, resetRateLimits } from '@tests/integration/helpers/reset-db';
import { closeConnections } from '@tests/integration/helpers/teardown';

describe('Auth flow (integration)', () => {
  beforeEach(async () => {
    await resetDb();
    await resetRateLimits();
  });

  afterAll(async () => {
    await closeConnections();
  });

  it('signup → login → /me round-trip works', async () => {
    const app = await getTestApp();

    const signup = await request(app)
      .post('/api/auth/signup')
      .send({
        email: 'learner@example.local',
        password: 'CorrectHorseBattery1',
        displayName: 'Learner One',
      });
    expect(signup.status).toBe(201);
    expect(signup.body.user.role).toBe('LEARNER');
    expect(signup.body.user.email).toBe('learner@example.local');
    expect(signup.body.accessToken).toEqual(expect.any(String));
    expect(signup.body.refreshToken).toEqual(expect.any(String));

    const login = await request(app)
      .post('/api/auth/login')
      .send({ email: 'learner@example.local', password: 'CorrectHorseBattery1' });
    expect(login.status).toBe(200);
    expect(login.body.user.id).toBe(signup.body.user.id);

    const me = await request(app)
      .get('/api/auth/me')
      .set('authorization', `Bearer ${login.body.accessToken}`);
    expect(me.status).toBe(200);
    expect(me.body.email).toBe('learner@example.local');
    expect(me.body.role).toBe('LEARNER');
  });

  it('returns 401 on missing bearer token', async () => {
    const app = await getTestApp();
    const res = await request(app).get('/api/auth/me');
    expect(res.status).toBe(401);
  });

  it('returns 409 on duplicate signup', async () => {
    const app = await getTestApp();
    const body = {
      email: 'dup@example.local',
      password: 'CorrectHorseBattery1',
      displayName: 'Dup',
    };
    const first = await request(app).post('/api/auth/signup').send(body);
    expect(first.status).toBe(201);

    const second = await request(app).post('/api/auth/signup').send(body);
    expect(second.status).toBe(409);
    expect(second.body.error).toBe('CONFLICT');
  });

  it('returns 401 with generic message on wrong password (no email enumeration)', async () => {
    const app = await getTestApp();
    await request(app).post('/api/auth/signup').send({
      email: 'target@example.local',
      password: 'CorrectHorseBattery1',
      displayName: 'Target',
    });

    const wrongPw = await request(app)
      .post('/api/auth/login')
      .send({ email: 'target@example.local', password: 'wrongpassword' });
    const noSuchUser = await request(app)
      .post('/api/auth/login')
      .send({ email: 'ghost@example.local', password: 'whatever1234' });

    expect(wrongPw.status).toBe(401);
    expect(noSuchUser.status).toBe(401);
    expect(wrongPw.body.message).toBe(noSuchUser.body.message);
    expect(wrongPw.body.error).toBe('UNAUTHORIZED');
  });

  it('refresh endpoint issues a new token pair', async () => {
    const app = await getTestApp();
    const signup = await request(app).post('/api/auth/signup').send({
      email: 'ref@example.local',
      password: 'CorrectHorseBattery1',
      displayName: 'Ref',
    });
    const refresh = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: signup.body.refreshToken });
    expect(refresh.status).toBe(200);
    expect(refresh.body.accessToken).toEqual(expect.any(String));
    expect(refresh.body.refreshToken).toEqual(expect.any(String));
  });

  it('rejects malformed signup payload with 400', async () => {
    const app = await getTestApp();
    const res = await request(app)
      .post('/api/auth/signup')
      .send({ email: 'not-an-email', password: 'short', displayName: '' });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('VALIDATION_ERROR');
    expect(Array.isArray(res.body.issues)).toBe(true);
  });
});
