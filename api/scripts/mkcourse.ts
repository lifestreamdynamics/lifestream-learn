import { prisma } from '@/config/prisma';

async function main(): Promise<void> {
  const admin = await prisma.user.findUniqueOrThrow({
    where: { email: 'admin@example.local' },
  });
  const course = await prisma.course.create({
    data: {
      slug: `smoke-${Date.now()}`,
      title: 'Smoke',
      description: 'smoke',
      ownerId: admin.id,
    },
  });
  // eslint-disable-next-line no-console
  console.log(course.id);
}

main()
  .then(() => prisma.$disconnect().then(() => process.exit(0)))
  .catch(async (err) => {
    // eslint-disable-next-line no-console
    console.error(err);
    await prisma.$disconnect();
    process.exit(1);
  });
