import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsNotEmpty, IsOptional, IsString, Min } from 'class-validator';

export class CreateOrderDto {
  @ApiProperty({ example: 1 })
  @IsInt()
  @Min(1)
  productId: number;

  @ApiProperty({ example: '123 Nguyễn Huệ, Q1, TP.HCM' })
  @IsString()
  @IsNotEmpty()
  shippingAddress: string;

  @ApiProperty({ example: 'BANK_TRANSFER', required: false })
  @IsOptional()
  @IsString()
  paymentMethod?: string;

  @ApiProperty({ example: 'SHIP', required: false })
  @IsOptional()
  @IsString()
  deliveryMethod?: string;
}

export class ChangePaymentMethodDto {
  @ApiProperty({ example: 'ONLINE_ESCROW', required: false })
  @IsOptional()
  @IsString()
  paymentMethod?: string;

  @ApiProperty({ example: 'SHIP', required: false })
  @IsOptional()
  @IsString()
  deliveryMethod?: string;

  @ApiProperty({ example: '123 Nguyễn Huệ, Q1, TP.HCM', required: false })
  @IsOptional()
  @IsString()
  shippingAddress?: string;
}

export class CancelOrderDto {
  @ApiProperty({ example: 'Hủy đơn', required: false })
  @IsOptional()
  @IsString()
  reason?: string;
}

export class DisputeOrderDto {
  @ApiProperty({ example: 'NO_RECEIVE' })
  @IsString()
  @IsNotEmpty()
  type: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  note?: string;
}
