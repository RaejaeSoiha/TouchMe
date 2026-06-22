import { Body, Controller, Get, Param, Patch, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { ReportStatus, UserRole, UserStatus } from '@prisma/client';
import { AuthUser, CurrentUser, Roles } from '../common/auth-user';
import { PrismaService } from '../database/prisma.service';
import { AnalyticsService } from '../analytics/analytics.service';
import { ResolveReportDto } from '../safety/dto/safety.dto';
import { SafetyService } from '../safety/safety.service';

@ApiTags('admin') @Roles(UserRole.ADMIN, UserRole.MODERATOR) @Controller('admin')
export class AdminController {
  constructor(private readonly prisma: PrismaService, private readonly safety: SafetyService, private readonly analytics: AnalyticsService) {}
  @Get('users') users(@Query('search') search?: string, @Query('status') status?: UserStatus) { return this.prisma.user.findMany({ where: { ...(status ? { status } : {}), ...(search ? { OR: [{ email: { contains: search, mode: 'insensitive' } }, { profile: { displayName: { contains: search, mode: 'insensitive' } } }] } : {}) }, select: { id: true, email: true, phone: true, role: true, status: true, createdAt: true, lastActiveAt: true, profile: { select: { displayName: true, verificationStatus: true } } }, orderBy: { createdAt: 'desc' }, take: 100 }); }
  @Patch('users/:id/status') async status(@CurrentUser() admin: AuthUser, @Param('id') id: string, @Body('status') status: UserStatus) { const user = await this.prisma.user.update({ where: { id }, data: { status } }); await this.prisma.auditLog.create({ data: { actorId: admin.id, action: 'USER_STATUS_CHANGED', targetType: 'User', targetId: id, metadata: { status } } }); return user; }
  @Get('reports') reports(@Query('status') status?: ReportStatus) { return this.safety.reportQueue(status); }
  @Patch('reports/:id') resolve(@CurrentUser() admin: AuthUser, @Param('id') id: string, @Body() dto: ResolveReportDto) { return this.safety.resolve(id, admin.id, dto); }
  @Get('analytics') dashboard() { return this.analytics.dashboard(); }
  @Get('subscriptions') subscriptions() { return this.prisma.subscription.findMany({ include: { user: { select: { email: true, profile: { select: { displayName: true } } } }, plan: true }, orderBy: { createdAt: 'desc' }, take: 200 }); }
  @Get('plans') plans() { return this.prisma.plan.findMany({ orderBy: { priceCents: 'asc' } }); }
  @Get('media') media() { return this.prisma.photo.findMany({ where: { status: 'PENDING' }, include: { profile: { select: { userId: true, displayName: true } } }, orderBy: { createdAt: 'asc' }, take: 100 }); }
  @Patch('media/:id') async moderateMedia(@CurrentUser() admin: AuthUser, @Param('id') id: string, @Body('status') status: 'APPROVED' | 'REJECTED') { const photo = await this.prisma.photo.update({ where: { id }, data: { status } }); await this.prisma.auditLog.create({ data: { actorId: admin.id, action: 'MEDIA_MODERATED', targetType: 'Photo', targetId: id, metadata: { status } } }); return photo; }
  @Patch('plans/:id') async updatePlan(@CurrentUser() admin: AuthUser, @Param('id') id: string, @Body('active') active: boolean) { const plan = await this.prisma.plan.update({ where: { id }, data: { active } }); await this.prisma.auditLog.create({ data: { actorId: admin.id, action: 'PLAN_UPDATED', targetType: 'Plan', targetId: id, metadata: { active } } }); return plan; }
}
