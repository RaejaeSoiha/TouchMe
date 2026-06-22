import { plainToInstance, Type } from 'class-transformer';
import { IsIn, IsInt, IsNotEmpty, IsOptional, IsString, Max, Min, validateSync } from 'class-validator';

class Environment {
  @IsIn(['development', 'test', 'production']) NODE_ENV = 'development';
  @Type(() => Number) @IsInt() @Min(1) @Max(65535) API_PORT = 3000;
  @IsString() @IsNotEmpty() DATABASE_URL!: string;
  @IsString() @IsNotEmpty() REDIS_URL!: string;
  @IsString() @IsNotEmpty() JWT_ACCESS_SECRET!: string;
  @IsString() @IsNotEmpty() JWT_REFRESH_SECRET!: string;
  @IsString() JWT_ACCESS_TTL = '15m';
  @IsString() JWT_REFRESH_TTL = '30d';
  @IsString() APP_ORIGINS = 'http://localhost:3001';
  @IsString() S3_BUCKET = 'touchme-media';
  @IsString() S3_REGION = 'us-west-2';
  @IsOptional() @IsString() CLOUDFRONT_DOMAIN?: string;
  @IsOptional() @IsString() STRIPE_SECRET_KEY?: string;
  @IsOptional() @IsString() STRIPE_WEBHOOK_SECRET?: string;
  @IsOptional() @IsString() STRIPE_PREMIUM_PRICE_ID?: string;
  @IsOptional() @IsString() GOOGLE_CLIENT_ID?: string;
  @IsOptional() @IsString() APPLE_CLIENT_ID?: string;
  @IsOptional() @IsString() SMTP_HOST?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(65535) SMTP_PORT?: number;
  @IsOptional() @IsString() SMTP_USER?: string;
  @IsOptional() @IsString() SMTP_PASSWORD?: string;
  @IsOptional() @IsString() SMTP_FROM?: string;
  @IsOptional() @IsString() FIREBASE_PROJECT_ID?: string;
  @IsOptional() @IsString() FIREBASE_CLIENT_EMAIL?: string;
  @IsOptional() @IsString() FIREBASE_PRIVATE_KEY?: string;
}

export function validateEnvironment(config: Record<string, unknown>): Environment {
  const validated = plainToInstance(Environment, config, { enableImplicitConversion: true });
  const errors = validateSync(validated, { skipMissingProperties: false });
  if (errors.length) throw new Error(errors.map((error) => error.toString()).join('\n'));
  if (validated.NODE_ENV === 'production' && (validated.JWT_ACCESS_SECRET.length < 64 || validated.JWT_REFRESH_SECRET.length < 64)) {
    throw new Error('Production JWT secrets must contain at least 64 characters');
  }
  if (validated.NODE_ENV === 'production') {
    const required = ['CLOUDFRONT_DOMAIN', 'STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET', 'STRIPE_PREMIUM_PRICE_ID', 'GOOGLE_CLIENT_ID', 'APPLE_CLIENT_ID', 'SMTP_HOST', 'SMTP_PORT', 'SMTP_USER', 'SMTP_PASSWORD', 'SMTP_FROM', 'FIREBASE_PROJECT_ID', 'FIREBASE_CLIENT_EMAIL', 'FIREBASE_PRIVATE_KEY'] as const;
    const missing = required.filter((key) => !validated[key]);
    if (missing.length) throw new Error(`Missing production environment variables: ${missing.join(', ')}`);
    if (validated.APP_ORIGINS.split(',').some((origin) => !origin.trim().startsWith('https://'))) throw new Error('Production APP_ORIGINS must use HTTPS');
  }
  return validated;
}
