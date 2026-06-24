import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { UpsertProfileDto } from './dto/profile.dto';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';

const CITY_COORDINATES: Record<string, [number, number]> = {
  phoenix: [33.4484, -112.074],
  denver: [39.7392, -104.9903],
  'new york': [40.7128, -74.006],
  chicago: [41.8781, -87.6298],
  seattle: [47.6062, -122.3321],
  austin: [30.2672, -97.7431],
  miami: [25.7617, -80.1918],
};

@Injectable()
export class ProfilesService {
  constructor(private readonly prisma: PrismaService, private readonly subscriptions: SubscriptionsService) {}

  me(userId: string) {
    const statuses = process.env.NODE_ENV === 'development' ? (['APPROVED', 'PENDING'] as const) : (['APPROVED'] as const);
    return this.prisma.profile.findUnique({
      where: { userId },
      include: {
        photos: { where: { status: { in: [...statuses] } }, orderBy: { position: 'asc' } },
        interests: { include: { interest: true } },
      },
    });
  }

  private coordinatesForCity(city?: string): [number, number] {
    const key = city?.trim().toLowerCase() ?? '';
    return CITY_COORDINATES[key] ?? [39.7392, -104.9903];
  }

  async upsert(userId: string, dto: UpsertProfileDto) {
    const birthDate = new Date(dto.birthDate);
    const adultCutoff = new Date(); adultCutoff.setFullYear(adultCutoff.getFullYear() - 18);
    if (birthDate > adultCutoff) throw new BadRequestException('You must be at least 18 years old');
    if (dto.minAge > dto.maxAge) throw new BadRequestException('Minimum age cannot exceed maximum age');
    const [latitude, longitude] = this.coordinatesForCity(dto.city);
    const data = {
      displayName: dto.displayName.trim(), birthDate, gender: dto.gender, showMe: dto.showMe,
      bio: dto.bio?.trim(), occupation: dto.occupation?.trim(), education: dto.education?.trim(), city: dto.city?.trim(),
      countryCode: dto.countryCode?.toUpperCase(), minAge: dto.minAge, maxAge: dto.maxAge,
      maxDistanceKm: dto.maxDistanceKm, discoverable: dto.discoverable ?? true, completedAt: new Date(),
      latitude, longitude,
    };
    return this.prisma.profile.upsert({
      where: { userId },
      create: { userId, ...data, interests: { create: dto.interestIds.map((interestId) => ({ interestId })) } },
      update: { ...data, interests: { deleteMany: {}, create: dto.interestIds.map((interestId) => ({ interestId })) } },
      include: { photos: true, interests: { include: { interest: true } } }
    });
  }

  async updateLocation(userId: string, latitude: number, longitude: number) {
    try { return await this.prisma.profile.update({ where: { userId }, data: { latitude, longitude } }); }
    catch { throw new NotFoundException('Complete your profile before updating location'); }
  }

  interests() { return this.prisma.interest.findMany({ where: { active: true }, orderBy: { label: 'asc' } }); }

  async publicProfile(viewerId: string, userId: string) {
    const blocked = await this.prisma.block.findFirst({
      where: {
        OR: [
          { blockerId: viewerId, blockedId: userId },
          { blockerId: userId, blockedId: viewerId },
        ],
      },
    });
    if (blocked) throw new NotFoundException('Profile not found');
    const profile = await this.prisma.profile.findUnique({
      where: { userId },
      include: {
        photos: { where: { status: 'APPROVED' }, orderBy: { position: 'asc' } },
        interests: { include: { interest: true } },
      },
    });
    if (!profile) throw new NotFoundException('Profile not found');
    return profile;
  }

  async passport(userId: string, latitude: number, longitude: number) { const plan = await this.subscriptions.entitlements(userId); if (!plan?.passportMode) throw new BadRequestException('Passport mode requires Premium'); return this.prisma.profile.update({ where: { userId }, data: { passportLatitude: latitude, passportLongitude: longitude } }); }

  async reorderPhotos(userId: string, photoIds: string[]) {
    const profile = await this.prisma.profile.findUnique({ where: { userId }, include: { photos: true } });
    if (!profile || photoIds.some((id) => !profile.photos.some((photo) => photo.id === id))) throw new BadRequestException('Invalid photo list');
    await this.prisma.$transaction(photoIds.map((id, position) => this.prisma.photo.update({ where: { id }, data: { position: position + 100 } })));
    await this.prisma.$transaction(photoIds.map((id, position) => this.prisma.photo.update({ where: { id }, data: { position } })));
    return this.me(userId);
  }

  async removePhoto(userId: string, photoId: string) {
    const result = await this.prisma.photo.deleteMany({ where: { id: photoId, profile: { userId } } });
    if (!result.count) throw new NotFoundException('Photo not found');
  }
}
