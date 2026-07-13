import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class RefreshTokenDto {
  @ApiProperty({ description: 'Opaque refresh token nhận từ login' })
  @IsString()
  @IsNotEmpty()
  @MinLength(32)
  refreshToken: string;
}

export class LogoutDto {
  @ApiProperty({ description: 'Refresh token cần thu hồi' })
  @IsString()
  @IsNotEmpty()
  @MinLength(32)
  refreshToken: string;
}
