import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser } from '../common/auth-user';
import { CreateConversationDto } from './dto/conversation.dto';
import { ConversationsService } from './conversations.service';

@ApiTags('conversations')
@Controller('conversations')
export class ConversationsController {
  constructor(private readonly conversations: ConversationsService) {}

  @Get() list(@CurrentUser() user: AuthUser) {
    return this.conversations.list(user.id);
  }

  @Post() open(@CurrentUser() user: AuthUser, @Body() dto: CreateConversationDto) {
    return this.conversations.getOrCreate(user.id, dto.userId);
  }

  @Get(':conversationId') get(
    @CurrentUser() user: AuthUser,
    @Param('conversationId') conversationId: string,
  ) {
    return this.conversations.assertMember(user.id, conversationId).then(() =>
      this.conversations.list(user.id).then((items) => items.find((item) => item.id === conversationId)),
    );
  }
}
