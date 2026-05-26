import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class LoginDto {
  @ApiProperty({
    example: 'hien@huflit.edu.vn',
    description: 'Email hoặc số điện thoại',
  })
  @IsString()
  @IsNotEmpty({ message: 'Email/SĐT không được trống' })
  identifier: string;

  @ApiProperty({ example: 'MatKhau@123' })
  @IsString()
  @MinLength(6)
  password: string;
}
