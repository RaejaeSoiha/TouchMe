import { BadRequestException, ConflictException, Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { IdentityProvider, User, UserStatus } from '@prisma/client';
import * as argon2 from 'argon2';
import { createHash, randomInt, randomUUID } from 'crypto';
import { OAuth2Client } from 'google-auth-library';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import Redis from 'ioredis';
import { CommunicationsService } from '../communications/communications.service';
import { PrismaService } from '../database/prisma.service';
import { REDIS } from '../redis/redis.module';
import { LoginDto, SignupDto } from './dto/auth.dto';

interface ClientContext { ip?: string; userAgent?: string }
export interface TokenPair { accessToken: string; refreshToken: string; expiresIn: number }
interface RefreshClaims { sub: string; jti: string; fid: string; type: 'refresh'; exp: number }

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly communications: CommunicationsService,
    @Inject(REDIS) private readonly redis: Redis
  ) {}

  async signup(dto: SignupDto, context: ClientContext): Promise<TokenPair> {
    const email = dto.email.trim().toLowerCase();
    if (await this.prisma.user.findUnique({ where: { email } })) throw new ConflictException('Email already registered');
    const passwordHash = await argon2.hash(dto.password, { type: argon2.argon2id, memoryCost: 19456, timeCost: 3, parallelism: 1 });
    const user = await this.prisma.user.create({ data: { email, passwordHash, status: UserStatus.ACTIVE, identities: { create: { provider: IdentityProvider.EMAIL, providerSubject: email } } } });
    const verificationToken = await this.issueVerification(user.id, 'EMAIL_VERIFY');
    await this.communications.sendEmailVerification(email, verificationToken);
    return this.createTokenPair(user, context);
  }

  async login(dto: LoginDto, context: ClientContext): Promise<TokenPair> {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email.trim().toLowerCase() } });
    if (!user?.passwordHash || !(await argon2.verify(user.passwordHash, dto.password))) throw new UnauthorizedException('Invalid credentials');
    if (user.status !== UserStatus.ACTIVE) throw new UnauthorizedException('Account is not active');
    await this.prisma.user.update({ where: { id: user.id }, data: { lastActiveAt: new Date() } });
    return this.createTokenPair(user, context);
  }

  async refresh(rawToken: string, context: ClientContext): Promise<TokenPair> {
    let claims: RefreshClaims;
    try { claims = await this.jwt.verifyAsync<RefreshClaims>(rawToken, { secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET') }); }
    catch { throw new UnauthorizedException('Invalid refresh token'); }
    if (claims.type !== 'refresh') throw new UnauthorizedException('Invalid token type');
    const stored = await this.prisma.refreshToken.findUnique({ where: { id: claims.jti }, include: { user: true } });
    if (!stored || stored.revokedAt || stored.expiresAt <= new Date() || !(await argon2.verify(stored.tokenHash, rawToken))) {
      await this.prisma.refreshToken.updateMany({ where: { familyId: claims.fid, revokedAt: null }, data: { revokedAt: new Date() } });
      throw new UnauthorizedException('Refresh token reuse detected');
    }
    await this.prisma.refreshToken.update({ where: { id: stored.id }, data: { revokedAt: new Date() } });
    return this.createTokenPair(stored.user, context, stored.familyId, stored.id);
  }

  async logout(userId: string, familyId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({ where: { userId, familyId, revokedAt: null }, data: { revokedAt: new Date() } });
  }

  async deleteAccount(userId: string, familyId: string): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.refreshToken.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: new Date() } }),
      this.prisma.device.deleteMany({ where: { userId } }),
      this.prisma.user.update({
        where: { id: userId },
        data: {
          status: UserStatus.DELETED,
          email: null,
          phone: null,
          passwordHash: null,
          deletedAt: new Date()
        }
      })
    ]);
    await this.logout(userId, familyId);
  }

  async requestOtp(phone: string): Promise<void> {
    const normalized = phone.replace(/\s/g, '');
    const code = randomInt(100000, 1000000).toString();
    await this.redis.set(`otp:${normalized}`, await argon2.hash(code), 'EX', 300);
    if (this.config.get('NODE_ENV') !== 'production') await this.redis.set(`otp-dev:${normalized}`, code, 'EX', 300);
  }

  async requestPasswordReset(emailInput: string): Promise<void> {
    const email = emailInput.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return;
    const token = await this.issueVerification(user.id, 'PASSWORD_RESET');
    await this.communications.sendPasswordReset(email, token);
  }

  async social(provider: 'google' | 'apple', identityToken: string, context: ClientContext): Promise<TokenPair> {
    const identity = provider === 'google' ? await this.verifyGoogle(identityToken) : await this.verifyApple(identityToken);
    const providerEnum = provider === 'google' ? IdentityProvider.GOOGLE : IdentityProvider.APPLE;
    const existing = await this.prisma.authIdentity.findUnique({ where: { provider_providerSubject: { provider: providerEnum, providerSubject: identity.subject } }, include: { user: true } });
    if (existing) return this.createTokenPair(existing.user, context);
    let user = identity.email ? await this.prisma.user.findUnique({ where: { email: identity.email } }) : null;
    user ??= await this.prisma.user.create({ data: { email: identity.email, emailVerifiedAt: identity.emailVerified ? new Date() : null, status: UserStatus.ACTIVE } });
    await this.prisma.authIdentity.create({ data: { userId: user.id, provider: providerEnum, providerSubject: identity.subject } });
    return this.createTokenPair(user, context);
  }

  async verifyOtp(phone: string, code: string, context: ClientContext): Promise<TokenPair> {
    const normalized = phone.replace(/\s/g, '');
    const hash = await this.redis.get(`otp:${normalized}`);
    if (!hash || !(await argon2.verify(hash, code))) throw new UnauthorizedException('Invalid or expired code');
    await this.redis.del(`otp:${normalized}`);
    const user = await this.prisma.user.upsert({
      where: { phone: normalized },
      update: { phoneVerifiedAt: new Date(), status: UserStatus.ACTIVE },
      create: { phone: normalized, phoneVerifiedAt: new Date(), status: UserStatus.ACTIVE, identities: { create: { provider: IdentityProvider.PHONE, providerSubject: normalized } } }
    });
    return this.createTokenPair(user, context);
  }

  async issueVerification(userId: string, purpose: string): Promise<string> {
    const token = randomUUID();
    await this.prisma.verificationToken.create({ data: { userId, purpose, tokenHash: await argon2.hash(token), expiresAt: new Date(Date.now() + 30 * 60 * 1000) } });
    return token;
  }

  async consumeVerification(rawToken: string, purpose: string): Promise<void> {
    const candidates = await this.prisma.verificationToken.findMany({ where: { purpose, consumedAt: null, expiresAt: { gt: new Date() } }, include: { user: true } });
    const found = await this.findMatchingToken(candidates, rawToken);
    if (!found) throw new BadRequestException('Invalid or expired token');
    await this.prisma.$transaction([
      this.prisma.verificationToken.update({ where: { id: found.id }, data: { consumedAt: new Date() } }),
      this.prisma.user.update({ where: { id: found.userId }, data: purpose === 'EMAIL_VERIFY' ? { emailVerifiedAt: new Date() } : {} })
    ]);
  }

  async resetPassword(rawToken: string, password: string): Promise<void> {
    const candidates = await this.prisma.verificationToken.findMany({ where: { purpose: 'PASSWORD_RESET', consumedAt: null, expiresAt: { gt: new Date() } } });
    const found = await this.findMatchingToken(candidates, rawToken);
    if (!found) throw new BadRequestException('Invalid or expired token');
    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id: found.userId }, data: { passwordHash: await argon2.hash(password) } }),
      this.prisma.verificationToken.update({ where: { id: found.id }, data: { consumedAt: new Date() } }),
      this.prisma.refreshToken.updateMany({ where: { userId: found.userId, revokedAt: null }, data: { revokedAt: new Date() } })
    ]);
  }

  private async createTokenPair(user: Pick<User, 'id' | 'role'>, context: ClientContext, familyId: string = randomUUID(), replacedTokenId?: string): Promise<TokenPair> {
    const refreshId = randomUUID();
    const sid = familyId;
    const accessToken = await this.jwt.signAsync({ sub: user.id, role: user.role, sid, type: 'access' }, { secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'), expiresIn: this.ttlSeconds(this.config.get<string>('JWT_ACCESS_TTL', '15m')) });
    const refreshToken = await this.jwt.signAsync({ sub: user.id, jti: refreshId, fid: familyId, type: 'refresh' }, { secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'), expiresIn: this.ttlSeconds(this.config.get<string>('JWT_REFRESH_TTL', '30d')) });
    const decoded = this.jwt.decode<RefreshClaims>(refreshToken);
    await this.prisma.refreshToken.create({ data: { id: refreshId, userId: user.id, familyId, tokenHash: await argon2.hash(refreshToken), expiresAt: new Date(decoded.exp * 1000), userAgent: context.userAgent?.slice(0, 500), ipHash: context.ip ? createHash('sha256').update(context.ip).digest('hex') : null } });
    if (replacedTokenId) await this.prisma.refreshToken.update({ where: { id: replacedTokenId }, data: { replacedBy: refreshId } });
    return { accessToken, refreshToken, expiresIn: 900 };
  }

  private async findMatchingToken<T extends { tokenHash: string }>(tokens: T[], rawToken: string): Promise<T | undefined> {
    for (const token of tokens) if (await argon2.verify(token.tokenHash, rawToken)) return token;
    return undefined;
  }

  private ttlSeconds(value: string): number {
    const match = /^(\d+)([smhd])$/.exec(value);
    if (!match) throw new Error(`Invalid token TTL: ${value}`);
    const multipliers = { s: 1, m: 60, h: 3600, d: 86400 } as const;
    return Number(match[1]) * multipliers[match[2] as keyof typeof multipliers];
  }

  private async verifyGoogle(token: string) {
    const audience = this.config.getOrThrow<string>('GOOGLE_CLIENT_ID');
    const ticket = await new OAuth2Client(audience).verifyIdToken({ idToken: token, audience });
    const payload = ticket.getPayload();
    if (!payload?.sub) throw new UnauthorizedException('Invalid Google identity token');
    return { subject: payload.sub, email: payload.email?.toLowerCase(), emailVerified: Boolean(payload.email_verified) };
  }

  private async verifyApple(token: string) {
    const audience = this.config.getOrThrow<string>('APPLE_CLIENT_ID');
    const jwks = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));
    const { payload } = await jwtVerify(token, jwks, { issuer: 'https://appleid.apple.com', audience });
    if (!payload.sub) throw new UnauthorizedException('Invalid Apple identity token');
    return { subject: payload.sub, email: typeof payload.email === 'string' ? payload.email.toLowerCase() : undefined, emailVerified: payload.email_verified === true || payload.email_verified === 'true' };
  }
}
