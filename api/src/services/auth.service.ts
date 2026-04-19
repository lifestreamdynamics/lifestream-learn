import { Prisma, type PrismaClient, type User } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import { hashPassword, verifyPassword } from '@/utils/password';
import { signAccessToken, signRefreshToken } from '@/utils/jwt';
import { ConflictError, UnauthorizedError } from '@/utils/errors';

// Dummy hash used when the user lookup misses, so bcrypt runs in both paths
// and login latency can't be used to distinguish "no such user" from "wrong
// password". Computed lazily at first miss.
let DUMMY_HASH: string | undefined;
async function getDummyHash(): Promise<string> {
  if (!DUMMY_HASH) DUMMY_HASH = await hashPassword('not-a-real-password-placeholder');
  return DUMMY_HASH;
}

export interface PublicUser {
  id: string;
  email: string;
  role: User['role'];
  displayName: string;
  createdAt: Date;
}

export interface AuthService {
  signup(input: {
    email: string;
    password: string;
    displayName: string;
  }): Promise<{ user: PublicUser; accessToken: string; refreshToken: string }>;
  login(input: {
    email: string;
    password: string;
  }): Promise<{ user: PublicUser; accessToken: string; refreshToken: string }>;
  refresh(userId: string): Promise<{ accessToken: string; refreshToken: string }>;
  findById(id: string): Promise<PublicUser>;
}

function toPublic(u: User): PublicUser {
  return {
    id: u.id,
    email: u.email,
    role: u.role,
    displayName: u.displayName,
    createdAt: u.createdAt,
  };
}

export function createAuthService(prisma: PrismaClient = defaultPrisma): AuthService {
  return {
    async signup({ email, password, displayName }) {
      const passwordHash = await hashPassword(password);
      try {
        const user = await prisma.user.create({
          data: { email, passwordHash, displayName, role: 'LEARNER' },
        });
        return {
          user: toPublic(user),
          accessToken: signAccessToken(user),
          refreshToken: signRefreshToken(user),
        };
      } catch (err) {
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
          throw new ConflictError('Email already registered');
        }
        throw err;
      }
    },

    async login({ email, password }) {
      const user = await prisma.user.findUnique({ where: { email } });
      // Always run bcrypt so the response time doesn't leak whether the email
      // exists: a missing user is compared against a dummy hash and the final
      // decision is gated on both the lookup result and the hash match.
      const hash = user?.passwordHash ?? (await getDummyHash());
      const passwordMatches = await verifyPassword(password, hash);
      if (!user || !passwordMatches) {
        throw new UnauthorizedError('Invalid credentials');
      }
      return {
        user: toPublic(user),
        accessToken: signAccessToken(user),
        refreshToken: signRefreshToken(user),
      };
    },

    async refresh(userId) {
      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) throw new UnauthorizedError('Invalid or expired token');
      return {
        accessToken: signAccessToken(user),
        refreshToken: signRefreshToken(user),
      };
    },

    async findById(id) {
      const user = await prisma.user.findUnique({ where: { id } });
      if (!user) throw new UnauthorizedError('Invalid or expired token');
      return toPublic(user);
    },
  };
}

export const authService = createAuthService();
