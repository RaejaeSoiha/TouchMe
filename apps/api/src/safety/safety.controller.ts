import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser } from '../common/auth-user';
import { BlockDto, ReportDto } from './dto/safety.dto';
import { SafetyService } from './safety.service';
@ApiTags('safety') @Controller('safety')
export class SafetyController {
  constructor(private readonly safety: SafetyService) {}
  @Post('blocks') @HttpCode(HttpStatus.NO_CONTENT) block(@CurrentUser() user: AuthUser, @Body() dto: BlockDto) { return this.safety.block(user.id, dto.userId); }
  @Delete('blocks/:userId') @HttpCode(HttpStatus.NO_CONTENT) unblock(@CurrentUser() user: AuthUser, @Param('userId') blockedId: string) { return this.safety.unblock(user.id, blockedId); }
  @Get('blocks') blocks(@CurrentUser() user: AuthUser) { return this.safety.blocks(user.id); }
  @Post('reports') report(@CurrentUser() user: AuthUser, @Body() dto: ReportDto) { return this.safety.report(user.id, dto); }
}

