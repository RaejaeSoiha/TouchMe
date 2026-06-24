import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { FriendRequestStatus } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PresenceService } from '../presence/presence.service';

@Injectable()
export class FriendsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly presence: PresenceService,
  ) {}

  async listFriends(userId: string) {
    const rows = await this.prisma.friendship.findMany({
      where: { userId },
      include: {
        friend: {
          select: {
            id: true,
            lastActiveAt: true,
            profile: {
              include: {
                photos: { where: { status: 'APPROVED' }, orderBy: { position: 'asc' }, take: 1 },
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    const presence = await this.presence.snapshot(rows.map((row) => row.friend.id));
    return rows.map((row) => {
      const status = presence.get(row.friend.id);
      return {
        userId: row.friend.id,
        displayName: row.friend.profile?.displayName ?? 'TouchMe user',
        photoUrl: row.friend.profile?.photos[0]?.url ?? null,
        online: status?.online ?? false,
        lastActiveAt: status?.lastActiveAt ?? row.friend.lastActiveAt,
        friendsSince: row.createdAt,
      };
    });
  }

  async listRequests(userId: string) {
    const incoming = await this.prisma.friendRequest.findMany({
      where: { recipientId: userId, status: FriendRequestStatus.PENDING },
      include: {
        sender: {
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
      orderBy: { createdAt: 'desc' },
    });
    return incoming.map((request) => ({
      id: request.id,
      userId: request.sender.id,
      displayName: request.sender.profile?.displayName ?? 'TouchMe user',
      photoUrl: request.sender.profile?.photos[0]?.url ?? null,
      createdAt: request.createdAt,
    }));
  }

  async sendRequest(senderId: string, recipientId: string) {
    if (senderId === recipientId) throw new BadRequestException('Cannot add yourself');
    await this.assertNotBlocked(senderId, recipientId);
    const existingFriend = await this.prisma.friendship.findUnique({
      where: { userId_friendId: { userId: senderId, friendId: recipientId } },
    });
    if (existingFriend) throw new BadRequestException('Already friends');

    const reverse = await this.prisma.friendRequest.findUnique({
      where: { senderId_recipientId: { senderId: recipientId, recipientId: senderId } },
    });
    if (reverse?.status === FriendRequestStatus.PENDING) {
      return this.acceptRequest(senderId, reverse.id);
    }

    const request = await this.prisma.friendRequest.upsert({
      where: { senderId_recipientId: { senderId, recipientId } },
      create: { senderId, recipientId },
      update: { status: FriendRequestStatus.PENDING, updatedAt: new Date() },
    });
    const sender = await this.prisma.profile.findUnique({ where: { userId: senderId }, select: { displayName: true } });
    await this.notifications.create(
      recipientId,
      'FRIEND_REQUEST',
      'New friend request',
      `${sender?.displayName ?? 'Someone'} wants to connect on TouchMe`,
      { requestId: request.id, userId: senderId },
    );
    return request;
  }

  async acceptRequest(userId: string, requestId: string) {
    const request = await this.prisma.friendRequest.findUnique({ where: { id: requestId } });
    if (!request || request.recipientId !== userId) throw new NotFoundException('Friend request not found');
    if (request.status !== FriendRequestStatus.PENDING) throw new BadRequestException('Request is not pending');

    await this.prisma.$transaction(async (tx) => {
      await tx.friendRequest.update({
        where: { id: requestId },
        data: { status: FriendRequestStatus.ACCEPTED },
      });
      await tx.friendship.createMany({
        data: [
          { userId: request.senderId, friendId: request.recipientId },
          { userId: request.recipientId, friendId: request.senderId },
        ],
        skipDuplicates: true,
      });
    });
    return { ok: true };
  }

  async rejectRequest(userId: string, requestId: string) {
    const request = await this.prisma.friendRequest.findUnique({ where: { id: requestId } });
    if (!request || request.recipientId !== userId) throw new NotFoundException('Friend request not found');
    return this.prisma.friendRequest.update({
      where: { id: requestId },
      data: { status: FriendRequestStatus.REJECTED },
    });
  }

  async cancelRequest(senderId: string, requestId: string) {
    const request = await this.prisma.friendRequest.findUnique({ where: { id: requestId } });
    if (!request || request.senderId !== senderId) throw new NotFoundException('Friend request not found');
    if (request.status !== FriendRequestStatus.PENDING) {
      throw new BadRequestException('Request is not pending');
    }
    return this.prisma.friendRequest.update({
      where: { id: requestId },
      data: { status: FriendRequestStatus.CANCELLED },
    });
  }

  async cancelOutgoing(senderId: string, recipientId: string) {
    const request = await this.prisma.friendRequest.findUnique({
      where: { senderId_recipientId: { senderId, recipientId } },
    });
    if (!request || request.senderId !== senderId) throw new NotFoundException('Friend request not found');
    if (request.status !== FriendRequestStatus.PENDING) {
      throw new BadRequestException('Request is not pending');
    }
    return this.prisma.friendRequest.update({
      where: { id: request.id },
      data: { status: FriendRequestStatus.CANCELLED },
    });
  }

  async removeFriend(userId: string, friendId: string) {
    await this.prisma.$transaction([
      this.prisma.friendship.deleteMany({
        where: {
          OR: [
            { userId, friendId },
            { userId: friendId, friendId: userId },
          ],
        },
      }),
      this.prisma.friendRequest.deleteMany({
        where: {
          OR: [
            { senderId: userId, recipientId: friendId },
            { senderId: friendId, recipientId: userId },
          ],
        },
      }),
    ]);
    return { ok: true };
  }

  async relationMap(userId: string, otherIds: string[]) {
    if (!otherIds.length) return new Map<string, string>();
    const [friendships, outgoing, incoming] = await Promise.all([
      this.prisma.friendship.findMany({
        where: { userId, friendId: { in: otherIds } },
        select: { friendId: true },
      }),
      this.prisma.friendRequest.findMany({
        where: { senderId: userId, recipientId: { in: otherIds }, status: FriendRequestStatus.PENDING },
        select: { recipientId: true },
      }),
      this.prisma.friendRequest.findMany({
        where: { recipientId: userId, senderId: { in: otherIds }, status: FriendRequestStatus.PENDING },
        select: { senderId: true },
      }),
    ]);
    const map = new Map<string, string>();
    for (const id of otherIds) map.set(id, 'NONE');
    for (const { friendId } of friendships) map.set(friendId, 'FRIENDS');
    for (const { recipientId } of outgoing) map.set(recipientId, 'REQUEST_SENT');
    for (const { senderId } of incoming) map.set(senderId, 'REQUEST_RECEIVED');
    return map;
  }

  private async assertNotBlocked(a: string, b: string) {
    const blocked = await this.prisma.block.findFirst({
      where: {
        OR: [
          { blockerId: a, blockedId: b },
          { blockerId: b, blockedId: a },
        ],
      },
    });
    if (blocked) throw new BadRequestException('Cannot connect with this user');
  }
}
