import { Body, Controller, Get, Headers, Post, RawBodyRequest, Req } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { AuthUser, CurrentUser, Public } from '../common/auth-user';
import { CheckoutDto } from './dto/subscription.dto';
import { SubscriptionsService } from './subscriptions.service';
@ApiTags('subscriptions') @Controller('subscriptions')
export class SubscriptionsController {
  constructor(private readonly subscriptions: SubscriptionsService) {}
  @Public() @Get('plans') plans() { return this.subscriptions.plans(); }
  @Get('me') mine(@CurrentUser() user: AuthUser) { return this.subscriptions.mine(user.id); }
  @Post('checkout') checkout(@CurrentUser() user: AuthUser, @Body() dto: CheckoutDto) { return this.subscriptions.checkout(user.id, dto.planCode); }
  @Post('boost') boost(@CurrentUser() user: AuthUser) { return this.subscriptions.activateBoost(user.id); }
  @Public() @Post('webhook') webhook(@Headers('stripe-signature') signature: string, @Req() request: RawBodyRequest<FastifyRequest>) { return this.subscriptions.webhook(signature, request.rawBody ?? Buffer.alloc(0)); }
}
