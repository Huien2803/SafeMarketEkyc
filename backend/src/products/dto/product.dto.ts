import { ApiProperty } from '@nestjs/swagger';

export class ProductSellerDto {
  @ApiProperty({ example: 1 })
  userId: number;

  @ApiProperty({ example: 'Nguyễn Văn An' })
  displayName: string;

  @ApiProperty({ example: '0912345678' })
  phoneNumber: string;

  @ApiProperty({ example: 'Verified' })
  kycStatus: string;

  @ApiProperty({ example: 850, nullable: true })
  trustScore: number | null;

  @ApiProperty({ example: 'Gold', nullable: true })
  rankLevel: string | null;

  @ApiProperty({ example: 'Quận 1, TP. HCM', nullable: true })
  location: string | null;
}

export class ProductListItemDto {
  @ApiProperty({ example: 1 })
  productId: number;

  @ApiProperty({ example: 'iPhone 13 Pro Max - 256GB' })
  title: string;

  @ApiProperty({ example: 15500000 })
  price: number;

  @ApiProperty({ example: 92 })
  conditionPct: number;

  @ApiProperty({ example: 'Available' })
  status: string;

  @ApiProperty({ example: 'Quận 1, TP. HCM', nullable: true })
  location: string | null;

  @ApiProperty({ example: '/uploads/products/iphone13.jpg', nullable: true })
  thumbnailUrl: string | null;

  @ApiProperty({ example: '2026-05-26T10:00:00.000Z' })
  createdAt: Date;

  @ApiProperty({ example: 'Điện tử' })
  categoryName: string;

  @ApiProperty({ type: ProductSellerDto })
  seller: ProductSellerDto;
}

export class ProductDetailDto extends ProductListItemDto {
  @ApiProperty({ example: 'Máy zin 100%, pin 92%...' })
  description: string;

  @ApiProperty({ example: 1 })
  categoryId: number;

  @ApiProperty({ type: [String], example: ['/uploads/products/iphone13.jpg'] })
  images: string[];
}

export class ProductListResponseDto {
  @ApiProperty({ type: [ProductListItemDto] })
  items: ProductListItemDto[];

  @ApiProperty({ example: 12 })
  total: number;

  @ApiProperty({ example: 1 })
  page: number;

  @ApiProperty({ example: 20 })
  limit: number;
}
