import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser } from '../common/auth-user';
import { CreateCommentDto, CreatePostDto } from './dto/post.dto';
import { PostsService } from './posts.service';

@ApiTags('posts')
@Controller('posts')
export class PostsController {
  constructor(private readonly posts: PostsService) {}

  @Get() feed(@CurrentUser() user: AuthUser) {
    return this.posts.feed(user.id);
  }

  @Post() create(@CurrentUser() user: AuthUser, @Body() dto: CreatePostDto) {
    return this.posts.create(user.id, dto);
  }

  @Post(':postId/like') @HttpCode(HttpStatus.OK)
  like(@CurrentUser() user: AuthUser, @Param('postId') postId: string) {
    return this.posts.toggleLike(user.id, postId);
  }

  @Post(':postId/comments')
  comment(
    @CurrentUser() user: AuthUser,
    @Param('postId') postId: string,
    @Body() dto: CreateCommentDto,
  ) {
    return this.posts.comment(user.id, postId, dto);
  }
}
