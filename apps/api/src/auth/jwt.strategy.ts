import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { UserStatus } from '@prisma/client';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { AuthUser } from '../common/auth-user';
import { PrismaService } from '../database/prisma.service';

interface AccessClaims { sub: string; role: AuthUser['role']; sid: string; type: 'access' }

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService, private readonly prisma: PrismaService) {
    super({ jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(), secretOrKey: config.getOrThrow<string>('JWT_ACCESS_SECRET') });
  }
  async validate(claims: AccessClaims): Promise<AuthUser> {
    if (claims.type !== 'access') throw new UnauthorizedException();
    const user = await this.prisma.user.findUnique({ where: { id: claims.sub }, select: { id: true, role: true, status: true } });
    if (!user || user.status !== UserStatus.ACTIVE) throw new UnauthorizedException('Account is not active');
    return { id: user.id, role: user.role, sessionId: claims.sid };
  }
}

