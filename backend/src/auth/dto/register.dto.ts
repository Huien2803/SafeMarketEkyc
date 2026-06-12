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
import {
  DISPLAY_NAME_MESSAGE,
  DISPLAY_NAME_PATTERN,
  STRONG_PASSWORD_MESSAGE,
  STRONG_PASSWORD_PATTERN,
  VN_PHONE_MESSAGE,
  VN_PHONE_PATTERN,
} from '../../common/validation.constants';

export class RegisterDto {
  @ApiProperty({
    example: '0912345678',
    description: 'Số điện thoại Việt Nam (10 chữ số, bắt đầu 0)',
  })
  @IsNotEmpty({ message: 'Số điện thoại không được trống' })
  @Matches(VN_PHONE_PATTERN, { message: VN_PHONE_MESSAGE })
  phoneNumber: string;

  @ApiProperty({ example: 'hien@huflit.edu.vn' })
  @IsEmail({}, { message: 'Email không hợp lệ' })
  email: string;

  @ApiProperty({
    example: 'MatKhau@123',
    description: STRONG_PASSWORD_MESSAGE,
  })
  @IsString()
  @Matches(STRONG_PASSWORD_PATTERN, { message: STRONG_PASSWORD_MESSAGE })
  @MaxLength(72, { message: 'Mật khẩu tối đa 72 ký tự' })
  password: string;

  @ApiProperty({ example: 'Trương Trí Hiền' })
  @IsNotEmpty({ message: 'Họ và tên không được trống' })
  @IsString()
  @MinLength(2, { message: 'Họ và tên tối thiểu 2 ký tự' })
  @MaxLength(100)
  @Matches(DISPLAY_NAME_PATTERN, { message: DISPLAY_NAME_MESSAGE })
  displayName: string;

  @ApiProperty({ example: 'TP.HCM', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  location?: string;
}
