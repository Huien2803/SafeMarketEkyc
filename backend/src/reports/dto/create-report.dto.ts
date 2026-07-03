import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export const REPORT_CATEGORIES = [
  'SCAM',
  'FAKE_OR_BANNED',
  'MISLEADING',
  'OFFENSIVE_SPAM',
  'HARASSMENT',
  'OTHER',
] as const;

export type ReportCategory = (typeof REPORT_CATEGORIES)[number];

export class CreateReportDto {
  @ApiProperty({ description: 'ID người bị báo cáo' })
  @Type(() => Number)
  @IsInt()
  reportedId: number;

  @ApiProperty({
    enum: REPORT_CATEGORIES,
    description: 'Loại vi phạm',
  })
  @IsString()
  @IsIn([...REPORT_CATEGORIES])
  category: ReportCategory;

  @ApiProperty({ description: 'Mô tả chi tiết vi phạm' })
  @IsString()
  @IsNotEmpty({ message: 'Mô tả vi phạm không được trống' })
  @MinLength(10, { message: 'Mô tả tối thiểu 10 ký tự' })
  @MaxLength(500)
  detail: string;

  @ApiPropertyOptional({ description: 'ID sản phẩm (nếu báo cáo bài đăng)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  productId?: number;

  @ApiPropertyOptional({ enum: ['low', 'medium', 'high'] })
  @IsOptional()
  @IsIn(['low', 'medium', 'high'])
  severity?: string;
}
