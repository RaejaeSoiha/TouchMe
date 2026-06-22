import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser } from '../common/auth-user';
import { DiscoveryQueryDto } from './dto/discovery.dto';
import { DiscoveryService } from './discovery.service';
@ApiTags('discovery') @Controller('discovery')
export class DiscoveryController {
  constructor(private readonly discovery: DiscoveryService) {}
  @Get() get(@CurrentUser() user: AuthUser, @Query() query: DiscoveryQueryDto) { return this.discovery.discover(user.id, query); }
}

