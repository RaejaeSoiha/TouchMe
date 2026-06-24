import { BadRequestException, Injectable } from '@nestjs/common';
import { Gender, Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { FriendsService } from '../friends/friends.service';
import { PresenceService } from '../presence/presence.service';
import { DiscoveryQueryDto } from './dto/discovery.dto';

interface NearbyRow {
  id: string;
  displayName: string;
  birthDate: Date;
  bio: string | null;
  occupation: string | null;
  education: string | null;
  city: string | null;
  gender: Gender;
  distanceKm: number;
  sharedInterests: number;
}

@Injectable()
export class DiscoveryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly friends: FriendsService,
    private readonly presence: PresenceService,
  ) {}

  async discover(userId: string, query: DiscoveryQueryDto) {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile?.latitude || !profile.longitude || !profile.completedAt) {
      throw new BadRequestException('Complete profile and location before browsing nearby people');
    }

    const originLatitude = Number(profile.passportLatitude ?? profile.latitude);
    const originLongitude = Number(profile.passportLongitude ?? profile.longitude);
    const minAge = query.minAge ?? profile.minAge;
    const maxAge = query.maxAge ?? profile.maxAge;
    const maxDistanceKm = query.maxDistanceKm ?? profile.maxDistanceKm;
    const genders = query.genders?.length ? query.genders : profile.showMe;
    const offset = Math.max(0, Number.parseInt(query.cursor ?? '0', 10) || 0);
    const limit = query.limit;

    const rows = await this.prisma.$queryRaw<NearbyRow[]>(Prisma.sql`
      SELECT u.id, p."displayName", p."birthDate", p.bio, p.occupation, p.education, p.city, p.gender,
        ST_Distance(
          ST_SetSRID(ST_MakePoint(${originLongitude}, ${originLatitude}), 4326)::geography,
          ST_SetSRID(ST_MakePoint(p.longitude::double precision, p.latitude::double precision), 4326)::geography
        ) / 1000.0 AS "distanceKm",
        (SELECT COUNT(*)::int FROM "ProfileInterest" mine
          JOIN "ProfileInterest" theirs ON mine."interestId" = theirs."interestId"
          WHERE mine."profileId" = ${profile.id}::uuid AND theirs."profileId" = p.id) AS "sharedInterests"
      FROM "User" u
      JOIN "Profile" p ON p."userId" = u.id
      WHERE u.id <> ${userId}::uuid
        AND u.status = 'ACTIVE'
        AND p.discoverable = true
        AND p.latitude IS NOT NULL
        AND p.longitude IS NOT NULL
        AND p.gender = ANY(${genders}::"Gender"[])
        AND DATE_PART('year', AGE(p."birthDate")) BETWEEN ${minAge} AND ${maxAge}
        AND ST_DWithin(
          ST_SetSRID(ST_MakePoint(${originLongitude}, ${originLatitude}), 4326)::geography,
          ST_SetSRID(ST_MakePoint(p.longitude::double precision, p.latitude::double precision), 4326)::geography,
          ${maxDistanceKm * 1000}
        )
        AND NOT EXISTS (
          SELECT 1 FROM "Block" b
          WHERE (b."blockerId" = ${userId}::uuid AND b."blockedId" = u.id)
             OR (b."blockerId" = u.id AND b."blockedId" = ${userId}::uuid)
        )
      ORDER BY
        EXISTS (
          SELECT 1 FROM "Boost" b
          WHERE b."userId" = u.id AND b."endsAt" > NOW()
        ) DESC,
        "distanceKm" ASC,
        u.id ASC
      LIMIT ${limit + 1} OFFSET ${offset}
    `);

    const hasMore = rows.length > limit;
    const page = rows.slice(0, limit);
    const ids = page.map((row) => row.id);
    const profiles = await this.prisma.profile.findMany({
      where: { userId: { in: ids } },
      include: {
        photos: { where: { status: 'APPROVED' }, orderBy: { position: 'asc' } },
        interests: { include: { interest: true } },
      },
    });
    const byUser = new Map(profiles.map((candidate) => [candidate.userId, candidate]));
    const relations = await this.friends.relationMap(userId, ids);
    const presence = await this.presence.snapshot(ids);

    return {
      items: page.map((row) => {
        const status = presence.get(row.id);
        return {
          ...row,
          age: new Date().getFullYear() - row.birthDate.getFullYear(),
          profile: byUser.get(row.id),
          friendStatus: relations.get(row.id) ?? 'NONE',
          online: status?.online ?? false,
          lastActiveAt: status?.lastActiveAt ?? new Date(0),
        };
      }),
      nextCursor: hasMore ? String(offset + limit) : null,
      filters: { minAge, maxAge, maxDistanceKm, genders },
    };
  }
}
