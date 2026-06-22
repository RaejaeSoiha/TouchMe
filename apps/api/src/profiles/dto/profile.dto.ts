import { Gender } from '@prisma/client';
import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsBoolean, IsDateString, IsEnum, IsInt, IsLatitude, IsLongitude, IsOptional, IsString, IsUUID, Length, Max, MaxLength, Min } from 'class-validator';

export class UpsertProfileDto {
  @IsString() @Length(2, 60) displayName!: string;
  @IsDateString() birthDate!: string;
  @IsEnum(Gender) gender!: Gender;
  @IsArray() @ArrayMinSize(1) @IsEnum(Gender, { each: true }) showMe!: Gender[];
  @IsOptional() @IsString() @MaxLength(1000) bio?: string;
  @IsOptional() @IsString() @MaxLength(120) occupation?: string;
  @IsOptional() @IsString() @MaxLength(120) education?: string;
  @IsOptional() @IsString() @MaxLength(120) city?: string;
  @IsOptional() @IsString() @Length(2, 2) countryCode?: string;
  @Type(() => Number) @IsInt() @Min(18) @Max(120) minAge!: number;
  @Type(() => Number) @IsInt() @Min(18) @Max(120) maxAge!: number;
  @Type(() => Number) @IsInt() @Min(1) @Max(1000) maxDistanceKm!: number;
  @IsOptional() @IsBoolean() discoverable?: boolean;
  @IsArray() @ArrayMaxSize(20) @IsUUID('4', { each: true }) interestIds!: string[];
}

export class UpdateLocationDto {
  @Type(() => Number) @IsLatitude() latitude!: number;
  @Type(() => Number) @IsLongitude() longitude!: number;
}
export class PassportLocationDto {
  @Type(() => Number) @IsLatitude() latitude!: number;
  @Type(() => Number) @IsLongitude() longitude!: number;
}

export class ReorderPhotosDto {
  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(9) @IsUUID('4', { each: true }) photoIds!: string[];
}
