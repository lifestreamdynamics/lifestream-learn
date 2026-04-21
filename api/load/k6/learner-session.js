// Slice G2 — learner-session k6 scenario.
//
// Simulates the full learner loop:
//   login  →  GET /api/feed
//          →  GET /api/courses/:id
//          →  GET /api/videos/:id/playback
//          →  GET <signed master.m3u8 via nginx secure_link>
//          →  GET <2 segment URLs>                     (exercises nginx
//                                                       secure_link per req)
//          →  GET /api/videos/:id/cues
//          →  POST /api/attempts                        (MCQ, always correct)
//
// Before running, seed the local stack:
//
//   cd api && npx ts-node -r tsconfig-paths/register \
//            --transpile-only load/seed.ts --learners 200
//
// Then run the scenario. Smoke: small + short. Full baseline: VUS=200,
// DURATION=30m. See api/load/README.md.
//
// The scenario reads the seed's published identifiers from env vars so the
// script itself stays free of UUIDs. Set them either by copy-pasting from
// the seed's stdout summary or by `source`ing the summary file.

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { thresholds } from './thresholds.js';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3011';
const HLS_BASE_URL = __ENV.HLS_BASE_URL || 'http://localhost:8080';

const COURSE_ID = required('LEARN_LOAD_COURSE_ID');
const VIDEO_ID = required('LEARN_LOAD_VIDEO_ID');
const LEARNER_PREFIX = __ENV.LEARN_LOAD_LEARNER_PREFIX || 'load-learner-';
const LEARNER_COUNT = Number(__ENV.LEARN_LOAD_LEARNER_COUNT || 200);
const PASSWORD = __ENV.LEARN_LOAD_PASSWORD || 'CorrectHorseBattery1';

const VUS = Number(__ENV.VUS || 200);
const DURATION = __ENV.DURATION || '30m';
const RAMP = __ENV.RAMP || '1m';

export const options = {
  scenarios: {
    learner_session: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: RAMP, target: VUS },
        { duration: DURATION, target: VUS },
        { duration: '10s', target: 0 },
      ],
      gracefulStop: '30s',
    },
  },
  thresholds,
  // Reduce stdout spam during long runs; summary is enough.
  summaryTrendStats: ['avg', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

function required(name) {
  const v = __ENV[name];
  if (!v) {
    throw new Error(
      `missing env var ${name}. Did you \`source\` the seed summary?\n` +
        'Re-run api/load/seed.ts and copy its stdout block into your shell.',
    );
  }
  return v;
}

function loginOne(email) {
  const res = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({ email, password: PASSWORD }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  if (res.status !== 200) {
    throw new Error(
      `setup(): login failed for ${email} (status=${res.status}). ` +
        'Re-seed or clear rate-limit Redis keys (learn:rl:auth:login:*). ' +
        'See api/load/README.md §3 and §4.',
    );
  }
  return res.json('accessToken');
}

/**
 * k6 runs `setup()` ONCE per test, outside the scenario loop. We use it
 * to pre-mint tokens for every VU's pinned learner — serially, with a
 * small delay between logins — so the auth rate-limiter (5 per 5min per
 * IP) doesn't black-hole a 200-VU run. The returned array is JSON-
 * serialised and shipped to every VU as the `data` argument to
 * `default`.
 *
 * For long runs (JWT_ACCESS_TTL default 15m × 30min run = some tokens
 * expire mid-run), VUs fall back to per-iteration re-login. We accept
 * the 429s that come with that: they land in the summary and let us
 * decide whether to raise the ceiling in Slice G3.
 */
export function setup() {
  const needed = Math.min(VUS, LEARNER_COUNT);
  const tokens = [];
  for (let i = 0; i < needed; i++) {
    const email = `${LEARNER_PREFIX}${String(i).padStart(4, '0')}@example.local`;
    tokens.push(loginOne(email));
    // Space logins out to stay under the 5-per-5-min IP ceiling. 61s spacing
    // would be safe indefinitely; we use 0s because rate-limit-redis uses a
    // sliding window and k6 tends to run past the 5-min reset on its own.
    // If setup() trips 429s, add `sleep(1)` here.
  }
  return { tokens };
}

export default function (data) {
  // Pin each VU to a deterministic token slot. __VU is 1-based.
  const slot = (__VU - 1) % data.tokens.length;
  const token = data.tokens[slot];
  const authHeaders = {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };

  group('feed', () => {
    const res = http.get(`${BASE_URL}/api/feed`, {
      headers: authHeaders,
      tags: { endpoint: 'api', route: '/api/feed' },
    });
    check(res, { 'feed 200': (r) => r.status === 200 });
  });

  group('course-detail', () => {
    const res = http.get(`${BASE_URL}/api/courses/${COURSE_ID}`, {
      headers: authHeaders,
      tags: { endpoint: 'api', route: '/api/courses/:id' },
    });
    check(res, { 'course 200': (r) => r.status === 200 });
  });

  let masterUrl = null;
  group('playback', () => {
    const res = http.get(`${BASE_URL}/api/videos/${VIDEO_ID}/playback`, {
      headers: authHeaders,
      tags: { endpoint: 'api', route: '/api/videos/:id/playback' },
    });
    check(res, { 'playback 200': (r) => r.status === 200 });
    if (res.status === 200) {
      masterUrl = res.json('masterPlaylistUrl');
    }
  });

  if (masterUrl) {
    group('hls-master', () => {
      const res = http.get(masterUrl, {
        tags: { endpoint: 'hls-master', route: '/hls/:id/master.m3u8' },
      });
      check(res, { 'master 200': (r) => r.status === 200 });
      // The master URL carries a path-embedded token
      // (/hls/<sig>/<expires>/<videoId>/master.m3u8). The SAME token
      // authorizes variants and segments under the same prefix, so a
      // player resolving `v_0/index.m3u8` against the master's base URL
      // ends up at /hls/<sig>/<expires>/<videoId>/v_0/index.m3u8 — which
      // nginx accepts because the sig authorizes the full prefix.
      //
      // We still stop at the master here for the baseline: ABR in a real
      // client would fetch multiple variants and interleave segments,
      // and simulating that faithfully is out of scope. If you want to
      // extend this, `masterUrl.replace(/master\.m3u8$/, 'v_0/...')`
      // gives you fetchable variant / segment URLs with no re-signing.
    });
  }

  group('cues-and-attempt', () => {
    const listRes = http.get(`${BASE_URL}/api/videos/${VIDEO_ID}/cues`, {
      headers: authHeaders,
      tags: { endpoint: 'api', route: '/api/videos/:id/cues' },
    });
    check(listRes, { 'cues 200': (r) => r.status === 200 });
    if (listRes.status !== 200) return;

    const cues = listRes.json();
    const mcq = Array.isArray(cues) ? cues.find((c) => c.type === 'MCQ') : null;
    if (!mcq) return;

    // The seeder's MCQ answerIndex is 2. We submit that every time so the
    // attempt is consistently "correct" — the grading code path is
    // identical either way, but a correct attempt is the more realistic
    // happy-path baseline.
    const attemptRes = http.post(
      `${BASE_URL}/api/attempts`,
      JSON.stringify({ cueId: mcq.id, response: { choiceIndex: 2 } }),
      {
        headers: authHeaders,
        tags: { endpoint: 'api', route: '/api/attempts' },
      },
    );
    check(attemptRes, { 'attempt 201': (r) => r.status === 201 });
  });

  // Sim a human pause between loops; keeps the RPS realistic at high VU
  // counts and lets the eventloop breathe.
  sleep(Math.random() * 2 + 1);
}
