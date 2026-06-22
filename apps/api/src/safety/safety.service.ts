import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ReportStatus, UserStatus } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { ReportDto, ResolveReportDto } from './dto/safety.dto';

@Injectable()
export class SafetyService {
  constructor(private readonly prisma: PrismaService) {}
  async block(blockerId: string, blockedId: string) {
    if (blockerId === blockedId) throw new BadRequestException('Cannot block yourself');
    await this.prisma.block.upsert({
      where: { blockerId_blockedId: { blockerId, blockedId } },
      create: { blockerId, blockedId },
      update: {},
    });
  }
  unblock(blockerId: string, blockedId: string) { return this.prisma.block.deleteMany({ where: { blockerId, blockedId } }); }
  blocks(userId: string) { return this.prisma.block.findMany({ where: { blockerId: userId }, include: { blocked: { select: { id: true, profile: { select: { displayName: true } } } } } }); }
  report(reporterId: string, dto: ReportDto) {
    if (reporterId === dto.userId) throw new BadRequestException('Cannot report yourself');
    return this.prisma.report.create({ data: { reporterId, reportedId: dto.userId, reason: dto.reason, details: dto.details, evidence: dto.evidence as never } });
  }
  reportQueue(status?: ReportStatus) { return this.prisma.report.findMany({ where: status ? { status } : {}, include: { reporter: { select: { id: true, profile: { select: { displayName: true } } } }, reported: { select: { id: true, status: true, profile: { include: { photos: true } } } } }, orderBy: { createdAt: 'asc' }, take: 100 }); }
  async resolve(reportId: string, reviewerId: string, dto: ResolveReportDto) {
    const report = await this.prisma.report.findUnique({ where: { id: reportId } });
    if (!report) throw new NotFoundException('Report not found');
    return this.prisma.$transaction(async (transaction) => {
      if (dto.userStatus && dto.userStatus !== UserStatus.DELETED) await transaction.user.update({ where: { id: report.reportedId }, data: { status: dto.userStatus } });
      const updated = await transaction.report.update({ where: { id: reportId }, data: { reviewerId, status: dto.status, resolution: dto.resolution, reviewedAt: new Date() } });
      await transaction.auditLog.create({ data: { actorId: reviewerId, action: 'REPORT_RESOLVED', targetType: 'Report', targetId: reportId, metadata: { status: dto.status, userStatus: dto.userStatus } } });
      return updated;
    });
  }
}

