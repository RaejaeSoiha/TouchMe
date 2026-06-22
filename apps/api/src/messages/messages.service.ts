import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { DeliveryStatus, MessageType } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ConversationsService } from './conversations.service';
import { SendMessageDto } from './dto/message.dto';

@Injectable()
export class MessagesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly conversations: ConversationsService,
  ) {}

  async send(userId: string, dto: SendMessageDto) {
    await this.conversations.assertMember(userId, dto.conversationId);
    if (dto.type === MessageType.SYSTEM) throw new ForbiddenException('System messages are server-only');

    const existing = await this.prisma.message.findUnique({
      where: { senderId_clientId: { senderId: userId, clientId: dto.clientId } },
    });

    const message = await this.prisma.message.upsert({
      where: { senderId_clientId: { senderId: userId, clientId: dto.clientId } },
      update: {},
      create: {
        conversationId: dto.conversationId,
        senderId: userId,
        clientId: dto.clientId,
        type: dto.type,
        body: dto.body?.trim(),
        mediaUrl: dto.mediaUrl,
        mediaSeconds: dto.mediaSeconds,
        receipts: { create: { userId, status: DeliveryStatus.SENT } },
      },
      include: { receipts: true },
    });

    await this.prisma.conversation.update({
      where: { id: dto.conversationId },
      data: { updatedAt: new Date() },
    });

    if (!existing) {
      const recipients = await this.prisma.conversationMember.findMany({
        where: { conversationId: dto.conversationId, userId: { not: userId } },
        select: { userId: true },
      });
      await Promise.all(
        recipients.map(({ userId: recipientId }) =>
          this.notifications.create(
            recipientId,
            'MESSAGE',
            'New message',
            dto.type === MessageType.TEXT
              ? (dto.body ?? '').slice(0, 120)
              : dto.type === MessageType.IMAGE
                ? 'Sent you a photo'
                : 'Sent you a voice note',
            { conversationId: dto.conversationId, messageId: message.id },
          ),
        ),
      );
    }

    return message;
  }

  async list(userId: string, conversationId: string, cursor?: string) {
    await this.conversations.assertMember(userId, conversationId);
    const messages = await this.prisma.message.findMany({
      where: { conversationId, deletedAt: null },
      include: { receipts: true },
      orderBy: { createdAt: 'desc' },
      take: 51,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    return { items: messages.slice(0, 50), nextCursor: messages.length > 50 ? messages[49]?.id : null };
  }

  async receipt(userId: string, messageId: string, status: DeliveryStatus) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId } });
    if (!message) throw new NotFoundException('Message not found');
    await this.conversations.assertMember(userId, message.conversationId);
    return this.prisma.messageReceipt.upsert({
      where: { messageId_userId: { messageId, userId } },
      create: { messageId, userId, status },
      update: { status },
    });
  }
}
