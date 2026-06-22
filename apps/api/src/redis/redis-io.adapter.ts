import { INestApplicationContext } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';
import { Server, ServerOptions } from 'socket.io';
export class RedisIoAdapter extends IoAdapter {
  private adapterConstructor?: ReturnType<typeof createAdapter>;
  constructor(private readonly appContext: INestApplicationContext) { super(appContext); }
  async connect(): Promise<void> { const url = this.appContext.get(ConfigService).getOrThrow<string>('REDIS_URL'); const pub = new Redis(url); const sub = pub.duplicate(); await Promise.all([pub.ping(), sub.ping()]); this.adapterConstructor = createAdapter(pub, sub); }
  override createIOServer(port: number, options?: ServerOptions): Server { const server = super.createIOServer(port, options) as unknown as Server; if (this.adapterConstructor) server.adapter(this.adapterConstructor); return server; }
}
