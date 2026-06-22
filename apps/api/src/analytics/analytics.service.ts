import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}
  async dashboard(days = 30) {
    const since = new Date(Date.now() - days * 86400000);
    const [users, activeUsers, friendRequests, messages, subscriptions, metrics] = await Promise.all([
      this.prisma.user.count(), this.prisma.user.count({ where: { lastActiveAt: { gte: since } } }),
      this.prisma.friendRequest.count({ where: { status: 'ACCEPTED', updatedAt: { gte: since } } }),
      this.prisma.message.count({ where: { createdAt: { gte: since } } }),
      this.prisma.subscription.count({ where: { status: 'ACTIVE' } }), this.prisma.dailyMetric.findMany({ where: { date: { gte: since } }, orderBy: { date: 'asc' } })
    ]);
    return { users, activeUsers, friendRequests, messages, activeSubscriptions: subscriptions, metrics };
  }
}

