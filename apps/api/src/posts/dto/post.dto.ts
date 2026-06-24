import { IsBoolean, IsEnum, IsOptional, IsString, IsUrl, MaxLength } from 'class-validator';
import { PostVisibility } from '@prisma/client';

export class CreatePostDto {
  @IsString() @MaxLength(4000) body!: string;
  @IsOptional() @IsUrl() mediaUrl?: string;
  @IsOptional() @IsString() mediaType?: string;
  @IsEnum(PostVisibility) visibility: PostVisibility = PostVisibility.FRIENDS_ONLY;
  @IsBoolean() allowComments = true;
}

export class CreateCommentDto {
  @IsString() @MaxLength(2000) body!: string;
}
