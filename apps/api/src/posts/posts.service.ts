import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PostVisibility, Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { CreateCommentDto, CreatePostDto } from './dto/post.dto';

@Injectable()
export class PostsService {
  constructor(private readonly prisma: PrismaService) {}

  private async friendIds(userId: string) {
    const rows = await this.prisma.friendship.findMany({
      where: { userId },
      select: { friendId: true },
    });
    return rows.map((row) => row.friendId);
  }

  private serialize(
    post: Prisma.PostGetPayload<{
      include: {
        author: { select: { id: true; profile: { select: { displayName: true } } } };
        likes: { select: { userId: true } };
        comments: {
          include: { author: { select: { profile: { select: { displayName: true } } } } };
          orderBy: { createdAt: 'asc' };
        };
      };
    }>,
    viewerId: string,
  ) {
    return {
      id: post.id,
      authorId: post.authorId,
      authorName: post.author.profile?.displayName ?? 'TouchMe user',
      body: post.body,
      mediaUrl: post.mediaUrl,
      mediaType: post.mediaType,
      visibility: post.visibility,
      allowComments: post.allowComments,
      createdAt: post.createdAt,
      likeCount: post.likes.length,
      likedByMe: post.likes.some((like) => like.userId === viewerId),
      comments: post.comments.map((comment) => ({
        id: comment.id,
        authorName: comment.author.profile?.displayName ?? 'TouchMe user',
        body: comment.body,
        createdAt: comment.createdAt,
      })),
    };
  }

  async feed(userId: string) {
    const friends = await this.friendIds(userId);
    const visibleAuthors = [userId, ...friends];
    const posts = await this.prisma.post.findMany({
      where: {
        OR: [
          { authorId: { in: visibleAuthors }, visibility: PostVisibility.FRIENDS_ONLY },
          { authorId: userId, visibility: PostVisibility.ONLY_ME },
        ],
      },
      include: {
        author: { select: { id: true, profile: { select: { displayName: true } } } },
        likes: { select: { userId: true } },
        comments: {
          include: { author: { select: { profile: { select: { displayName: true } } } } },
          orderBy: { createdAt: 'asc' },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return posts.map((post) => this.serialize(post, userId));
  }

  async create(userId: string, dto: CreatePostDto) {
    const body = dto.body.trim();
    if (!body && !dto.mediaUrl) throw new BadRequestException('Post must include text or media');
    const post = await this.prisma.post.create({
      data: {
        authorId: userId,
        body: body || ' ',
        mediaUrl: dto.mediaUrl,
        mediaType: dto.mediaType,
        visibility: dto.visibility,
        allowComments: dto.allowComments,
      },
      include: {
        author: { select: { id: true, profile: { select: { displayName: true } } } },
        likes: { select: { userId: true } },
        comments: {
          include: { author: { select: { profile: { select: { displayName: true } } } } },
          orderBy: { createdAt: 'asc' },
        },
      },
    });
    return this.serialize(post, userId);
  }

  async toggleLike(userId: string, postId: string) {
    const post = await this.prisma.post.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException('Post not found');
    const existing = await this.prisma.postLike.findUnique({
      where: { postId_userId: { postId, userId } },
    });
    if (existing) {
      await this.prisma.postLike.delete({ where: { postId_userId: { postId, userId } } });
      return { liked: false };
    }
    await this.prisma.postLike.create({ data: { postId, userId } });
    return { liked: true };
  }

  async comment(userId: string, postId: string, dto: CreateCommentDto) {
    const post = await this.prisma.post.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException('Post not found');
    if (!post.allowComments) throw new ForbiddenException('Comments are disabled on this post');
    const body = dto.body.trim();
    if (!body) throw new BadRequestException('Comment cannot be empty');
    return this.prisma.postComment.create({
      data: { postId, authorId: userId, body },
      include: { author: { select: { profile: { select: { displayName: true } } } } },
    });
  }
}
