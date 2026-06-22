import { Test } from '@nestjs/testing';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
jest.mock('jose', () => ({ createRemoteJWKSet: jest.fn(), jwtVerify: jest.fn() }));
import { AppModule } from '../src/app.module';
describe('health', () => {
  let app: NestFastifyApplication;
  beforeAll(async () => { const module = await Test.createTestingModule({ imports: [AppModule] }).compile(); app = module.createNestApplication<NestFastifyApplication>(new FastifyAdapter()); await app.init(); await app.getHttpAdapter().getInstance().ready(); });
  afterAll(() => app.close());
  it('reports liveness', async () => { const response = await app.inject({ method: 'GET', url: '/health/live' }); expect(response.statusCode).toBe(200); });
});
