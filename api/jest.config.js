/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  roots: ['<rootDir>/src', '<rootDir>/tests/unit'],
  testMatch: ['**/*.test.ts', '**/*.spec.ts'],
  testPathIgnorePatterns: ['/node_modules/', '/dist/', '/tests/integration/'],
  // Slice P7a — `otplib` (and its `@scure/base` dep) ship ESM-only
  // builds. Jest defaults to NOT transforming node_modules, which
  // means `import { ... } from '@scure/base'` lands as raw `export`
  // syntax inside a CommonJS context and blows up at parse time.
  // We opt those packages INTO a plain babel-jest transform (ts-jest
  // only handles .ts). Keep this list tight — every entry widens the
  // transform surface area and slows test warm-up.
  transform: {
    '^.+\\.tsx?$': ['ts-jest', {}],
    '^.+\\.(m?jsx?)$': [
      'babel-jest',
      { presets: [['@babel/preset-env', { targets: { node: 'current' } }]] },
    ],
  },
  transformIgnorePatterns: [
    '/node_modules/(?!(otplib|@otplib|@scure|@noble)/)',
  ],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '^@tests/(.*)$': '<rootDir>/tests/$1',
  },
  setupFiles: ['<rootDir>/tests/unit/setup.ts'],
  // Unit coverage scope: middleware, auth layer, Phase-3 pure/near-pure
  // modules (ffmpeg arg building, ladder selection, content types, hls
  // signer, validators). Stateful wiring (Prisma + Redis + S3 + Bull) and
  // the worker entry process are exercised by the integration suite.
  collectCoverageFrom: [
    'src/middleware/**/*.ts',
    'src/controllers/**/*.ts',
    'src/services/auth.service.ts',
    'src/services/video.service.ts',
    'src/services/cue.service.ts',
    'src/services/attempt.service.ts',
    'src/services/progress.service.ts',
    'src/services/progress.service.streak.ts',
    'src/services/achievement.service.ts',
    'src/services/grading/**/*.ts',
    'src/services/ffmpeg/**/*.ts',
    'src/services/object-store.ts',
    'src/validators/**/*.ts',
    'src/utils/jwt.ts',
    'src/utils/password.ts',
    'src/utils/errors.ts',
    'src/utils/hls-signer.ts',
    'src/utils/content-type.ts',
    'src/utils/tmp-dir.ts',
    'src/workers/transcode.pipeline.ts',
    'src/routes/health.routes.ts',
    '!src/**/*.d.ts',
  ],
  coverageDirectory: 'coverage',
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 80,
      lines: 80,
      statements: 80,
    },
    // Grading logic is security-sensitive (CLAUDE.md: "a wrong correct/
    // incorrect leaks the answer or miscredits a learner"). Enforce ≥95%
    // on branches/lines/functions/statements for this subtree.
    'src/services/grading/**/*.ts': {
      branches: 95,
      functions: 95,
      lines: 95,
      statements: 95,
    },
    // Slice P2 — progress aggregation is grading-adjacent: grade letters
    // and accuracy are computed from `Attempt.correct`, so a regression
    // here mis-credits a learner. Hold to the same ≥95% bar as grading.
    'src/services/progress.service.ts': {
      branches: 90,
      functions: 95,
      lines: 95,
      statements: 95,
    },
    // Slice P3 — achievement unlock evaluator. Miscredit here equals a
    // reward the learner didn't earn (or worse, a silently-missed
    // unlock). Same 95% bar as grading/progress.
    'src/services/achievement.service.ts': {
      branches: 90,
      functions: 95,
      lines: 95,
      statements: 95,
    },
    // Streak helper is pure arithmetic but shared between progress +
    // achievement services — same bar.
    'src/services/progress.service.streak.ts': {
      branches: 90,
      functions: 95,
      lines: 95,
      statements: 95,
    },
  },
};
