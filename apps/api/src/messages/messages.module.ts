import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';
import { MessagesController } from './messages.controller';
import { MessagesGateway } from './messages.gateway';
import { MessagesService } from './messages.service';

@Module({
  imports: [AuthModule, NotificationsModule],
  controllers: [ConversationsController, MessagesController],
  providers: [ConversationsService, MessagesService, MessagesGateway],
  exports: [ConversationsService, MessagesService, MessagesGateway],
})
export class MessagesModule {}
