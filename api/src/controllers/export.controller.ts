/**
 * @openapi
 * tags:
 *   name: Export
 *   description: GDPR "right of access" personal-data export.
 */
import type { Request, Response } from 'express';
import { exportService } from '@/services/export.service';
import { prisma } from '@/config/prisma';
import { NotFoundError, UnauthorizedError } from '@/utils/errors';

/**
 * @openapi
 * /api/me/export:
 *   get:
 *     tags: [Export]
 *     summary: Download a JSON export of the caller's personal data.
 *     description: |
 *       Returns a typed JSON document of everything we hold about the
 *       caller. Matches the GDPR "right of access" posture: credentials
 *       (password hash, TOTP secret, backup-code hashes, WebAuthn
 *       public-key material) are intentionally excluded; courses the
 *       user authored are NOT included (separately copyrightable — only
 *       a count pointer is returned).
 *
 *       Analytics events are capped at 10,000 rows most-recent first;
 *       the `analyticsEventsTruncated` flag indicates whether the
 *       payload was truncated. Schema is versioned via `schemaVersion`.
 *
 *       Rate-limited at 1 request per 24 hours per user (not per IP)
 *       to bound the DB load a single caller can impose. Soft-deleted
 *       users are rejected with 403 — the GDPR "right of erasure"
 *       supersedes "right of access" once deletion is requested. If the
 *       user wants an export, they must do it BEFORE deleting.
 *
 *       Response headers:
 *         - `Content-Type: application/json`
 *         - `Content-Disposition: attachment; filename="..."` so the
 *           browser saves rather than renders inline.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: Full JSON export payload. }
 *       401: { description: Unauthenticated. }
 *       403: { description: Account is soft-deleted. }
 *       429:
 *         description: Rate limited (1 export per 24 hours per user).
 *         headers:
 *           Retry-After:
 *             schema: { type: integer }
 *             description: Seconds until next allowed request.
 */
export async function exportMyData(req: Request, res: Response): Promise<void> {
  if (!req.user) throw new UnauthorizedError('Not authenticated');

  // Gate: reject soft-deleted users. We re-check the DB state rather
  // than trusting the access token alone because the token can be up to
  // 15 minutes old; a user who soft-deleted moments ago should not be
  // able to slip an export through that grace window.
  //
  // We return 403 (not 401) because the credentials ARE valid — the
  // account itself is in a state that forbids this action. Clients
  // treat 401 as "re-login" which would be wrong here.
  const row = await prisma.user.findUnique({
    where: { id: req.user.id },
    select: { deletedAt: true },
  });
  if (!row) throw new NotFoundError('User not found');
  if (row.deletedAt != null) {
    res.status(403).json({
      error: 'ACCOUNT_DELETED',
      message:
        'Account is pending deletion; export is no longer available. ' +
        'Data export must be performed before requesting deletion.',
    });
    return;
  }

  const payload = await exportService.exportUserData(req.user.id);

  // `Content-Disposition: attachment; filename="..."` is the long-
  // standing way to tell a user-agent (browser or share-sheet target)
  // to save the response as a file rather than render it. The filename
  // includes the user id + the export date so the user can keep
  // multiple exports side-by-side without clobbering.
  const isoDate = payload.exportedAt.slice(0, 10); // YYYY-MM-DD
  const filename = `lifestream-learn-export-${req.user.id}-${isoDate}.json`;

  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="${filename}"`,
  );
  // Exports contain every analytics event and attempt the user has
  // made. Mark no-cache so a shared cache doesn't retain a second copy
  // with weaker access controls than our authenticated endpoint.
  res.setHeader('Cache-Control', 'no-store');

  res.status(200).json(payload);
}
