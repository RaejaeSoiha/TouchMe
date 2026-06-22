import { Inject, Injectable } from '@nestjs/common';
import Redis from 'ioredis';
import { PrismaService } from '../database/prisma.service';
import { REDIS } from '../redis/redis.module';

export interface PresenceInfo {
  online: boolean;
  lastActiveAt: Date;
}

@Injectable()
export class PresenceService {
  private static countKey(userId: string) {
    return `presence:count:${userId}`;
  }

  private static touchKey(userId: string) {
    return `presence:touched:${userId}`;
  }

  constructor(
    @Inject(REDIS) private readonly redis: Redis,
    private readonly prisma: PrismaService,
  ) {}

  async markOnline(userId: string): Promise<PresenceInfo> {
    const count = await this.redis.incr(PresenceService.countKey(userId));
    const lastActiveAt = await this.updateLastActive(userId, count === 1);
    return { online: true, lastActiveAt };
  }

  async markOffline(userId: string): Promise<PresenceInfo> {
    const count = await this.redis.decr(PresenceService.countKey(userId));
    if (count <= 0) {
      await this.redis.del(PresenceService.countKey(userId));
      const lastActiveAt = await this.updateLastActive(userId, true);
      return { online: false, lastActiveAt };
    }
    const lastActiveAt = await this.touch(userId);
    return { online: true, lastActiveAt };
  }

  async heartbeat(userId: string): Promise<PresenceInfo> {
    const count = await this.redis.get(PresenceService.countKey(userId));
    if (count === null || parseInt(count, 10) <= 0) {
      await this.redis.incr(PresenceService.countKey(userId));
    }
    const lastActiveAt = await this.touch(userId);
    return { online: true, lastActiveAt };
  }

  async snapshot(userIds: string[]): Promise<Map<string, PresenceInfo>> {
    const map = new Map<string, PresenceInfo>();
    if (!userIds.length) return map;

    const pipeline = this.redis.pipeline();
    for (const id of userIds) pipeline.get(PresenceService.countKey(id));
    const results = await pipeline.exec();

    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, lastActiveAt: true },
    });
    const activeById = new Map(users.map((user) => [user.id, user.lastActiveAt]));

    userIds.forEach((id, index) => {
      const countRaw = results?.[index]?.[1] as string | null;
      const online = countRaw !== null && parseInt(countRaw, 10) > 0;
      map.set(id, {
        online,
        lastActiveAt: activeById.get(id) ?? new Date(0),
      });
    });
    return map;
  }

  private async updateLastActive(userId: string, force: boolean): Promise<Date> {
    if (force) {
      const now = new Date();
      await this.prisma.user.update({ where: { id: userId }, data: { lastActiveAt: now } });
      return now;
    }
    return this.touch(userId);
  }

  private async touch(userId: string): Promise<Date> {
    const throttled = await this.redis.set(
      PresenceService.touchKey(userId),
      '1',
      'EX',
      60,
      'NX',
    );
    if (throttled === 'OK') {
      const now = new Date();
      await this.prisma.user.update({ where: { id: userId }, data: { lastActiveAt: now } });
      return now;
    }
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { lastActiveAt: true },
    });
    return user.lastActiveAt;
  }
}
