import type { Role } from '@prisma/client';

declare global {
  namespace Express {
    interface Request {
      user?: { id: string; role: Role; email: string; sid?: string };
    }
  }
}

export {};
