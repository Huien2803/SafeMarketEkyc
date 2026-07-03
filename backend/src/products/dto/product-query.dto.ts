import { ApiProperty } from '@nestjs/swagger';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';

export enum ProductSort {
  NEWEST = 'newest',
  OLDEST = 'oldest',
  PRICE_ASC = 'price_asc',
  PRICE_DESC = 'price_desc',
}

export class ProductQueryDto {
  @ApiProperty({ required: false, example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  categoryId?: number;

  @ApiProperty({ required: false, example: 'iphone' })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiProperty({ required: false, example: true })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  verifiedOnly?: boolean;

  @ApiProperty({ required: false, example: 100000 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  minPrice?: number;

  @ApiProperty({ required: false, example: 5000000 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  maxPrice?: number;

  @ApiProperty({ required: false, example: 'TP. Hồ Chí Minh' })
  @IsOptional()
  @IsString()
  location?: string;

  @ApiProperty({
    required: false,
    enum: ProductSort,
    default: ProductSort.NEWEST,
  })
  @IsOptional()
  @IsEnum(ProductSort)
  sort?: ProductSort;
}
