import { Inject, UsePipes, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import Redis from 'ioredis';
import { PrismaService } from '../database/prisma.service';
import { PresenceService } from '../presence/presence.service';
import { REDIS } from '../redis/redis.module';
import { resolveCorsOrigins } from '../config/cors';
import { ReceiptDto, SendMessageDto } from './dto/message.dto';
import { MessagesService } from './messages.service';
import { ConversationsService } from './conversations.service';

interface SocketClaims { sub: string; type: 'access' }
interface AuthSocket extends Socket { data: { userId: string } }

const socketOrigins = process.env.APP_ORIGINS?.split(',').map((origin) => origin.trim()).filter(Boolean) ?? [];
const socketNodeEnv = process.env.NODE_ENV ?? 'development';

@WebSocketGateway({
  namespace: '/chat',
  cors: { origin: resolveCorsOrigins(socketOrigins, socketNodeEnv), credentials: true },
})
@UsePipes(new ValidationPipe({ whitelist: true, transform: true }))
export class MessagesGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly messages: MessagesService,
    private readonly conversations: ConversationsService,
    private readonly presence: PresenceService,
    @Inject(REDIS) private readonly redis: Redis,
  ) {}

  private broadcastPresence(userId: string, info: { online: boolean; lastActiveAt: Date }) {
    this.server.emit('presence', {
      userId,
      online: info.online,
      lastActiveAt: info.lastActiveAt.toISOString(),
    });
  }

  async handleConnection(client: AuthSocket) {
    try {
      const bearer = client.handshake.auth.token as string | undefined;
      const claims = await this.jwt.verifyAsync<SocketClaims>(bearer ?? '', {
        secret: this.config.getOrThrow('JWT_ACCESS_SECRET'),
      });
      if (claims.type !== 'access') throw new Error();
      client.data.userId = claims.sub;
      await client.join(`user:${claims.sub}`);
      const memberships = await this.prisma.conversationMember.findMany({
        where: { userId: claims.sub },
        select: { conversationId: true },
      });
      for (const { conversationId } of memberships) {
        await client.join(`conversation:${conversationId}`);
      }
      const info = await this.presence.markOnline(claims.sub);
      this.broadcastPresence(claims.sub, info);
    } catch {
      client.disconnect(true);
    }
  }

  async handleDisconnect(client: AuthSocket) {
    if (client.data.userId) {
      const info = await this.presence.markOffline(client.data.userId);
      this.broadcastPresence(client.data.userId, info);
    }
  }

  @SubscribeMessage('presence:heartbeat')
  async heartbeat(@ConnectedSocket() client: AuthSocket) {
    const info = await this.presence.heartbeat(client.data.userId);
    return { online: info.online, lastActiveAt: info.lastActiveAt.toISOString() };
  }

  @SubscribeMessage('message:send')
  async send(@ConnectedSocket() client: AuthSocket, @MessageBody() dto: SendMessageDto) {
    try {
      const key = `spam:message:${client.data.userId}`;
      const count = await this.redis.incr(key);
      if (count === 1) await this.redis.expire(key, 10);
      if (count > 30) throw new WsException('Message rate exceeded');
      await this.presence.heartbeat(client.data.userId);
      const message = await this.messages.send(client.data.userId, dto);
      this.server.to(`conversation:${dto.conversationId}`).emit('message:new', message);
      return message;
    } catch (error) {
      throw new WsException(error instanceof Error ? error.message : 'Message rejected');
    }
  }

  @SubscribeMessage('message:receipt')
  async receipt(@ConnectedSocket() client: AuthSocket, @MessageBody() dto: ReceiptDto) {
    const receipt = await this.messages.receipt(client.data.userId, dto.messageId, dto.status);
    const message = await this.prisma.message.findUniqueOrThrow({ where: { id: dto.messageId } });
    this.server.to(`conversation:${message.conversationId}`).emit('message:receipt', receipt);
  }

  @SubscribeMessage('typing')
  async typing(
    @ConnectedSocket() client: AuthSocket,
    @MessageBody() body: { conversationId: string; active: boolean },
  ) {
    await this.conversations.assertMember(client.data.userId, body.conversationId);
    client.to(`conversation:${body.conversationId}`).emit('typing', {
      userId: client.data.userId,
      active: Boolean(body.active),
    });
  }

  @SubscribeMessage('conversation:join')
  async joinConversation(
    @ConnectedSocket() client: AuthSocket,
    @MessageBody() body: { conversationId: string },
  ) {
    await this.conversations.assertMember(client.data.userId, body.conversationId);
    await client.join(`conversation:${body.conversationId}`);
  }
}
