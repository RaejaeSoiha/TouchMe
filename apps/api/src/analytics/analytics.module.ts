import { Module } from '@nestjs/common';
import { AnalyticsScheduler } from './analytics.scheduler';
import { AnalyticsService } from './analytics.service';

@Module({
  providers: [AnalyticsService, AnalyticsScheduler],
  exports: [AnalyticsService]
})
export class AnalyticsModule {}

