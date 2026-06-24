import { Injectable, Logger } from '@nestjs/common';
import { NotificationType } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { ConfigService } from '@nestjs/config'; import { App, cert, getApps, initializeApp } from 'firebase-admin/app'; import { getMessaging } from 'firebase-admin/messaging';
@Injectable()
export class NotificationsService {
  private readonly firebase?: App;
  private readonly logger = new Logger(NotificationsService.name);
  constructor(private readonly prisma: PrismaService, config: ConfigService) { const projectId = config.get<string>('FIREBASE_PROJECT_ID'); const clientEmail = config.get<string>('FIREBASE_CLIENT_EMAIL'); const privateKey = config.get<string>('FIREBASE_PRIVATE_KEY')?.replace(/\\n/g, '\n'); if (projectId && clientEmail && privateKey) this.firebase = getApps()[0] ?? initializeApp({ credential: cert({ projectId, clientEmail, privateKey }) }); }
  register(userId: string, platform: string, pushToken: string) { return this.prisma.device.upsert({ where: { pushToken }, create: { userId, platform, pushToken }, update: { userId, platform, active: true } }); }
  deactivateAll(userId: string) { return this.prisma.device.updateMany({ where: { userId }, data: { active: false } }); }
  list(userId: string) { return this.prisma.notification.findMany({ where: { userId }, orderBy: { createdAt: 'desc' }, take: 100 }); }
  markRead(userId: string, id: string) { return this.prisma.notification.updateMany({ where: { id, userId }, data: { readAt: new Date() } }); }
  async create(userId: string, type: NotificationType, title: string, body: string, data?: Record<string, unknown>) {
    const notification = await this.prisma.notification.create({ data: { userId, type, title, body, data: data as never } });
    const devices = await this.prisma.device.findMany({ where: { userId, active: true }, select: { pushToken: true } });
    if (this.firebase && devices.length) { try { await getMessaging(this.firebase).sendEachForMulticast({ tokens: devices.map(({ pushToken }) => pushToken), notification: { title, body }, data: Object.fromEntries(Object.entries(data ?? {}).map(([key, value]) => [key, String(value)])) }); } catch (error) { this.logger.warn(error instanceof Error ? error.message : 'Push delivery failed'); } }
    return notification;
  }
}
