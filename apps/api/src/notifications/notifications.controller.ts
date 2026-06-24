import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Patch, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser } from '../common/auth-user';
import { RegisterDeviceDto } from './dto/device.dto';
import { NotificationsService } from './notifications.service';
@ApiTags('notifications') @Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}
  @Post('devices') register(@CurrentUser() user: AuthUser, @Body() dto: RegisterDeviceDto) { return this.notifications.register(user.id, dto.platform, dto.pushToken); }
  @Delete('devices') @HttpCode(HttpStatus.NO_CONTENT) unregister(@CurrentUser() user: AuthUser) { return this.notifications.deactivateAll(user.id); }
  @Get() list(@CurrentUser() user: AuthUser) { return this.notifications.list(user.id); }
  @Patch(':id/read') @HttpCode(HttpStatus.NO_CONTENT) read(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.notifications.markRead(user.id, id); }
}

