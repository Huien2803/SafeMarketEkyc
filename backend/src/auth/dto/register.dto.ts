import { ApiProperty } from '@nestjs/swagger';
import {
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

export class RegisterDto {
  @ApiProperty({
    example: '0359599503',
    description: 'Số điện thoại Việt Nam (10 số)',
  })
  @IsNotEmpty({ message: 'Số điện thoại không được trống' })
  @Matches(/^(0|\+84)[0-9]{9,10}$/, {
    message: 'Số điện thoại không hợp lệ',
  })
  phoneNumber: string;

  @ApiProperty({ example: 'hien@huflit.edu.vn' })
  @IsEmail({}, { message: 'Email không hợp lệ' })
  email: string;

  @ApiProperty({
    example: 'MatKhau@123',
    description: 'Mật khẩu tối thiểu 6 ký tự',
  })
  @IsString()
  @MinLength(6, { message: 'Mật khẩu tối thiểu 6 ký tự' })
  @MaxLength(72, { message: 'Mật khẩu tối đa 72 ký tự' })
  password: string;

  @ApiProperty({ example: 'Trương Trí Hiền', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  displayName?: string;

  @ApiProperty({ example: 'TP.HCM', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  location?: string;
}
