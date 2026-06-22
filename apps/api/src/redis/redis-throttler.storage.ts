import { Inject, Injectable } from '@nestjs/common';
import { ThrottlerStorage } from '@nestjs/throttler';
import Redis from 'ioredis';
import { REDIS } from './redis.module';

@Injectable()
export class RedisThrottlerStorage implements ThrottlerStorage {
  constructor(@Inject(REDIS) private readonly redis: Redis) {}
  async increment(key: string, ttl: number, limit: number, blockDuration: number, throttlerName: string): Promise<{ totalHits: number; timeToExpire: number; isBlocked: boolean; timeToBlockExpire: number }> {
    const countKey = `throttle:${throttlerName}:${key}`; const blockKey = `${countKey}:blocked`;
    const result = await this.redis.eval(`
      local blocked = redis.call('PTTL', KEYS[2])
      if blocked > 0 then return {0, redis.call('PTTL', KEYS[1]), 1, blocked} end
      local hits = redis.call('INCR', KEYS[1])
      if hits == 1 then redis.call('PEXPIRE', KEYS[1], ARGV[1]) end
      local expires = redis.call('PTTL', KEYS[1])
      if hits > tonumber(ARGV[2]) then redis.call('SET', KEYS[2], '1', 'PX', ARGV[3]); return {hits, expires, 1, tonumber(ARGV[3])} end
      return {hits, expires, 0, 0}
    `, 2, countKey, blockKey, ttl, limit, blockDuration || ttl) as number[];
    return { totalHits: result[0] ?? 0, timeToExpire: result[1] ?? ttl, isBlocked: result[2] === 1, timeToBlockExpire: result[3] ?? 0 };
  }
}
