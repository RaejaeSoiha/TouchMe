import { ReportReason, ReportStatus, UserStatus } from '@prisma/client';
import { IsEnum, IsObject, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
export class BlockDto { @IsUUID() userId!: string; }
export class ReportDto {
  @IsUUID() userId!: string;
  @IsEnum(ReportReason) reason!: ReportReason;
  @IsOptional() @IsString() @MaxLength(2000) details?: string;
  @IsOptional() @IsObject() evidence?: Record<string, unknown>;
}
export class ResolveReportDto {
  @IsEnum(ReportStatus) status!: ReportStatus;
  @IsString() @MaxLength(2000) resolution!: string;
  @IsOptional() @IsEnum(UserStatus) userStatus?: UserStatus;
}

