import { ApiProperty } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
} from 'class-validator';

/**
 * Body khi user xác nhận thông tin eKYC đã chụp xong và muốn lưu vào hệ thống.
 * Frontend sẽ gọi /api/ekyc/submit sau khi đã chạy 2 bước scan-id + face-match.
 */
export class SubmitEkycDto {
  @ApiProperty({ example: '079203001234' })
  @IsString()
  @IsNotEmpty()
  @Length(9, 20)
  idNumber: string;

  @ApiProperty({ example: 'NGUYỄN VĂN AN' })
  @IsString()
  @IsNotEmpty()
  @Length(2, 100)
  fullName: string;

  @ApiProperty({ example: '1998-05-15', description: 'Ngày sinh ISO yyyy-MM-dd' })
  @IsString()
  @IsNotEmpty()
  dob: string;

  @ApiProperty({ example: '123 Lê Lợi, Quận 1, TP.HCM' })
  @IsString()
  @IsNotEmpty()
  @Length(2, 255)
  address: string;

  @ApiProperty({
    example: 0.92,
    description: 'Điểm similarity từ face match (0..1)',
  })
  @IsNumber()
  @Min(0)
  @Max(1)
  faceSimilarity: number;

  @ApiProperty({ required: false, example: '/uploads/kyc/1/front.jpg' })
  @IsOptional()
  @IsString()
  idFrontUrl?: string;

  @ApiProperty({ required: false, example: '/uploads/kyc/1/back.jpg' })
  @IsOptional()
  @IsString()
  idBackUrl?: string;

  @ApiProperty({ required: false, example: '/uploads/kyc/1/selfie.jpg' })
  @IsOptional()
  @IsString()
  selfieUrl?: string;

  @ApiProperty({ required: false, description: 'Token từ bước liveness-check' })
  @IsOptional()
  @IsString()
  livenessToken?: string;
}
