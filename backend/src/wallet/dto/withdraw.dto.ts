import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsNotEmpty, IsString, MaxLength, Min } from 'class-validator';

export class CreateWithdrawalDto {
  @ApiProperty({ example: 500000, description: 'Số tiền muốn rút (VND)' })
  @IsInt()
  @Min(10000, { message: 'Số tiền rút tối thiểu 10.000đ' })
  amount: number;

  @ApiProperty({ example: 'Vietcombank' })
  @IsString()
  @IsNotEmpty({ message: 'Vui lòng nhập tên ngân hàng' })
  @MaxLength(100)
  bankName: string;

  @ApiProperty({ example: '0123456789' })
  @IsString()
  @IsNotEmpty({ message: 'Vui lòng nhập số tài khoản' })
  @MaxLength(50)
  bankAccount: string;

  @ApiProperty({ example: 'TRUONG TRI HIEN' })
  @IsString()
  @IsNotEmpty({ message: 'Vui lòng nhập tên chủ tài khoản' })
  @MaxLength(100)
  accountHolder: string;
}
