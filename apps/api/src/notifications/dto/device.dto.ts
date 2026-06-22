import { IsIn, IsString, MaxLength } from 'class-validator';
export class RegisterDeviceDto { @IsIn(['ios', 'android']) platform!: string; @IsString() @MaxLength(4096) pushToken!: string; }

