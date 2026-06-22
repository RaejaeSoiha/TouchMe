import { Body, Controller, Delete, Get, Param, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser } from '../common/auth-user';
import { SendFriendRequestDto } from './dto/friends.dto';
import { FriendsService } from './friends.service';

@ApiTags('friends')
@Controller('friends')
export class FriendsController {
  constructor(private readonly friends: FriendsService) {}

  @Get() list(@CurrentUser() user: AuthUser) {
    return this.friends.listFriends(user.id);
  }

  @Get('requests') requests(@CurrentUser() user: AuthUser) {
    return this.friends.listRequests(user.id);
  }

  @Post('requests') send(@CurrentUser() user: AuthUser, @Body() dto: SendFriendRequestDto) {
    return this.friends.sendRequest(user.id, dto.userId);
  }

  @Post('requests/:requestId/accept') accept(@CurrentUser() user: AuthUser, @Param('requestId') requestId: string) {
    return this.friends.acceptRequest(user.id, requestId);
  }

  @Post('requests/:requestId/reject') reject(@CurrentUser() user: AuthUser, @Param('requestId') requestId: string) {
    return this.friends.rejectRequest(user.id, requestId);
  }

  @Delete(':userId') remove(@CurrentUser() user: AuthUser, @Param('userId') userId: string) {
    return this.friends.removeFriend(user.id, userId);
  }
}
