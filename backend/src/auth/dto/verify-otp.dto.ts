import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, Length } from 'class-validator';

export class VerifyOtpDto {
  @ApiProperty({ example: 'hien@huflit.edu.vn' })
  @IsEmail({}, { message: 'Email không hợp lệ' })
  email: string;

  @ApiProperty({ example: '123456', description: 'Mã OTP 6 chữ số' })
  @IsString()
  @IsNotEmpty({ message: 'Vui lòng nhập mã OTP' })
  @Length(6, 6, { message: 'Mã OTP gồm 6 chữ số' })
  otp: string;
}

export class RequestOtpResponseDto {
  @ApiProperty({ example: 'hien@huflit.edu.vn' })
  email: string;

  @ApiProperty({ example: 300, description: 'Số giây mã OTP còn hiệu lực' })
  expiresInSeconds: number;

  @ApiProperty({ example: 'Đã gửi mã OTP tới email của bạn.' })
  message: string;

  @ApiProperty({
    required: false,
    description: 'Chỉ trả về khi dev và chưa cấu hình SMTP — dùng để test',
    example: '123456',
  })
  devOtp?: string;
}
