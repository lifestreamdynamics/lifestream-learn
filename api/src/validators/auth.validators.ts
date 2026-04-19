import { z } from 'zod';

export const signupSchema = z.object({
  email: z.string().email().toLowerCase().max(254),
  password: z.string().min(12).max(128),
  displayName: z.string().min(1).max(80).trim(),
});

export const loginSchema = z.object({
  email: z.string().email().toLowerCase(),
  password: z.string().min(1).max(128),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

export type SignupInput = z.infer<typeof signupSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type RefreshInput = z.infer<typeof refreshSchema>;
