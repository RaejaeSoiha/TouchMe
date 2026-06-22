import { Body, Controller, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser } from '../common/auth-user';
import { CompletePhotoDto, DirectPhotoUploadDto, PresignUploadDto } from './dto/upload.dto';
import { UploadsService } from './uploads.service';
@ApiTags('uploads') @Controller('uploads')
export class UploadsController {
  constructor(private readonly uploads: UploadsService) {}
  @Post('presign') presign(@CurrentUser() user: AuthUser, @Body() dto: PresignUploadDto) { return this.uploads.presign(user.id, dto.contentType, dto.contentLength, dto.purpose); }
  @Post('photos/complete') complete(@CurrentUser() user: AuthUser, @Body() dto: CompletePhotoDto) { return this.uploads.completePhoto(user.id, dto.storageKey, dto.position); }
  @Post('photos/direct') direct(@CurrentUser() user: AuthUser, @Body() dto: DirectPhotoUploadDto) {
    return this.uploads.uploadProfilePhotoDirect(user.id, dto.contentType, dto.position, Buffer.from(dto.imageBase64, 'base64'));
  }
}

