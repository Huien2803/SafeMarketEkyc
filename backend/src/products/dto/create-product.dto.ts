import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import {
  MAX_PRODUCT_DESCRIPTION,
  MIN_PRODUCT_CONDITION,
  MIN_PRODUCT_PRICE,
} from '../../common/validation.constants';

/** Form-data khi đăng tin kèm ảnh file (multipart) */
export class CreateProductDto {
  @ApiProperty({ example: 'iPhone 13 Pro Max 256GB' })
  @IsString()
  @IsNotEmpty()
  @Length(2, 255)
  title: string;

  @ApiProperty({
    example: 'Máy zin 100%, pin 92%, kèm hộp',
    maxLength: MAX_PRODUCT_DESCRIPTION,
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(MAX_PRODUCT_DESCRIPTION, {
    message: `Mô tả tối đa ${MAX_PRODUCT_DESCRIPTION} ký tự`,
  })
  description: string;

  @ApiProperty({ example: 15500000, minimum: MIN_PRODUCT_PRICE })
  @Type(() => Number)
  @IsInt()
  @Min(MIN_PRODUCT_PRICE, { message: 'Giá phải cao hơn 50.000đ' })
  price: number;

  @ApiProperty({
    example: 92,
    description: `Tình trạng ${MIN_PRODUCT_CONDITION}-100%`,
    minimum: MIN_PRODUCT_CONDITION,
  })
  @Type(() => Number)
  @IsInt()
  @Min(MIN_PRODUCT_CONDITION, {
    message: `Độ bền tối thiểu ${MIN_PRODUCT_CONDITION}%`,
  })
  @Max(100)
  conditionPct: number;

  @ApiProperty({ example: 1, description: 'categoryId từ GET /categories' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  categoryId: number;

  @ApiProperty({ required: false, example: 'Quận 1, TP.HCM' })
  @IsOptional()
  @IsString()
  @Length(0, 100)
  location?: string;
}

export class UploadImageResponseDto {
  @ApiProperty({ example: 1 })
  productId: number;

  @ApiProperty({ example: '/uploads/products/product-123456.jpg' })
  imageUrl: string;
}
