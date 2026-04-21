import '@tests/unit/setup';

import { Prisma } from '@prisma/client';

// We mock `@simplewebauthn/server` at the module boundary so the unit
// tests stay focused on OUR service's branching (challenge binding,
// sign-count regression, backup-code lifecycle) without having to mint
// a real signed attestation for every assertion.
jest.mock('@simplewebauthn/server', () => ({
  generateRegistrationOptions: jest.fn(),
  verifyRegistrationResponse: jest.fn(),
  generateAuthenticationOptions: jest.fn(),
  verifyAuthenticationResponse: jest.fn(),
}));

import {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
} from '@simplewebauthn/server';
import {
  createMfaWebauthnService,
  MFA_WEBAUTHN_REG_JWT_KIND,
  MFA_WEBAUTHN_AUTH_JWT_KIND,
} from '@/services/mfa-webauthn.service';
import {
  ConflictError,
  NotFoundError,
  UnauthorizedError,
} from '@/utils/errors';
import { hashPassword } from '@/utils/password';
import jwt from 'jsonwebtoken';
import { env } from '@/config/env';
import { JWT_AUDIENCE } from '@/utils/jwt';

type FakeCred = {
  id: string;
  userId: string;
  kind: 'TOTP' | 'WEBAUTHN';
  label: string | null;
  credentialId: Uint8Array | null;
  publicKey: Uint8Array | null;
  signCount: number | null;
  transports: string[];
  aaguid: string | null;
  createdAt: Date;
  lastUsedAt: Date | null;
};

type FakeUser = {
  id: string;
  email: string;
  displayName: string;
  passwordHash: string;
  deletedAt: Date | null;
  mfaEnabled: boolean;
  mfaBackupCodes: string[];
};

function matchesBytes(a: Uint8Array, b: Uint8Array): boolean {
  if (a.byteLength !== b.byteLength) return false;
  for (let i = 0; i < a.byteLength; i++) if (a[i] !== b[i]) return false;
  return true;
}

function buildFakePrisma(initial: {
  user: FakeUser;
  creds?: FakeCred[];
}): unknown {
  const state = {
    user: { ...initial.user },
    creds: [...(initial.creds ?? [])] as FakeCred[],
  };

  const api: any = {
    user: {
      findUnique: jest.fn(async ({ where, select }: any) => {
        if (state.user.id !== where.id) return null;
        const row: Record<string, unknown> = { ...state.user };
        if (select?.mfaCredentials) {
          row.mfaCredentials = state.creds
            .filter((c) => c.kind === select.mfaCredentials.where.kind)
            .map((c) => ({
              credentialId: c.credentialId,
              transports: c.transports,
            }));
        }
        return row;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        if (state.user.id !== where.id) throw new Error('user not found');
        state.user = { ...state.user, ...data };
        return state.user;
      }),
    },
    mfaCredential: {
      findFirst: jest.fn(async ({ where }: any) => {
        const match = state.creds.find((c) => {
          if (where.userId && c.userId !== where.userId) return false;
          if (where.kind && c.kind !== where.kind) return false;
          if (where.id && c.id !== where.id) return false;
          return true;
        });
        return match ?? null;
      }),
      findUnique: jest.fn(async ({ where }: any) => {
        if (where.credentialId) {
          return (
            state.creds.find(
              (c) =>
                c.credentialId != null &&
                matchesBytes(c.credentialId, where.credentialId),
            ) ?? null
          );
        }
        return state.creds.find((c) => c.id === where.id) ?? null;
      }),
      findMany: jest.fn(async ({ where }: any) => {
        return state.creds.filter((c) => {
          if (where.userId && c.userId !== where.userId) return false;
          if (where.kind && c.kind !== where.kind) return false;
          return true;
        });
      }),
      create: jest.fn(async ({ data }: any) => {
        // Reject duplicate credentialId — the real DB has a unique
        // index; mirror that here so the service's P2002 handler fires.
        if (
          data.credentialId &&
          state.creds.some(
            (c) =>
              c.credentialId != null &&
              matchesBytes(c.credentialId, data.credentialId),
          )
        ) {
          throw new Prisma.PrismaClientKnownRequestError(
            'unique constraint',
            { code: 'P2002', clientVersion: 'test' },
          );
        }
        const row: FakeCred = {
          id: `cred-${state.creds.length + 1}`,
          userId: data.userId,
          kind: data.kind,
          label: data.label ?? null,
          credentialId: data.credentialId ?? null,
          publicKey: data.publicKey ?? null,
          signCount: data.signCount ?? 0,
          transports: data.transports ?? [],
          aaguid: data.aaguid ?? null,
          createdAt: new Date(),
          lastUsedAt: null,
        };
        state.creds.push(row);
        return row;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const idx = state.creds.findIndex((c) => c.id === where.id);
        if (idx < 0) throw new Error('cred not found');
        state.creds[idx] = { ...state.creds[idx]!, ...data };
        return state.creds[idx];
      }),
      delete: jest.fn(async ({ where }: any) => {
        const idx = state.creds.findIndex((c) => c.id === where.id);
        if (idx < 0) throw new Error('cred not found');
        const [removed] = state.creds.splice(idx, 1);
        return removed;
      }),
      count: jest.fn(async ({ where }: any) => {
        return state.creds.filter((c) => {
          if (where.userId && c.userId !== where.userId) return false;
          if (
            where.kind &&
            typeof where.kind === 'object' &&
            'in' in where.kind
          ) {
            return (where.kind.in as string[]).includes(c.kind);
          }
          if (where.kind && c.kind !== where.kind) return false;
          return true;
        }).length;
      }),
    },
    $transaction: jest.fn(async (fn: any): Promise<any> => {
      // Accept both function form and array form. Production uses the
      // function form so callbacks can interleave with non-tx queries.
      if (typeof fn === 'function') return fn(api);
      return Promise.all(fn);
    }),
    _state: state,
  };
  return api;
}

const USER_ID = '00000000-0000-0000-0000-00000000ffff';

async function baseUser(): Promise<FakeUser> {
  return {
    id: USER_ID,
    email: 'wa@example.local',
    displayName: 'Webauthn User',
    passwordHash: await hashPassword('currentPassword123!'),
    deletedAt: null,
    mfaEnabled: false,
    mfaBackupCodes: [],
  };
}

const mockedGenReg = generateRegistrationOptions as jest.MockedFunction<
  typeof generateRegistrationOptions
>;
const mockedVerifyReg = verifyRegistrationResponse as jest.MockedFunction<
  typeof verifyRegistrationResponse
>;
const mockedGenAuth = generateAuthenticationOptions as jest.MockedFunction<
  typeof generateAuthenticationOptions
>;
const mockedVerifyAuth = verifyAuthenticationResponse as jest.MockedFunction<
  typeof verifyAuthenticationResponse
>;

function stubRegOptions(challenge = 'REG-CHALLENGE-ABC'): void {
  mockedGenReg.mockResolvedValue({
    challenge,
    rp: { id: 'localhost', name: 'Lifestream Learn' },
    user: { id: 'u', name: 'u', displayName: 'u' },
    pubKeyCredParams: [],
    timeout: 60000,
    attestation: 'none',
    excludeCredentials: [],
    authenticatorSelection: {},
  } as any);
}

function stubAuthOptions(challenge = 'AUTH-CHALLENGE-XYZ'): void {
  mockedGenAuth.mockResolvedValue({
    challenge,
    timeout: 60000,
    rpId: 'localhost',
    userVerification: 'preferred',
    allowCredentials: [],
  } as any);
}

function stubRegVerifySuccess(credId: Uint8Array, publicKey: Uint8Array): void {
  mockedVerifyReg.mockResolvedValue({
    verified: true,
    registrationInfo: {
      fmt: 'none',
      aaguid: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      credential: {
        id: Buffer.from(credId).toString('base64url'),
        publicKey,
        counter: 0,
      },
      credentialType: 'public-key',
      attestationObject: new Uint8Array(),
      userVerified: true,
      credentialDeviceType: 'singleDevice',
      credentialBackedUp: false,
      origin: 'http://localhost:3011',
      rpID: 'localhost',
    },
  } as any);
}

function stubAuthVerify(verified: boolean, newCounter: number, credId: Uint8Array): void {
  mockedVerifyAuth.mockResolvedValue({
    verified,
    authenticationInfo: {
      credentialID: Buffer.from(credId).toString('base64url'),
      newCounter,
      userVerified: true,
      credentialDeviceType: 'singleDevice',
      credentialBackedUp: false,
      origin: 'http://localhost:3011',
      rpID: 'localhost',
    },
  } as any);
}

beforeEach(() => {
  jest.clearAllMocks();
});

describe('mfa-webauthn.service', () => {
  describe('startRegistration', () => {
    it('throws NotFoundError for an unknown user', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaWebauthnService(prisma as any);
      await expect(
        svc.startRegistration('00000000-0000-0000-0000-00000000dead'),
      ).rejects.toBeInstanceOf(NotFoundError);
    });

    it('returns options + a pending token whose `kind` and `sub` bind this user', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaWebauthnService(prisma as any);
      stubRegOptions('REG-CHALLENGE-ABC');

      const result = await svc.startRegistration(USER_ID);
      expect(result.options.challenge).toBe('REG-CHALLENGE-ABC');

      const decoded = jwt.verify(result.pendingToken, env.JWT_ACCESS_SECRET, {
        audience: JWT_AUDIENCE,
      }) as Record<string, unknown>;
      expect(decoded.kind).toBe(MFA_WEBAUTHN_REG_JWT_KIND);
      expect(decoded.sub).toBe(USER_ID);
      expect(decoded.challenge).toBe('REG-CHALLENGE-ABC');
    });
  });

  describe('verifyRegistration', () => {
    it('rejects a pending token whose `sub` does not match the caller', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaWebauthnService(prisma as any);
      const foreignToken = jwt.sign(
        {
          sub: '00000000-0000-0000-0000-00000000aaaa',
          kind: MFA_WEBAUTHN_REG_JWT_KIND,
          challenge: 'x',
        },
        env.JWT_ACCESS_SECRET,
        { audience: JWT_AUDIENCE, expiresIn: '5m' },
      );
      await expect(
        svc.verifyRegistration(USER_ID, {
          pendingToken: foreignToken,
          attestationResponse: { id: '', rawId: '', type: 'public-key', response: {} } as any,
        }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('happy path: persists credential, flips mfaEnabled, returns backup codes on first factor', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaWebauthnService(prisma as any);
      stubRegOptions('R1');
      const credId = new Uint8Array(32).fill(7);
      const pubKey = new Uint8Array([1, 2, 3, 4]);
      stubRegVerifySuccess(credId, pubKey);

      const pendingToken = jwt.sign(
        { sub: USER_ID, kind: MFA_WEBAUTHN_REG_JWT_KIND, challenge: 'R1' },
        env.JWT_ACCESS_SECRET,
        { audience: JWT_AUDIENCE, expiresIn: '5m' },
      );

      const result = await svc.verifyRegistration(USER_ID, {
        pendingToken,
        attestationResponse: {
          id: Buffer.from(credId).toString('base64url'),
          rawId: Buffer.from(credId).toString('base64url'),
          type: 'public-key',
          response: { transports: ['internal'] },
        } as any,
        label: 'Phone',
      });

      expect(result.credentialId).toBe(Buffer.from(credId).toString('base64url'));
      expect(result.backupCodes).toHaveLength(10);
      // State side-effects:
      const state = (prisma as any)._state;
      expect(state.creds).toHaveLength(1);
      expect(state.creds[0].kind).toBe('WEBAUTHN');
      expect(state.creds[0].label).toBe('Phone');
      expect(state.user.mfaEnabled).toBe(true);
      expect(state.user.mfaBackupCodes).toHaveLength(10);
    });

    it('second registration (TOTP already enabled) does NOT mint new backup codes', async () => {
      const user = await baseUser();
      user.mfaEnabled = true;
      // Simulate pre-existing backup codes from the TOTP path.
      user.mfaBackupCodes = Array.from({ length: 10 }, () => '$2b$12$existing-hash');
      const prisma = buildFakePrisma({ user });
      const svc = createMfaWebauthnService(prisma as any);
      stubRegOptions('R2');
      const credId = new Uint8Array(32).fill(11);
      stubRegVerifySuccess(credId, new Uint8Array([9, 9]));

      const pendingToken = jwt.sign(
        { sub: USER_ID, kind: MFA_WEBAUTHN_REG_JWT_KIND, challenge: 'R2' },
        env.JWT_ACCESS_SECRET,
        { audience: JWT_AUDIENCE, expiresIn: '5m' },
      );

      const result = await svc.verifyRegistration(USER_ID, {
        pendingToken,
        attestationResponse: {
          id: Buffer.from(credId).toString('base64url'),
          rawId: Buffer.from(credId).toString('base64url'),
          type: 'public-key',
          response: {},
        } as any,
      });
      expect(result.backupCodes).toBeUndefined();
      // Existing codes preserved.
      const state = (prisma as any)._state;
      expect(state.user.mfaBackupCodes).toHaveLength(10);
    });

    it('duplicate credentialId → ConflictError', async () => {
      const user = await baseUser();
      const existingCredId = new Uint8Array(32).fill(42);
      const prisma = buildFakePrisma({
        user,
        creds: [
          {
            id: 'cred-existing',
            userId: USER_ID,
            kind: 'WEBAUTHN',
            label: null,
            credentialId: existingCredId,
            publicKey: new Uint8Array([1]),
            signCount: 3,
            transports: [],
            aaguid: null,
            createdAt: new Date(),
            lastUsedAt: null,
          },
        ],
      });
      const svc = createMfaWebauthnService(prisma as any);
      stubRegOptions('R3');
      stubRegVerifySuccess(existingCredId, new Uint8Array([2]));

      const pendingToken = jwt.sign(
        { sub: USER_ID, kind: MFA_WEBAUTHN_REG_JWT_KIND, challenge: 'R3' },
        env.JWT_ACCESS_SECRET,
        { audience: JWT_AUDIENCE, expiresIn: '5m' },
      );

      await expect(
        svc.verifyRegistration(USER_ID, {
          pendingToken,
          attestationResponse: {
            id: Buffer.from(existingCredId).toString('base64url'),
            rawId: Buffer.from(existingCredId).toString('base64url'),
            type: 'public-key',
            response: {},
          } as any,
        }),
      ).rejects.toBeInstanceOf(ConflictError);
    });
  });

  describe('verifyAuthentication (sign-count regression)', () => {
    async function setupWithStoredCounter(storedSignCount: number) {
      const user = await baseUser();
      user.mfaEnabled = true;
      const credId = new Uint8Array(32).fill(99);
      const prisma = buildFakePrisma({
        user,
        creds: [
          {
            id: 'cred-1',
            userId: USER_ID,
            kind: 'WEBAUTHN',
            label: null,
            credentialId: credId,
            publicKey: new Uint8Array([5, 5, 5]),
            signCount: storedSignCount,
            transports: [],
            aaguid: null,
            createdAt: new Date(),
            lastUsedAt: null,
          },
        ],
      });
      const svc = createMfaWebauthnService(prisma as any);
      return { svc, prisma, credId };
    }

    function mintChallengeToken(challenge: string): string {
      return jwt.sign(
        { sub: USER_ID, kind: MFA_WEBAUTHN_AUTH_JWT_KIND, challenge },
        env.JWT_ACCESS_SECRET,
        { audience: JWT_AUDIENCE, expiresIn: '5m' },
      );
    }

    it('rejects when newCounter <= storedSignCount and both are not zero', async () => {
      const { svc, prisma, credId } = await setupWithStoredCounter(5);
      stubAuthVerify(true, 5, credId); // newCounter == stored → regression

      const token = mintChallengeToken('C1');
      await expect(
        svc.verifyAuthentication(USER_ID, {
          challengeToken: token,
          assertionResponse: {
            id: Buffer.from(credId).toString('base64url'),
            rawId: Buffer.from(credId).toString('base64url'),
            type: 'public-key',
            response: {},
          } as any,
        }),
      ).rejects.toBeInstanceOf(UnauthorizedError);

      // Stored counter NOT updated on regression.
      const state = (prisma as any)._state;
      expect(state.creds[0].signCount).toBe(5);
    });

    it('accepts when both stored and newCounter are 0 (counter-less authenticator)', async () => {
      const { svc, credId } = await setupWithStoredCounter(0);
      stubAuthVerify(true, 0, credId);

      const token = mintChallengeToken('C2');
      const ok = await svc.verifyAuthentication(USER_ID, {
        challengeToken: token,
        assertionResponse: {
          id: Buffer.from(credId).toString('base64url'),
          rawId: Buffer.from(credId).toString('base64url'),
          type: 'public-key',
          response: {},
        } as any,
      });
      expect(ok).toBe(true);
    });

    it('happy path: newCounter > stored → updates signCount + lastUsedAt', async () => {
      const { svc, prisma, credId } = await setupWithStoredCounter(3);
      stubAuthVerify(true, 7, credId);

      const token = mintChallengeToken('C3');
      const ok = await svc.verifyAuthentication(USER_ID, {
        challengeToken: token,
        assertionResponse: {
          id: Buffer.from(credId).toString('base64url'),
          rawId: Buffer.from(credId).toString('base64url'),
          type: 'public-key',
          response: {},
        } as any,
      });
      expect(ok).toBe(true);
      const state = (prisma as any)._state;
      expect(state.creds[0].signCount).toBe(7);
      expect(state.creds[0].lastUsedAt).toBeInstanceOf(Date);
    });

    it('returns false when the stored credential does not belong to the caller', async () => {
      const { svc, credId } = await setupWithStoredCounter(3);
      stubAuthVerify(true, 4, credId);
      const otherUser = '00000000-0000-0000-0000-000000000abc';

      const token = jwt.sign(
        { sub: otherUser, kind: MFA_WEBAUTHN_AUTH_JWT_KIND, challenge: 'C4' },
        env.JWT_ACCESS_SECRET,
        { audience: JWT_AUDIENCE, expiresIn: '5m' },
      );

      const ok = await svc.verifyAuthentication(otherUser, {
        challengeToken: token,
        assertionResponse: {
          id: Buffer.from(credId).toString('base64url'),
          rawId: Buffer.from(credId).toString('base64url'),
          type: 'public-key',
          response: {},
        } as any,
      });
      // credential belongs to USER_ID, not `otherUser` — service returns false.
      expect(ok).toBe(false);
    });

    it('rejects a challenge token bound to a different user (sub mismatch) with 401', async () => {
      const { svc, credId } = await setupWithStoredCounter(3);
      const otherToken = jwt.sign(
        {
          sub: '00000000-0000-0000-0000-00000000beef',
          kind: MFA_WEBAUTHN_AUTH_JWT_KIND,
          challenge: 'X',
        },
        env.JWT_ACCESS_SECRET,
        { audience: JWT_AUDIENCE, expiresIn: '5m' },
      );
      await expect(
        svc.verifyAuthentication(USER_ID, {
          challengeToken: otherToken,
          assertionResponse: {
            id: Buffer.from(credId).toString('base64url'),
            rawId: Buffer.from(credId).toString('base64url'),
            type: 'public-key',
            response: {},
          } as any,
        }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });
  });

  describe('deleteCredential', () => {
    it('401 on wrong current password', async () => {
      const user = await baseUser();
      const credId = new Uint8Array(32).fill(1);
      const prisma = buildFakePrisma({
        user,
        creds: [
          {
            id: 'cred-1',
            userId: USER_ID,
            kind: 'WEBAUTHN',
            label: null,
            credentialId: credId,
            publicKey: new Uint8Array([1]),
            signCount: 0,
            transports: [],
            aaguid: null,
            createdAt: new Date(),
            lastUsedAt: null,
          },
        ],
      });
      const svc = createMfaWebauthnService(prisma as any);
      await expect(
        svc.deleteCredential(USER_ID, 'cred-1', { currentPassword: 'wrong' }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('deleting the last factor flips mfaEnabled=false and clears backup codes', async () => {
      const user = await baseUser();
      user.mfaEnabled = true;
      user.mfaBackupCodes = Array.from({ length: 10 }, () => '$2b$12$x');
      const credId = new Uint8Array(32).fill(1);
      const prisma = buildFakePrisma({
        user,
        creds: [
          {
            id: 'cred-1',
            userId: USER_ID,
            kind: 'WEBAUTHN',
            label: null,
            credentialId: credId,
            publicKey: new Uint8Array([1]),
            signCount: 0,
            transports: [],
            aaguid: null,
            createdAt: new Date(),
            lastUsedAt: null,
          },
        ],
      });
      const svc = createMfaWebauthnService(prisma as any);
      await svc.deleteCredential(USER_ID, 'cred-1', {
        currentPassword: 'currentPassword123!',
      });
      const state = (prisma as any)._state;
      expect(state.creds).toHaveLength(0);
      expect(state.user.mfaEnabled).toBe(false);
      expect(state.user.mfaBackupCodes).toEqual([]);
    });

    it('deleting one of multiple factors leaves mfaEnabled=true', async () => {
      const user = await baseUser();
      user.mfaEnabled = true;
      user.mfaBackupCodes = Array.from({ length: 10 }, () => '$2b$12$x');
      const credId = new Uint8Array(32).fill(1);
      const prisma = buildFakePrisma({
        user,
        creds: [
          {
            id: 'cred-1',
            userId: USER_ID,
            kind: 'WEBAUTHN',
            label: null,
            credentialId: credId,
            publicKey: new Uint8Array([1]),
            signCount: 0,
            transports: [],
            aaguid: null,
            createdAt: new Date(),
            lastUsedAt: null,
          },
          {
            id: 'cred-totp',
            userId: USER_ID,
            kind: 'TOTP',
            label: null,
            credentialId: null,
            publicKey: null,
            signCount: null,
            transports: [],
            aaguid: null,
            createdAt: new Date(),
            lastUsedAt: null,
          },
        ],
      });
      const svc = createMfaWebauthnService(prisma as any);
      await svc.deleteCredential(USER_ID, 'cred-1', {
        currentPassword: 'currentPassword123!',
      });
      const state = (prisma as any)._state;
      expect(state.user.mfaEnabled).toBe(true);
      expect(state.user.mfaBackupCodes).toHaveLength(10);
    });

    it('404 when credential belongs to another user (service throws NotFoundError)', async () => {
      const user = await baseUser();
      const credId = new Uint8Array(32).fill(1);
      const prisma = buildFakePrisma({
        user,
        creds: [
          {
            id: 'cred-1',
            userId: '00000000-0000-0000-0000-000000000bbb',
            kind: 'WEBAUTHN',
            label: null,
            credentialId: credId,
            publicKey: new Uint8Array([1]),
            signCount: 0,
            transports: [],
            aaguid: null,
            createdAt: new Date(),
            lastUsedAt: null,
          },
        ],
      });
      const svc = createMfaWebauthnService(prisma as any);
      await expect(
        svc.deleteCredential(USER_ID, 'cred-1', {
          currentPassword: 'currentPassword123!',
        }),
      ).rejects.toBeInstanceOf(NotFoundError);
    });
  });

  describe('startAuthentication', () => {
    it('allowCredentials lists the user\'s registered credential ids', async () => {
      const user = await baseUser();
      const credId = new Uint8Array(32).fill(33);
      const prisma = buildFakePrisma({
        user,
        creds: [
          {
            id: 'cred-1',
            userId: USER_ID,
            kind: 'WEBAUTHN',
            label: null,
            credentialId: credId,
            publicKey: new Uint8Array([1]),
            signCount: 2,
            transports: ['internal'],
            aaguid: null,
            createdAt: new Date(),
            lastUsedAt: null,
          },
        ],
      });
      const svc = createMfaWebauthnService(prisma as any);
      stubAuthOptions('AUTH1');
      const result = await svc.startAuthentication(USER_ID);
      expect(result.options.challenge).toBe('AUTH1');
      // The library call should have been handed `allowCredentials` that
      // includes the user's credential id.
      const argObj = mockedGenAuth.mock.calls[0]![0] as any;
      expect(argObj.allowCredentials).toHaveLength(1);
      expect(argObj.allowCredentials[0].id).toBe(
        Buffer.from(credId).toString('base64url'),
      );
      // Challenge token's sub must bind to this user.
      const decoded = jwt.verify(result.challengeToken, env.JWT_ACCESS_SECRET, {
        audience: JWT_AUDIENCE,
      }) as Record<string, unknown>;
      expect(decoded.sub).toBe(USER_ID);
      expect(decoded.kind).toBe(MFA_WEBAUTHN_AUTH_JWT_KIND);
    });
  });
});
