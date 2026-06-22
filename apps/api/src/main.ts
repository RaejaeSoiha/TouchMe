import { Logger, ValidationPipe, VersioningType } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import cookie from '@fastify/cookie';
import helmet from '@fastify/helmet';
import { AppModule } from './app.module';
import { resolveCorsOrigins } from './config/cors';
import { RedisIoAdapter } from './redis/redis-io.adapter';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({ trustProxy: true, bodyLimit: 20 * 1024 * 1024 }),
    { rawBody: true },
  );
  const config = app.get(ConfigService);
  const socketAdapter = new RedisIoAdapter(app); await socketAdapter.connect(); app.useWebSocketAdapter(socketAdapter);
  const origins = config.get<string>('APP_ORIGINS', '').split(',').map((origin) => origin.trim()).filter(Boolean);
  const nodeEnv = config.get<string>('NODE_ENV', 'development');
  app.setGlobalPrefix('api');
  app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' });
  app.enableShutdownHooks();
  await app.register(helmet, { contentSecurityPolicy: { directives: { defaultSrc: ["'none'"], frameAncestors: ["'none'"] } }, crossOriginResourcePolicy: { policy: 'cross-origin' } });
  await app.register(cookie);
  app.enableCors({
    origin: resolveCorsOrigins(origins, nodeEnv),
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['authorization', 'content-type', 'x-csrf-token'],
  });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true, transformOptions: { enableImplicitConversion: true } }));
  const swaggerConfig = new DocumentBuilder().setTitle('TouchMe API').setDescription('Nearby people discovery, friends, and messaging API').setVersion('1.0').addBearerAuth().build();
  SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, swaggerConfig), { swaggerOptions: { persistAuthorization: false } });
  const port = config.get<number>('API_PORT', 3000);
  await app.listen(port, '0.0.0.0');
  Logger.log(`TouchMe API listening on ${port}`);
}
void bootstrap();
