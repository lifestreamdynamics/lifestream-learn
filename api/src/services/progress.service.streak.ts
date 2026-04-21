/**
 * Slice P3 — streak computation helpers, extracted into their own
 * module so both `progress.service.ts` (for the overall-progress
 * summary) and `achievement.service.ts` (for `type: "streak"` criteria)
 * can import without a circular dependency.
 *
 * The helpers are pure — no Prisma, no Redis. Callers pull event rows
 * and user preferences on their end, then fold them through
 * `computeStreakFromEvents`. See `CLAUDE.md` on why we use
 * `AnalyticsEvent.occurredAt` (client-sourced wall-clock) rather than
 * `receivedAt` (server): streaks are about the learner's day, not the
 * server's.
 */

export interface StreakResult {
  currentStreak: number;
  longestStreak: number;
}

/**
 * Collapse a list of event timestamps into `{ currentStreak,
 * longestStreak }` counted in the learner's local timezone.
 *
 *  - A "day" is the integer floor of `(utcMs + offsetMs) / 86_400_000`,
 *    so arithmetic stays trivial (ordering is all we need).
 *  - `currentStreak` includes a grace day — streaks ending "yesterday"
 *    still count so a learner opening the app at 2am on day N+1 doesn't
 *    see their counter reset just because they haven't acted *today*
 *    yet.
 *  - `longestStreak` is the longest run in the full event history.
 *
 * `nowMs` is injectable for unit tests so "today" can be pinned.
 */
export function computeStreakFromEvents(
  eventDates: Date[],
  opts: { timezoneOffsetMinutes: number; nowMs?: number },
): StreakResult {
  if (eventDates.length === 0) return { currentStreak: 0, longestStreak: 0 };
  const offsetMs = opts.timezoneOffsetMinutes * 60 * 1000;
  const now = opts.nowMs ?? Date.now();

  const dayIndex = (ms: number): number =>
    Math.floor((ms + offsetMs) / 86_400_000);

  const days = new Set<number>();
  for (const d of eventDates) {
    days.add(dayIndex(d.getTime()));
  }
  const sorted = Array.from(days).sort((a, b) => b - a);
  const todayLocal = dayIndex(now);

  let currentStreak = 0;
  if (days.has(todayLocal)) {
    let cursor = todayLocal;
    while (days.has(cursor)) {
      currentStreak += 1;
      cursor -= 1;
    }
  } else if (days.has(todayLocal - 1)) {
    let cursor = todayLocal - 1;
    while (days.has(cursor)) {
      currentStreak += 1;
      cursor -= 1;
    }
  }

  let longestStreak = 0;
  let runLen = 0;
  for (let i = 0; i < sorted.length; i += 1) {
    if (i === 0 || sorted[i - 1] - sorted[i] === 1) {
      runLen += 1;
    } else {
      runLen = 1;
    }
    if (runLen > longestStreak) longestStreak = runLen;
  }

  return { currentStreak, longestStreak };
}

/**
 * Extract the learner's timezone offset (minutes East of UTC) from
 * `user.preferences.timezoneOffsetMinutes`. Defaults to 0 (UTC) when
 * the slot is missing or malformed. The Flutter app patches this on
 * first profile load.
 */
export function timezoneOffsetFromPreferences(prefs: unknown): number {
  if (prefs === null || typeof prefs !== 'object') return 0;
  const v = (prefs as Record<string, unknown>).timezoneOffsetMinutes;
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  return 0;
}
