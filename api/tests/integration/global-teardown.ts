/**
 * Jest globalTeardown — runs once after the full integration suite.
 * Individual test files must NOT call prisma.$disconnect()/redis.quit() in
 * their own afterAll because the singletons are shared across test files
 * (jest --maxWorkers=1 runs files serially in ONE process). Closing them
 * mid-suite leaves later files with quit connections and BullMQ errors.
 *
 * Node.js process exit will eventually close the connections naturally,
 * but we do it explicitly so jest's open-handle detection stays happy.
 */
export default async function globalTeardown(): Promise<void> {
  // Nothing to do — connections are closed by the normal process exit
  // hook. Kept as a documented seam in case we need it later.
}
