import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../database/prisma.service';

@Injectable()
export class AnalyticsScheduler {
  private readonly logger = new Logger(AnalyticsScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron('5 0 * * *', { timeZone: 'UTC' })
  async aggregateYesterday(): Promise<void> {
    const end = new Date();
    end.setUTCHours(0, 0, 0, 0);
    const start = new Date(end);
    start.setUTCDate(start.getUTCDate() - 1);
    await this.aggregateDay(start, end);
  }

  async aggregateDay(start: Date, end: Date): Promise<void> {
    const date = new Date(start);
    date.setUTCHours(0, 0, 0, 0);
    const [activeUsers, signups, friendRequests, messages, revenue] = await Promise.all([
      this.prisma.user.count({ where: { lastActiveAt: { gte: start, lt: end } } }),
      this.prisma.user.count({ where: { createdAt: { gte: start, lt: end } } }),
      this.prisma.friendRequest.count({ where: { status: 'ACCEPTED', updatedAt: { gte: start, lt: end } } }),
      this.prisma.message.count({ where: { createdAt: { gte: start, lt: end } } }),
      this.prisma.subscription
        .findMany({
          where: { status: 'ACTIVE', currentPeriodEnd: { gte: start } },
          include: { plan: true }
        })
        .then((active) => active.reduce((sum, sub) => sum + sub.plan.priceCents, 0))
    ]);
    const cohortStart = new Date(start);
    cohortStart.setUTCDate(cohortStart.getUTCDate() - 7);
    const cohortEnd = new Date(cohortStart);
    cohortEnd.setUTCDate(cohortEnd.getUTCDate() + 1);
    const retainedDay7 = await this.prisma.user.count({
      where: {
        createdAt: { gte: cohortStart, lt: cohortEnd },
        lastActiveAt: { gte: start, lt: end }
      }
    });
    await this.prisma.dailyMetric.upsert({
      where: { date },
      create: { date, activeUsers, signups, matches: 0, friendRequests, messages, revenueCents: revenue, retainedDay7 },
      update: { activeUsers, signups, friendRequests, messages, revenueCents: revenue, retainedDay7 }
    });
    this.logger.log(`Aggregated metrics for ${date.toISOString().slice(0, 10)}`);
  }
}
