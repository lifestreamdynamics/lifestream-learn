/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  roots: ['<rootDir>/tests/integration'],
  testMatch: ['**/*.test.ts', '**/*.spec.ts'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '^@tests/(.*)$': '<rootDir>/tests/$1',
  },
  // Slice P7a — otplib and its transitive deps (`@scure/base`,
  // `@noble/hashes@2`) ship ESM-only (`"type": "module"`) builds. Jest
  // defaults to NOT transforming node_modules; we opt those packages
  // into a babel-jest transform that downlevels their ESM source to
  // CJS so the existing Jest classic runtime can load them. Mirrors
  // jest.config.js (unit suite).
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
  setupFiles: ['<rootDir>/tests/integration/env.ts'],
  globalSetup: '<rootDir>/tests/integration/global-setup.ts',
  // Module singletons (prisma, shared ioredis, BullMQ queue) live for the
  // whole serial run. We force-exit so jest doesn't wait for them to close
  // themselves after the last test's afterAll — Node's process exit will
  // reap them. detectOpenHandles helps catch new leaks when they appear.
  forceExit: true,
  testTimeout: 90000,
  maxWorkers: 1,
  // Integration coverage targets app wiring, route composition, and end-to-end
  // auth flow. Pure utilities (jwt, errors, password, validators) and unit-
  // specific service/controller branches are covered by jest.config.js.
  collectCoverageFrom: [
    'src/app.ts',
    'src/routes/**/*.ts',
    'src/controllers/**/*.ts',
    'src/services/**/*.ts',
    'src/queues/**/*.ts',
    '!src/**/*.d.ts',
  ],
  coverageThreshold: {
    global: {
      branches: 40,
      functions: 85,
      lines: 85,
      statements: 85,
    },
  },
};
