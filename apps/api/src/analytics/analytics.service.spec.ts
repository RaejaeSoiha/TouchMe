import { Test } from '@nestjs/testing';
import { AnalyticsService } from './analytics.service';
import { PrismaService } from '../database/prisma.service';

describe('AnalyticsService', () => {
  let service: AnalyticsService;
  const prisma = {
    user: { count: jest.fn() },
    friendRequest: { count: jest.fn() },
    message: { count: jest.fn() },
    subscription: { count: jest.fn() },
    dailyMetric: { findMany: jest.fn() },
  };

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [AnalyticsService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = module.get(AnalyticsService);
    jest.clearAllMocks();
    prisma.user.count.mockResolvedValue(10);
    prisma.friendRequest.count.mockResolvedValue(3);
    prisma.message.count.mockResolvedValue(50);
    prisma.subscription.count.mockResolvedValue(2);
    prisma.dailyMetric.findMany.mockResolvedValue([]);
  });

  it('returns dashboard aggregates', async () => {
    const result = await service.dashboard(7);
    expect(result.users).toBe(10);
    expect(result.activeUsers).toBe(10);
    expect(result.friendRequests).toBe(3);
    expect(result.messages).toBe(50);
    expect(result.activeSubscriptions).toBe(2);
    expect(result.metrics).toEqual([]);
  });
});
