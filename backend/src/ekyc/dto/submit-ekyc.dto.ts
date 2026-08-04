import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * Submit eKYC — dữ liệu CCCD lấy từ session server (không tin client bịa số CCCD).
 * Client chỉ gửi sessionId + livenessToken + bổ sung dob/address nếu OCR thiếu.
 */
export class SubmitEkycDto {
  @ApiProperty({ example: 'a1b2c3...' })
  @IsString()
  @IsNotEmpty()
  sessionId: string;

  @ApiProperty({
    example: 'ekyc.a1b2....',
    description: 'Token do server phát sau bước Face ID',
  })
  @IsString()
  @IsNotEmpty()
  livenessToken: string;

  @ApiPropertyOptional({
    example: '1998-05-15',
    description: 'Bổ sung nếu OCR thiếu — dd/MM/yyyy hoặc yyyy-MM-dd',
  })
  @IsOptional()
  @IsString()
  dob?: string;

  @ApiPropertyOptional({ example: '123 Lê Lợi, Quận 1, TP.HCM' })
  @IsOptional()
  @IsString()
  @Length(0, 255)
  address?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(0, 255)
  home?: string;

  /** Tương thích ngược — bị bỏ qua nếu có session hợp lệ */
  @ApiPropertyOptional({ deprecated: true })
  @IsOptional()
  @IsString()
  idNumber?: string;

  @ApiPropertyOptional({ deprecated: true })
  @IsOptional()
  @IsString()
  fullName?: string;

  @ApiPropertyOptional({ deprecated: true })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  faceSimilarity?: number;

  @ApiPropertyOptional({ deprecated: true })
  @IsOptional()
  @IsNumber()
  @Min(0)
  recognitionPoints?: number;
}

export class StartSessionResponseDto {
  @ApiProperty()
  sessionId: string;

  @ApiProperty()
  expiresAt: string;
}

export class CompleteLivenessDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  sessionId: string;

  @ApiProperty({ example: 25 })
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  recognitionPoints: number;
}
