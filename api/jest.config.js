/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  roots: ['<rootDir>/src', '<rootDir>/tests/unit'],
  testMatch: ['**/*.test.ts', '**/*.spec.ts'],
  testPathIgnorePatterns: ['/node_modules/', '/dist/', '/tests/integration/'],
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
  },
};
