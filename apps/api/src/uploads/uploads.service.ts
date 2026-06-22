import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HeadObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';
import { PrismaService } from '../database/prisma.service';

@Injectable()
export class UploadsService {
  private readonly s3: S3Client;
  private readonly presignS3: S3Client;
  private readonly bucket: string;
  constructor(private readonly config: ConfigService, private readonly prisma: PrismaService) {
    const endpoint = config.get<string>('S3_ENDPOINT');
    const presignEndpoint = config.get<string>('S3_PRESIGN_ENDPOINT') ?? endpoint;
    const region = config.get<string>('S3_REGION', 'us-west-2');
    this.s3 = new S3Client({ region, ...(endpoint ? { endpoint, forcePathStyle: true } : {}) });
    this.presignS3 = new S3Client({ region, ...(presignEndpoint ? { endpoint: presignEndpoint, forcePathStyle: true } : {}) });
    this.bucket = config.get<string>('S3_BUCKET', 'touchme-media');
  }
  async presign(userId: string, contentType: string, contentLength: number, purpose: 'profile' | 'message') {
    const extension = this.extension(contentType);
    const key = `${purpose}/${userId}/${new Date().toISOString().slice(0, 10)}/${randomUUID()}.${extension}`;
    const command = new PutObjectCommand({ Bucket: this.bucket, Key: key, ContentType: contentType, Metadata: { owner: userId, purpose, maximumBytes: String(contentLength) } });
    const domain = this.config.get<string>('CLOUDFRONT_DOMAIN');
    const publicBase = this.config.get<string>('S3_PUBLIC_URL');
    const publicUrl = domain ? `https://${domain}/${key}` : publicBase ? `${publicBase.replace(/\/$/, '')}/${this.bucket}/${key}` : `https://${this.bucket}.s3.${this.config.get('S3_REGION')}.amazonaws.com/${key}`;
    return { key, publicUrl, uploadUrl: await getSignedUrl(this.presignS3, command, { expiresIn: 300 }), expiresIn: 300, headers: { 'content-type': contentType } };
  }
  async completePhoto(userId: string, storageKey: string, position: number) {
    if (!storageKey.startsWith(`profile/${userId}/`)) throw new BadRequestException('Invalid storage key');
    const profile = await this.prisma.profile.findUnique({ where: { userId }, include: { photos: true } });
    if (!profile) throw new NotFoundException('Profile not found');
    if (profile.photos.length >= 9) throw new BadRequestException('Maximum photo count reached');
    const object = await this.s3.send(new HeadObjectCommand({ Bucket: this.bucket, Key: storageKey }));
    if (object.Metadata?.owner !== userId || object.Metadata?.purpose !== 'profile') throw new BadRequestException('Upload ownership metadata is invalid');
    const maximumBytes = Number(object.Metadata?.maximumbytes ?? 0);
    if (!object.ContentLength || object.ContentLength > 15_000_000 || (maximumBytes > 0 && object.ContentLength > maximumBytes)) throw new BadRequestException('Uploaded file size is invalid');
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(object.ContentType ?? '')) throw new BadRequestException('Uploaded profile media type is invalid');
    const domain = this.config.get<string>('CLOUDFRONT_DOMAIN');
    const publicBase = this.config.get<string>('S3_PUBLIC_URL');
    const url = domain ? `https://${domain}/${storageKey}` : publicBase ? `${publicBase.replace(/\/$/, '')}/${this.bucket}/${storageKey}` : `https://${this.bucket}.s3.${this.config.get('S3_REGION')}.amazonaws.com/${storageKey}`;
    return this.prisma.photo.create({
      data: {
        profileId: profile.id,
        storageKey,
        url,
        position,
        status: this.config.get('NODE_ENV') === 'development' ? 'APPROVED' : 'PENDING',
      },
    });
  }

  async uploadProfilePhotoDirect(userId: string, contentType: string, position: number, body: Buffer) {
    if (body.length > 15_000_000) throw new BadRequestException('Uploaded file size is invalid');
    const extension = this.extension(contentType);
    const storageKey = `profile/${userId}/${new Date().toISOString().slice(0, 10)}/${randomUUID()}.${extension}`;
    await this.s3.send(new PutObjectCommand({
      Bucket: this.bucket,
      Key: storageKey,
      Body: body,
      ContentType: contentType,
      Metadata: { owner: userId, purpose: 'profile', maximumBytes: String(body.length) },
    }));
    return this.completePhoto(userId, storageKey, position);
  }
  private extension(contentType: string) {
    const extensions: Record<string, string> = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'audio/aac': 'aac', 'audio/m4a': 'm4a', 'audio/mpeg': 'mp3' };
    const extension = extensions[contentType];
    if (!extension) throw new BadRequestException('Unsupported media type');
    return extension;
  }
}
