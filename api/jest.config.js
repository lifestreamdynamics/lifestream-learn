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
  // Unit coverage targets the Phase-2 exit-criterion scope: middleware + auth.
  // Infra wiring (config/*, routes/index.ts, route stubs, services that touch
  // Prisma) is exercised by the integration suite — jest.integration.config.js
  // runs against a real DB + Redis + SeaweedFS and enforces its own thresholds.
  collectCoverageFrom: [
    'src/middleware/**/*.ts',
    'src/controllers/auth.controller.ts',
    'src/services/auth.service.ts',
    'src/validators/auth.validators.ts',
    'src/utils/jwt.ts',
    'src/utils/password.ts',
    'src/utils/errors.ts',
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
