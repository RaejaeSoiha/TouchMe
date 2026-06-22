import { Module } from '@nestjs/common';
import { AnalyticsModule } from '../analytics/analytics.module';
import { SafetyModule } from '../safety/safety.module';
import { AdminController } from './admin.controller';
@Module({ imports: [SafetyModule, AnalyticsModule], controllers: [AdminController] }) export class AdminModule {}

