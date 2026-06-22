import { Module } from '@nestjs/common';
import { ProfilesController } from './profiles.controller';
import { ProfilesService } from './profiles.service';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
@Module({ imports: [SubscriptionsModule], controllers: [ProfilesController], providers: [ProfilesService], exports: [ProfilesService] })
export class ProfilesModule {}
