import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SubscriptionStatus } from '@prisma/client';
import Stripe from 'stripe';
import { PrismaService } from '../database/prisma.service';

@Injectable()
export class SubscriptionsService {
  private readonly stripe?: Stripe;
  constructor(private readonly config: ConfigService, private readonly prisma: PrismaService) {
    const key = config.get<string>('STRIPE_SECRET_KEY'); if (key) this.stripe = new Stripe(key);
  }
  plans() { return this.prisma.plan.findMany({ where: { active: true }, orderBy: { priceCents: 'asc' } }); }
  mine(userId: string) { return this.prisma.subscription.findFirst({ where: { userId, status: SubscriptionStatus.ACTIVE }, include: { plan: true }, orderBy: { createdAt: 'desc' } }); }
  async entitlements(userId: string) { const subscription = await this.mine(userId); return subscription?.currentPeriodEnd && subscription.currentPeriodEnd > new Date() ? subscription.plan : null; }
  async activateBoost(userId: string) {
    const plan = await this.entitlements(userId); if (!plan || plan.monthlyBoosts < 1) throw new BadRequestException('Your plan does not include boosts');
    const monthStart = new Date(); monthStart.setUTCDate(1); monthStart.setUTCHours(0, 0, 0, 0);
    const used = await this.prisma.boost.count({ where: { userId, createdAt: { gte: monthStart } } }); if (used >= plan.monthlyBoosts) throw new BadRequestException('Monthly boost allowance used');
    const startsAt = new Date(); return this.prisma.boost.create({ data: { userId, startsAt, endsAt: new Date(startsAt.getTime() + 30 * 60 * 1000) } });
  }
  async checkout(userId: string, planCode: string) {
    if (!this.stripe) throw new BadRequestException('Billing is not configured');
    const [user, plan] = await Promise.all([this.prisma.user.findUniqueOrThrow({ where: { id: userId } }), this.prisma.plan.findUnique({ where: { code: planCode } })]);
    if (!plan?.active) throw new BadRequestException('Plan unavailable');
    const origin = this.config.get<string>('APP_ORIGINS', '').split(',')[0];
    const session = await this.stripe.checkout.sessions.create({ mode: 'subscription', customer_email: user.email ?? undefined, line_items: [{ price: plan.stripePriceId, quantity: 1 }], success_url: `${origin}/subscription/success`, cancel_url: `${origin}/subscription`, client_reference_id: userId, metadata: { userId, planId: plan.id } });
    return { url: session.url };
  }
  async webhook(signature: string, rawBody: Buffer) {
    if (!this.stripe) throw new BadRequestException('Billing is not configured');
    const event = this.stripe.webhooks.constructEvent(rawBody, signature, this.config.getOrThrow<string>('STRIPE_WEBHOOK_SECRET'));
    if (event.type === 'customer.subscription.created' || event.type === 'customer.subscription.updated' || event.type === 'customer.subscription.deleted') {
      const subscription = event.data.object;
      const userId = subscription.metadata.userId; const planId = subscription.metadata.planId;
      const item = subscription.items.data[0];
      const customerId = typeof subscription.customer === 'string' ? subscription.customer : subscription.customer.id;
      if (userId && planId && item) await this.prisma.subscription.upsert({ where: { stripeSubscriptionId: subscription.id }, create: { userId, planId, stripeCustomerId: customerId, stripeSubscriptionId: subscription.id, status: this.status(subscription.status), currentPeriodEnd: new Date(item.current_period_end * 1000), cancelAtPeriodEnd: subscription.cancel_at_period_end }, update: { status: this.status(subscription.status), currentPeriodEnd: new Date(item.current_period_end * 1000), cancelAtPeriodEnd: subscription.cancel_at_period_end } });
    }
    return { received: true };
  }
  private status(status: Stripe.Subscription.Status): SubscriptionStatus {
    const map: Partial<Record<Stripe.Subscription.Status, SubscriptionStatus>> = { active: 'ACTIVE', trialing: 'ACTIVE', past_due: 'PAST_DUE', canceled: 'CANCELED', incomplete: 'INCOMPLETE', incomplete_expired: 'EXPIRED', unpaid: 'PAST_DUE', paused: 'PAST_DUE' };
    return map[status] ?? 'INCOMPLETE';
  }
}
