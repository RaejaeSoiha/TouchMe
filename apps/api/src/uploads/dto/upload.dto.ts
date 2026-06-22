import { IsIn, IsInt, IsString, Max, Min } from 'class-validator';
export class PresignUploadDto {
  @IsIn(['image/jpeg', 'image/png', 'image/webp', 'audio/aac', 'audio/m4a', 'audio/mpeg']) contentType!: string;
  @IsInt() @Min(1) @Max(15_000_000) contentLength!: number;
  @IsIn(['profile', 'message']) purpose!: 'profile' | 'message';
}
export class CompletePhotoDto { @IsString() storageKey!: string; @IsInt() @Min(0) @Max(8) position!: number; }
export class DirectPhotoUploadDto {
  @IsIn(['image/jpeg', 'image/png', 'image/webp']) contentType!: string;
  @IsInt() @Min(0) @Max(8) position!: number;
  @IsString() imageBase64!: string;
}
