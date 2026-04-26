import '@tests/unit/setup';

import {
  generate as otpGenerate,
  generateSecret as otpGenerateSecret,
} from 'otplib';
import type { PrismaClient } from '@prisma/client';
import {
  createMfaTotpService,
  MFA_ENROL_JWT_KIND,
  MFA_LOGIN_JWT_KIND,
  LOGIN_MFA_JWT_TTL,
} from '@/services/mfa-totp.service';
import { ConflictError, NotFoundError, UnauthorizedError } from '@/utils/errors';
import { hashPassword } from '@/utils/password';
import jwt from 'jsonwebtoken';
import { env } from '@/config/env';
import { JWT_AUDIENCE } from '@/utils/jwt';
import { encryptTotpSecret } from '@/services/mfa/crypto';

// ---- Mock Prisma --------------------------------------------------------
//
// Slice P7a unit tests exercise the TOTP service against an in-memory
// fake that only implements the method surface the service actually
// touches. Integration tests hit a real DB; keeping the unit surface
// small lets us assert each invariant without dragging in Prisma's
// type footprint.

type FakeUser = {
  id: string;
  email: string;
  passwordHash: string;
  deletedAt: Date | null;
  mfaEnabled: boolean;
  mfaBackupCodes: string[];
  mfaCredentials: FakeMfaCredential[];
};

type FakeMfaCredential = {
  id: string;
  userId: string;
  kind: 'TOTP' | 'WEBAUTHN';
  label: string | null;
  totpSecretEncrypted: string | null;
  lastUsedAt: Date | null;
};

// Minimal query-arg shapes — only the fields the fake's callbacks
// actually read. Typed explicitly so jest.fn callbacks stay free of `any`.
type WhereId = { id?: string; email?: string };
type WhereData<D> = { where: WhereId; data: D };
type WhereCred = {
  id?: string;
  kind?: string | { in: string[] };
  userId?: string;
};
type CredCreateData = {
  userId: string;
  kind: FakeMfaCredential['kind'];
  label?: string | null;
  totpSecretEncrypted?: string | null;
};
type SelectArg = {
  mfaCredentials?: { where: { kind: string } };
};

type FakePrismaState = { user: FakeUser; creds: FakeMfaCredential[] };

type FakePrisma = {
  user: {
    findUnique: jest.Mock;
    update: jest.Mock;
  };
  mfaCredential: {
    findFirst: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
    count: jest.Mock;
  };
  $transaction: jest.Mock;
  _state: FakePrismaState;
};

function buildFakePrisma(initial: { user: FakeUser }): FakePrisma {
  const state: FakePrismaState = {
    user: { ...initial.user },
    creds: [...initial.user.mfaCredentials],
  };

  function findCred(where: Partial<FakeMfaCredential>): FakeMfaCredential | undefined {
    return state.creds.find((c) =>
      Object.entries(where).every(([k, v]) => {
        if (k === 'kind' && typeof v === 'object' && v !== null && 'in' in v) {
          return (v as { in: string[] }).in.includes(c.kind);
        }
        return (c as unknown as Record<string, unknown>)[k] === v;
      }),
    );
  }

  return {
    user: {
      findUnique: jest.fn(async ({ where, select }: { where: WhereId; select?: SelectArg }) => {
        if (state.user.id !== where.id && state.user.email !== where.email) return null;
        const row: Record<string, unknown> = { ...state.user };
        if (select?.mfaCredentials) {
          row.mfaCredentials = state.creds.filter(
            (c) => c.kind === select.mfaCredentials?.where.kind,
          );
        }
        return row;
      }),
      update: jest.fn(async ({ where, data }: WhereData<Partial<FakeUser>>) => {
        if (state.user.id !== where.id) throw new Error('user not found');
        state.user = { ...state.user, ...data };
        return state.user;
      }),
    },
    mfaCredential: {
      findFirst: jest.fn(async ({ where }: { where: WhereCred }) => findCred(where as Partial<FakeMfaCredential>) ?? null),
      create: jest.fn(async ({ data }: { data: CredCreateData }) => {
        const row: FakeMfaCredential = {
          id: `cred-${state.creds.length + 1}`,
          userId: data.userId,
          kind: data.kind,
          label: data.label ?? null,
          totpSecretEncrypted: data.totpSecretEncrypted ?? null,
          lastUsedAt: null,
        };
        state.creds.push(row);
        return row;
      }),
      update: jest.fn(async ({ where, data }: WhereData<Partial<FakeMfaCredential>>) => {
        const idx = state.creds.findIndex((c) => c.id === where.id);
        if (idx < 0) throw new Error('cred not found');
        state.creds[idx] = { ...state.creds[idx]!, ...data };
        return state.creds[idx];
      }),
      delete: jest.fn(async ({ where }: { where: WhereId }) => {
        const idx = state.creds.findIndex((c) => c.id === where.id);
        if (idx < 0) throw new Error('cred not found');
        const [removed] = state.creds.splice(idx, 1);
        return removed;
      }),
      count: jest.fn(async ({ where }: { where: WhereCred }) => {
        if (where.kind && typeof where.kind === 'object' && 'in' in where.kind) {
          return state.creds.filter((c) =>
            (where.kind as { in: string[] }).in.includes(c.kind),
          ).length;
        }
        return state.creds.filter((c) => c.kind === where.kind).length;
      }),
    },
    $transaction: jest.fn(async (ops: Promise<unknown>[]) => Promise.all(ops)),
    _state: state,
  };
}

const USER_ID = '00000000-0000-0000-0000-00000000ffff';
const USER_EMAIL = 'mfa-user@example.local';

async function baseUser(): Promise<FakeUser> {
  return {
    id: USER_ID,
    email: USER_EMAIL,
    passwordHash: await hashPassword('currentPassword123!'),
    deletedAt: null,
    mfaEnabled: false,
    mfaBackupCodes: [],
    mfaCredentials: [],
  };
}

async function freshToken(secret: string): Promise<string> {
  return otpGenerate({ secret });
}

describe('mfa-totp.service', () => {
  describe('startEnrol', () => {
    it('returns secret + otpauth URL + QR data URL + pending token', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      const result = await svc.startEnrol(USER_ID);

      expect(result.secret).toMatch(/^[A-Z2-7]+$/); // base32
      expect(result.otpauthUrl).toMatch(/^otpauth:\/\/totp\//);
      expect(result.qrDataUrl).toMatch(/^data:image\/png;base64,/);
      expect(typeof result.pendingEnrolmentToken).toBe('string');

      // Pending token carries the same secret + correct kind claim.
      const decoded = jwt.verify(
        result.pendingEnrolmentToken,
        env.JWT_ACCESS_SECRET,
        { audience: JWT_AUDIENCE },
      ) as Record<string, unknown>;
      expect(decoded.kind).toBe(MFA_ENROL_JWT_KIND);
      expect(decoded.sub).toBe(USER_ID);
      expect(decoded.secret).toBe(result.secret);
    });

    it('throws ConflictError when TOTP is already enrolled', async () => {
      const user = await baseUser();
      user.mfaCredentials = [
        {
          id: 'cred-existing',
          userId: USER_ID,
          kind: 'TOTP',
          label: null,
          totpSecretEncrypted: encryptTotpSecret(otpGenerateSecret()),
          lastUsedAt: null,
        },
      ];
      user.mfaEnabled = true;
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      await expect(svc.startEnrol(USER_ID)).rejects.toBeInstanceOf(ConflictError);
    });

    it('throws NotFoundError for an unknown user', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      await expect(
        svc.startEnrol('00000000-0000-0000-0000-00000000dead'),
      ).rejects.toBeInstanceOf(NotFoundError);
    });
  });

  describe('confirmEnrol', () => {
    it('writes an MfaCredential, flips mfaEnabled, returns 10 backup codes', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);

      const start = await svc.startEnrol(USER_ID);
      const code = await freshToken(start.secret);
      const result = await svc.confirmEnrol(USER_ID, {
        pendingToken: start.pendingEnrolmentToken,
        code,
        label: 'My Phone',
      });

      expect(result.backupCodes).toHaveLength(10);
      const s = prisma._state;
      expect(s.user.mfaEnabled).toBe(true);
      expect(s.user.mfaBackupCodes).toHaveLength(10);
      expect(s.creds).toHaveLength(1);
      expect(s.creds[0]!.kind).toBe('TOTP');
      expect(s.creds[0]!.label).toBe('My Phone');
      // Secret is encrypted — must not equal the plaintext base32 secret.
      expect(s.creds[0]!.totpSecretEncrypted).not.toBe(start.secret);
    });

    it('rejects a wrong code with 401', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      const start = await svc.startEnrol(USER_ID);
      await expect(
        svc.confirmEnrol(USER_ID, {
          pendingToken: start.pendingEnrolmentToken,
          code: '000000',
        }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('rejects an expired pending token', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      // Mint a pending token that has already expired.
      const expired = jwt.sign(
        {
          sub: USER_ID,
          kind: MFA_ENROL_JWT_KIND,
          secret: otpGenerateSecret(),
        },
        env.JWT_ACCESS_SECRET,
        {
          expiresIn: -1,
          audience: JWT_AUDIENCE,
        },
      );
      await expect(
        svc.confirmEnrol(USER_ID, { pendingToken: expired, code: '123456' }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('rejects when the pending token was minted for a different user', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      const foreign = jwt.sign(
        {
          sub: 'somebody-else',
          kind: MFA_ENROL_JWT_KIND,
          secret: otpGenerateSecret(),
        },
        env.JWT_ACCESS_SECRET,
        { expiresIn: '10m', audience: JWT_AUDIENCE },
      );
      await expect(
        svc.confirmEnrol(USER_ID, { pendingToken: foreign, code: '000000' }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });
  });

  describe('verify', () => {
    it('returns true for a current code and false for a stale one', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      const start = await svc.startEnrol(USER_ID);
      const code = await freshToken(start.secret);
      await svc.confirmEnrol(USER_ID, {
        pendingToken: start.pendingEnrolmentToken,
        code,
      });

      expect(await svc.verify(USER_ID, code)).toBe(true);
      expect(await svc.verify(USER_ID, '000000')).toBe(false);
    });

    it('returns false when the user has no TOTP credential', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      expect(await svc.verify(USER_ID, '123456')).toBe(false);
    });
  });

  describe('disable', () => {
    it('removes the TOTP credential, clears backup codes, flips mfaEnabled off', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      const start = await svc.startEnrol(USER_ID);
      const enrolCode = await freshToken(start.secret);
      await svc.confirmEnrol(USER_ID, {
        pendingToken: start.pendingEnrolmentToken,
        code: enrolCode,
      });
      const disableCode = await freshToken(start.secret);
      await svc.disable(USER_ID, {
        currentPassword: 'currentPassword123!',
        code: disableCode,
      });
      const s = prisma._state;
      expect(s.creds).toHaveLength(0);
      expect(s.user.mfaEnabled).toBe(false);
      expect(s.user.mfaBackupCodes).toEqual([]);
    });

    it('rejects a wrong password', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      const start = await svc.startEnrol(USER_ID);
      const code = await freshToken(start.secret);
      await svc.confirmEnrol(USER_ID, {
        pendingToken: start.pendingEnrolmentToken,
        code,
      });
      await expect(
        svc.disable(USER_ID, {
          currentPassword: 'wrong',
          code,
        }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });

    it('rejects a wrong code', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      const start = await svc.startEnrol(USER_ID);
      const code = await freshToken(start.secret);
      await svc.confirmEnrol(USER_ID, {
        pendingToken: start.pendingEnrolmentToken,
        code,
      });
      await expect(
        svc.disable(USER_ID, {
          currentPassword: 'currentPassword123!',
          code: '000000',
        }),
      ).rejects.toBeInstanceOf(UnauthorizedError);
    });
  });

  describe('verifyBackup', () => {
    it('burns the code on first use; second use fails', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      const start = await svc.startEnrol(USER_ID);
      const code = await freshToken(start.secret);
      const { backupCodes } = await svc.confirmEnrol(USER_ID, {
        pendingToken: start.pendingEnrolmentToken,
        code,
      });
      const firstBackup = backupCodes[0]!;
      expect(await svc.verifyBackup(USER_ID, firstBackup)).toBe(true);
      expect(await svc.verifyBackup(USER_ID, firstBackup)).toBe(false);
    });
  });

  describe('listMethods', () => {
    it('reports false/0/false before enrolment', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      const methods = await svc.listMethods(USER_ID);
      expect(methods).toEqual({
        totp: false,
        webauthnCount: 0,
        hasBackupCodes: false,
        backupCodesRemaining: 0,
      });
    });

    it('reports totp=true + backup codes count after enrolment', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      const start = await svc.startEnrol(USER_ID);
      const code = await freshToken(start.secret);
      await svc.confirmEnrol(USER_ID, {
        pendingToken: start.pendingEnrolmentToken,
        code,
      });
      const methods = await svc.listMethods(USER_ID);
      expect(methods.totp).toBe(true);
      expect(methods.hasBackupCodes).toBe(true);
      expect(methods.backupCodesRemaining).toBe(10);
    });
  });

  describe('mintLoginPendingToken / verifyLoginPendingToken', () => {
    it('round-trips the userId through a signed JWT', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      const token = svc.mintLoginPendingToken(USER_ID);
      expect(svc.verifyLoginPendingToken(token)).toEqual({ userId: USER_ID });
    });

    it('rejects tokens signed with a different secret', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      const evil = jwt.sign(
        { sub: USER_ID, kind: MFA_LOGIN_JWT_KIND },
        'not-the-real-secret-at-all-0123456789',
        { expiresIn: '5m', audience: JWT_AUDIENCE },
      );
      expect(() => svc.verifyLoginPendingToken(evil)).toThrow(UnauthorizedError);
    });

    it('rejects a cross-kind swap (access token instead of mfa-pending)', async () => {
      const user = await baseUser();
      const prisma = buildFakePrisma({ user });
      const svc = createMfaTotpService(prisma as unknown as PrismaClient);
      // A valid-looking JWT with the wrong kind claim — the service
      // must reject it so we don't trade an access token for fresh
      // tokens via the MFA path.
      const wrongKind = jwt.sign(
        { sub: USER_ID, kind: 'access' },
        env.JWT_ACCESS_SECRET,
        { expiresIn: '5m', audience: JWT_AUDIENCE },
      );
      expect(() => svc.verifyLoginPendingToken(wrongKind)).toThrow(UnauthorizedError);
    });

    it('uses the documented 5-minute TTL', async () => {
      // Documentary: LOGIN_MFA_JWT_TTL is the single source of truth,
      // so if an operator lowers it the mint path follows suit.
      expect(LOGIN_MFA_JWT_TTL).toBe('5m');
    });
  });
});
