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
  setupFiles: ['<rootDir>/tests/integration/env.ts'],
  globalSetup: '<rootDir>/tests/integration/global-setup.ts',
  testTimeout: 30000,
  maxWorkers: 1,
  // Integration coverage targets app wiring, route composition, and end-to-end
  // auth flow. Pure utilities (jwt, errors, password, validators) and unit-
  // specific service/controller branches are covered by jest.config.js.
  collectCoverageFrom: [
    'src/app.ts',
    'src/routes/**/*.ts',
    'src/controllers/**/*.ts',
    'src/services/**/*.ts',
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
