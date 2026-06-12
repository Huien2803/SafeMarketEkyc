import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MinLength, ValidateIf } from 'class-validator';

export class LoginDto {
  @ApiProperty({
    example: 'hien@huflit.edu.vn',
    description: 'Email hoặc số điện thoại',
    required: false,
  })
  @ValidateIf((o: LoginDto) => !o.email)
  @IsString()
  @IsNotEmpty({ message: 'Email/SĐT không được trống' })
  identifier?: string;

  /** Flutter gửi { email, password } — tương thích Java API */
  @ApiProperty({ required: false, example: 'hien@huflit.edu.vn' })
  @ValidateIf((o: LoginDto) => !o.identifier)
  @IsString()
  @IsNotEmpty({ message: 'Email/SĐT không được trống' })
  email?: string;

  @ApiProperty({ example: 'MatKhau@123' })
  @IsString()
  @MinLength(6)
  password: string;
}
