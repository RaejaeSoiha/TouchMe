import { MessageType } from '@prisma/client';
import { IsEnum, IsInt, IsOptional, IsString, IsUrl, IsUUID, Max, MaxLength, Min, ValidateIf } from 'class-validator';

export class SendMessageDto {
  @IsUUID() conversationId!: string;
  @IsUUID() clientId!: string;
  @IsEnum(MessageType) type!: MessageType;
  @ValidateIf((value: SendMessageDto) => value.type === MessageType.TEXT)
  @IsString()
  @MaxLength(4000)
  body?: string;
  @ValidateIf((value: SendMessageDto) => value.type === MessageType.IMAGE || value.type === MessageType.VOICE)
  @IsUrl({ require_protocol: true })
  mediaUrl?: string;
  @IsOptional() @IsInt() @Min(1) @Max(600) mediaSeconds?: number;
}

export class MessagePageDto {
  @IsOptional() @IsUUID() cursor?: string;
}

export class ReceiptDto {
  @IsUUID() messageId!: string;
  @IsEnum(['DELIVERED', 'READ']) status!: 'DELIVERED' | 'READ';
}
