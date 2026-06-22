import { PrismaClient, UserRole, UserStatus } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import * as argon2 from 'argon2';

const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL! }) });
const interests = ['Art', 'Books', 'Cooking', 'Cycling', 'Dancing', 'Fitness', 'Gaming', 'Hiking', 'Movies', 'Music', 'Photography', 'Travel', 'Volunteering', 'Yoga'];

async function main() {
  await Promise.all(
    interests.map((label) =>
      prisma.interest.upsert({
        where: { slug: label.toLowerCase() },
        update: { label, active: true },
        create: { slug: label.toLowerCase(), label },
      }),
    ),
  );

  await prisma.plan.upsert({
    where: { code: 'touchme_plus_monthly' },
    update: { name: 'TouchMe Plus' },
    create: {
      code: 'touchme_plus_monthly',
      name: 'TouchMe Plus',
      stripePriceId: process.env.STRIPE_PREMIUM_PRICE_ID ?? 'price_development_touchme_plus',
      priceCents: 1999,
      currency: 'usd',
      interval: 'month',
      unlimitedLikes: true,
      passportMode: true,
      monthlyBoosts: 1,
    },
  });

  const adminEmail = process.env.SEED_ADMIN_EMAIL ?? 'admin@touchme.local';
  const adminPassword = process.env.SEED_ADMIN_PASSWORD;
  if (adminPassword) {
    const passwordHash = await argon2.hash(adminPassword);
    await prisma.user.upsert({
      where: { email: adminEmail },
      update: { passwordHash, role: UserRole.ADMIN, status: UserStatus.ACTIVE },
      create: {
        email: adminEmail,
        passwordHash,
        emailVerifiedAt: new Date(),
        role: UserRole.ADMIN,
        status: UserStatus.ACTIVE,
        profile: {
          create: {
            displayName: 'Admin',
            birthDate: new Date('1990-01-01'),
            gender: 'OTHER',
            showMe: ['WOMAN', 'MAN', 'NON_BINARY', 'OTHER'],
            city: 'Admin',
            completedAt: new Date(),
          },
        },
      },
    });
  }

  const demoPassword = process.env.SEED_DEMO_PASSWORD;
  const demoEmail = process.env.SEED_DEMO_EMAIL ?? 'demo@touchme.local';
  if (demoPassword) {
    const passwordHash = await argon2.hash(demoPassword);
    await prisma.user.upsert({
      where: { email: demoEmail },
      update: { passwordHash, status: UserStatus.ACTIVE },
      create: {
        email: demoEmail,
        passwordHash,
        emailVerifiedAt: new Date(),
        status: UserStatus.ACTIVE,
        profile: {
          create: {
            displayName: 'Demo',
            birthDate: new Date('1995-06-15'),
            gender: 'NON_BINARY',
            showMe: ['WOMAN', 'MAN', 'NON_BINARY', 'OTHER'],
            bio: 'Trying TouchMe — say hi!',
            city: 'Denver',
            countryCode: 'US',
            latitude: 39.7392,
            longitude: -104.9903,
            completedAt: new Date(),
          },
        },
      },
    });

    // Legacy demo account (kept for existing installs)
    await prisma.user.upsert({
      where: { email: 'demo@nearbyconnect.local' },
      update: { passwordHash, status: UserStatus.ACTIVE },
      create: {
        email: 'demo@nearbyconnect.local',
        passwordHash,
        emailVerifiedAt: new Date(),
        status: UserStatus.ACTIVE,
        profile: {
          create: {
            displayName: 'Demo',
            birthDate: new Date('1995-06-15'),
            gender: 'NON_BINARY',
            showMe: ['WOMAN', 'MAN', 'NON_BINARY', 'OTHER'],
            bio: 'Trying TouchMe — say hi!',
            city: 'Denver',
            countryCode: 'US',
            latitude: 39.7392,
            longitude: -104.9903,
            completedAt: new Date(),
          },
        },
      },
    });
  }

  const seedUsers = [
    {
      email: 'alex@touchme.local',
      displayName: 'Alex',
      gender: 'MAN' as const,
      city: 'Phoenix',
      latitude: 33.4484,
      longitude: -112.074,
      bio: 'Coffee, hiking, and meeting new people nearby.',
    },
    {
      email: 'sam@touchme.local',
      displayName: 'Sam',
      gender: 'WOMAN' as const,
      city: 'Austin',
      latitude: 30.2672,
      longitude: -97.7431,
      bio: 'Music lover looking for friends in the area.',
    },
  ];

  if (demoPassword) {
    const passwordHash = await argon2.hash(demoPassword);
    for (const user of seedUsers) {
      await prisma.user.upsert({
        where: { email: user.email },
        update: { status: UserStatus.ACTIVE },
        create: {
          email: user.email,
          passwordHash,
          emailVerifiedAt: new Date(),
          status: UserStatus.ACTIVE,
          profile: {
            create: {
              displayName: user.displayName,
              birthDate: new Date('1998-03-20'),
              gender: user.gender,
              showMe: ['WOMAN', 'MAN', 'NON_BINARY', 'OTHER'],
              bio: user.bio,
              city: user.city,
              countryCode: 'US',
              latitude: user.latitude,
              longitude: user.longitude,
              completedAt: new Date(),
            },
          },
        },
      });
    }
  }
}

main().finally(async () => prisma.$disconnect());
