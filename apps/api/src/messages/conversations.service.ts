import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { PresenceService } from '../presence/presence.service';

@Injectable()
export class ConversationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly presence: PresenceService,
  ) {}

  async list(userId: string) {
    const memberships = await this.prisma.conversationMember.findMany({
      where: { userId },
      include: {
        conversation: {
          include: {
            members: {
              where: { userId: { not: userId } },
              include: {
                user: {
                  select: {
                    id: true,
                    profile: {
                      include: {
                        photos: { where: { status: 'APPROVED' }, orderBy: { position: 'asc' }, take: 1 },
                      },
                    },
                  },
                },
              },
            },
            messages: {
              where: { deletedAt: null },
              orderBy: { createdAt: 'desc' },
              take: 1,
            },
          },
        },
      },
      orderBy: { conversation: { updatedAt: 'desc' } },
    });

    const otherIds = memberships
      .map((membership) => membership.conversation.members[0]?.user.id)
      .filter((id): id is string => Boolean(id));
    const presence = await this.presence.snapshot(otherIds);

    return memberships.map((membership) => {
      const other = membership.conversation.members[0]?.user;
      const last = membership.conversation.messages[0];
      const status = other ? presence.get(other.id) : undefined;
      return {
        id: membership.conversationId,
        otherUser: other
          ? {
              id: other.id,
              displayName: other.profile?.displayName ?? 'TouchMe user',
              photoUrl: other.profile?.photos[0]?.url ?? null,
              online: status?.online ?? false,
              lastActiveAt: status?.lastActiveAt ?? new Date(0),
            }
          : null,
        lastMessage: last
          ? {
              id: last.id,
              type: last.type,
              body: last.body,
              createdAt: last.createdAt,
              senderId: last.senderId,
            }
          : null,
        updatedAt: membership.conversation.updatedAt,
      };
    });
  }

  async getOrCreate(userId: string, otherUserId: string) {
    if (userId === otherUserId) throw new BadRequestException('Cannot message yourself');
    await this.assertCanMessage(userId, otherUserId);

    const existing = await this.prisma.conversation.findFirst({
      where: {
        AND: [
          { members: { some: { userId } } },
          { members: { some: { userId: otherUserId } } },
        ],
      },
      include: {
        members: {
          include: {
            user: {
              select: {
                id: true,
                profile: {
                  include: {
                    photos: { where: { status: 'APPROVED' }, orderBy: { position: 'asc' }, take: 1 },
                  },
                },
              },
            },
          },
        },
      },
    });
    if (existing) {
      return this.serialize(existing, userId);
    }

    const created = await this.prisma.conversation.create({
      data: {
        members: {
          create: [{ userId }, { userId: otherUserId }],
        },
      },
      include: {
        members: {
          include: {
            user: {
              select: {
                id: true,
                profile: {
                  include: {
                    photos: { where: { status: 'APPROVED' }, orderBy: { position: 'asc' }, take: 1 },
                  },
                },
              },
            },
          },
        },
      },
    });
    return this.serialize(created, userId);
  }

  async assertMember(userId: string, conversationId: string) {
    const member = await this.prisma.conversationMember.findUnique({
      where: { conversationId_userId: { conversationId, userId } },
    });
    if (!member) throw new ForbiddenException('Conversation access denied');
    return member;
  }

  private async serialize(
    conversation: {
      id: string;
      updatedAt: Date;
      members: Array<{
        user: {
          id: string;
          profile: { displayName: string; photos: Array<{ url: string }> } | null;
        };
      }>;
    },
    userId: string,
  ) {
    const other = conversation.members.find((member) => member.user.id !== userId)?.user;
    const status = other ? (await this.presence.snapshot([other.id])).get(other.id) : undefined;
    return {
      id: conversation.id,
      otherUser: other
        ? {
            id: other.id,
            displayName: other.profile?.displayName ?? 'TouchMe user',
            photoUrl: other.profile?.photos[0]?.url ?? null,
            online: status?.online ?? false,
            lastActiveAt: status?.lastActiveAt ?? new Date(0),
          }
        : null,
      updatedAt: conversation.updatedAt,
    };
  }

  private async assertCanMessage(a: string, b: string) {
    const blocked = await this.prisma.block.findFirst({
      where: {
        OR: [
          { blockerId: a, blockedId: b },
          { blockerId: b, blockedId: a },
        ],
      },
    });
    if (blocked) throw new ForbiddenException('Messaging is blocked');
    const other = await this.prisma.user.findUnique({ where: { id: b }, select: { status: true } });
    if (!other || other.status !== 'ACTIVE') throw new NotFoundException('User not found');
  }
}
