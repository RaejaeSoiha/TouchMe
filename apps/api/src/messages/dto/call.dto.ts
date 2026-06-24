import { IsBoolean, IsIn, IsObject, IsString, IsUUID } from 'class-validator';

export class CallOfferDto {
  @IsUUID() conversationId!: string;
  @IsUUID() callId!: string;
  @IsIn(['AUDIO', 'VIDEO']) media!: 'AUDIO' | 'VIDEO';
  @IsObject() offer!: Record<string, unknown>;
}

export class CallAnswerDto {
  @IsUUID() conversationId!: string;
  @IsUUID() callId!: string;
  @IsObject() answer!: Record<string, unknown>;
}

export class CallIceCandidateDto {
  @IsUUID() conversationId!: string;
  @IsUUID() callId!: string;
  @IsObject() candidate!: Record<string, unknown>;
}

export class CallEndDto {
  @IsUUID() conversationId!: string;
  @IsUUID() callId!: string;
  @IsString() reason!: string;
}

export class CallBusyDto {
  @IsUUID() conversationId!: string;
  @IsUUID() callId!: string;
  @IsBoolean() busy!: boolean;
}
