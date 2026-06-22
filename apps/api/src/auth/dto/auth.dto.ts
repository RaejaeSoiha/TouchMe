import { IsEmail, IsIn, IsOptional, IsPhoneNumber, IsString, IsStrongPassword, IsUUID, Length } from 'class-validator';

export class SignupDto {
  @IsEmail() email!: string;
  @IsStrongPassword({ minLength: 10, minLowercase: 1, minUppercase: 1, minNumbers: 1, minSymbols: 1 }) password!: string;
}

export class LoginDto { @IsEmail() email!: string; @IsString() password!: string; }
export class RefreshDto { @IsString() refreshToken!: string; }
export class RequestOtpDto { @IsPhoneNumber() phone!: string; }
export class VerifyOtpDto { @IsPhoneNumber() phone!: string; @Length(6, 6) code!: string; }
export class PasswordResetRequestDto { @IsEmail() email!: string; }
export class PasswordResetDto { @IsUUID() token!: string; @IsStrongPassword({ minLength: 10 }) password!: string; }
export class VerifyEmailDto { @IsUUID() token!: string; }
export class SocialLoginDto {
  @IsIn(['google', 'apple']) provider!: 'google' | 'apple';
  @IsString() identityToken!: string;
  @IsOptional() @IsString() nonce?: string;
}

