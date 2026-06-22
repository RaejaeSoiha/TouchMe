import { Test } from '@nestjs/testing';
jest.mock('jose', () => ({ createRemoteJWKSet: jest.fn(), jwtVerify: jest.fn() }));
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { PrismaService } from '../database/prisma.service';
import { CommunicationsService } from '../communications/communications.service';
import { REDIS } from '../redis/redis.module';

describe('AuthService', () => {
  it('normalizes email and rejects duplicate registration', async () => {
    const prisma = { user: { findUnique: jest.fn().mockResolvedValue({ id: 'existing' }) } };
    const module = await Test.createTestingModule({ providers: [AuthService, { provide: PrismaService, useValue: prisma }, { provide: JwtService, useValue: {} }, { provide: ConfigService, useValue: {} }, { provide: CommunicationsService, useValue: {} }, { provide: REDIS, useValue: {} }] }).compile();
    await expect(module.get(AuthService).signup({ email: ' EXISTING@example.com ', password: 'Valid!Password1' }, {})).rejects.toThrow('Email already registered');
    expect(prisma.user.findUnique).toHaveBeenCalledWith({ where: { email: 'existing@example.com' } });
  });
});
