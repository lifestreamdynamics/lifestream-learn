/**
 * NOTE: Do NOT close the module-level prisma/redis singletons from a test
 * file's afterAll. Jest's serial integration runner (`maxWorkers: 1`) runs
 * all test files in one process — closing connections in one file leaves
 * later files with dead handles and BullMQ connection-refused spew.
 *
 * This used to be `closeConnections()`; now it's a no-op kept as a seam so
 * tests don't need to be rewritten when their afterAll calls it. Jest
 * `forceExit: true` (jest.integration.config.js) reaps the connections.
 */
export async function closeConnections(): Promise<void> {
  // no-op by design
}
