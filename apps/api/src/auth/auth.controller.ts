import { Body, Controller, Delete, HttpCode, HttpStatus, Post, Req } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser, Public, AuthUser } from '../common/auth-user';
import { AuthService } from './auth.service';
import { LoginDto, PasswordResetDto, PasswordResetRequestDto, RefreshDto, RequestOtpDto, SignupDto, SocialLoginDto, VerifyEmailDto, VerifyOtpDto } from './dto/auth.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}
  @Public() @Throttle({ default: { limit: 5, ttl: 60_000 } }) @Post('signup') signup(@Body() dto: SignupDto, @Req() request: FastifyRequest) { return this.auth.signup(dto, this.context(request)); }
  @Public() @Throttle({ default: { limit: 10, ttl: 60_000 } }) @HttpCode(HttpStatus.OK) @Post('login') login(@Body() dto: LoginDto, @Req() request: FastifyRequest) { return this.auth.login(dto, this.context(request)); }
  @Public() @HttpCode(HttpStatus.OK) @Post('refresh') refresh(@Body() dto: RefreshDto, @Req() request: FastifyRequest) { return this.auth.refresh(dto.refreshToken, this.context(request)); }
  @Post('logout') @HttpCode(HttpStatus.NO_CONTENT) logout(@CurrentUser() user: AuthUser) { return this.auth.logout(user.id, user.sessionId); }
  @Delete('account') @HttpCode(HttpStatus.NO_CONTENT) deleteAccount(@CurrentUser() user: AuthUser) { return this.auth.deleteAccount(user.id, user.sessionId); }
  @Public() @Throttle({ default: { limit: 5, ttl: 60_000 } }) @Post('otp/request') @HttpCode(HttpStatus.ACCEPTED) requestOtp(@Body() dto: RequestOtpDto) { return this.auth.requestOtp(dto.phone); }
  @Public() @Post('otp/verify') verifyOtp(@Body() dto: VerifyOtpDto, @Req() request: FastifyRequest) { return this.auth.verifyOtp(dto.phone, dto.code, this.context(request)); }
  @Public() @Post('email/verify') @HttpCode(HttpStatus.NO_CONTENT) verifyEmail(@Body() dto: VerifyEmailDto) { return this.auth.consumeVerification(dto.token, 'EMAIL_VERIFY'); }
  @Public() @Post('password/request') @HttpCode(HttpStatus.ACCEPTED) async requestReset(@Body() dto: PasswordResetRequestDto) {
    return this.auth.requestPasswordReset(dto.email);
  }
  @Public() @Post('password/reset') @HttpCode(HttpStatus.NO_CONTENT) resetPassword(@Body() dto: PasswordResetDto) { return this.auth.resetPassword(dto.token, dto.password); }
  @Public() @Post('social') social(@Body() dto: SocialLoginDto, @Req() request: FastifyRequest) { return this.auth.social(dto.provider, dto.identityToken, this.context(request)); }
  private context(request: FastifyRequest) { return { ip: request.ip, userAgent: request.headers['user-agent'] }; }
}
