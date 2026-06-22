import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Patch, Put } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser, Public } from '../common/auth-user';
import { PassportLocationDto, ReorderPhotosDto, UpdateLocationDto, UpsertProfileDto } from './dto/profile.dto';
import { ProfilesService } from './profiles.service';

@ApiTags('profiles')
@Controller('profiles')
export class ProfilesController {
  constructor(private readonly profiles: ProfilesService) {}
  @Get('me') me(@CurrentUser() user: AuthUser) { return this.profiles.me(user.id); }
  @Put('me') upsert(@CurrentUser() user: AuthUser, @Body() dto: UpsertProfileDto) { return this.profiles.upsert(user.id, dto); }
  @Patch('me/location') location(@CurrentUser() user: AuthUser, @Body() dto: UpdateLocationDto) { return this.profiles.updateLocation(user.id, dto.latitude, dto.longitude); }
  @Patch('me/passport') passport(@CurrentUser() user: AuthUser, @Body() dto: PassportLocationDto) { return this.profiles.passport(user.id, dto.latitude, dto.longitude); }
  @Patch('me/photos/order') reorder(@CurrentUser() user: AuthUser, @Body() dto: ReorderPhotosDto) { return this.profiles.reorderPhotos(user.id, dto.photoIds); }
  @Delete('me/photos/:photoId') @HttpCode(HttpStatus.NO_CONTENT) removePhoto(@CurrentUser() user: AuthUser, @Param('photoId') photoId: string) { return this.profiles.removePhoto(user.id, photoId); }
  @Public() @Get('interests') interests() { return this.profiles.interests(); }
}
