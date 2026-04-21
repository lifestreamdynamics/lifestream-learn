import { z } from 'zod';

/**
 * Body for `PATCH /api/me`. All fields are optional so the caller can
 * update one at a time. `.strict()` rejects unknown keys so an attacker
 * can't slip in `role: "ADMIN"` or `email: "..."` — those fields are
 * off-limits from this endpoint by design.
 *
 * `preferences` is a free-form JSON bag (theme/playback/a11y prefs).
 * Kept loose here because Slice P4 will define the concrete shape; a
 * Zod schema at this layer would force a coordinated change every time
 * the client grows a new preference key.
 */
export const patchMeBodySchema = z
  .object({
    displayName: z.string().trim().min(1).max(80).optional(),
    useGravatar: z.boolean().optional(),
    // Object (not array, not primitive) so the client can't accidentally
    // replace the whole bag with a scalar. `passthrough()` keeps unknown
    // keys — each client generation may add new pref keys ahead of the
    // API knowing about them.
    preferences: z.record(z.unknown()).optional(),
  })
  .strict();

export type PatchMeBody = z.infer<typeof patchMeBodySchema>;

/**
 * Slice P5 — body for `POST /api/me/password`. `currentPassword` is
 * capped at 128 chars (the same ceiling we apply to login) so a caller
 * can't use this endpoint as a bcrypt DoS vector. `newPassword` matches
 * the signup rule (min 12, max 128). Both length checks are duplicated
 * in `user.service.changePassword` so the service boundary holds the
 * invariant even if a caller bypasses validation.
 */
export const changePasswordBodySchema = z
  .object({
    currentPassword: z.string().min(1).max(128),
    newPassword: z.string().min(12).max(128),
  })
  .strict();

export type ChangePasswordBody = z.infer<typeof changePasswordBodySchema>;

/**
 * Slice P5 — body for `DELETE /api/me`. Current-password re-verification
 * on the single most destructive endpoint in the API — no path where a
 * stolen access token alone can delete an account.
 */
export const deleteAccountBodySchema = z
  .object({
    currentPassword: z.string().min(1).max(128),
  })
  .strict();

export type DeleteAccountBody = z.infer<typeof deleteAccountBodySchema>;
