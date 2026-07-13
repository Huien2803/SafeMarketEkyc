import { ApiProperty } from '@nestjs/swagger';

export class AuthUserDto {
  @ApiProperty({ example: 1 })
  userId: number;

  @ApiProperty({ example: 'hien@huflit.edu.vn' })
  email: string;

  @ApiProperty({ example: '0359599503' })
  phoneNumber: string;

  @ApiProperty({ example: 'Trương Trí Hiền', nullable: true })
  displayName: string | null;

  @ApiProperty({ example: 'Unverified' })
  kycStatus: string;

  @ApiProperty({ example: 'Active' })
  accountStatus: string;

  @ApiProperty({ example: false })
  isAdmin: boolean;
}

export class AuthResponseDto {
  @ApiProperty({ example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...' })
  accessToken: string;

  @ApiProperty({
    example: 'a1b2c3d4e5f6...',
    description: 'Opaque refresh token — lưu an toàn, dùng để lấy access mới',
  })
  refreshToken: string;

  @ApiProperty({ example: 'Bearer' })
  tokenType: string;

  @ApiProperty({ example: 900, description: 'Số giây access token còn hiệu lực' })
  expiresIn: number;

  @ApiProperty({ type: AuthUserDto })
  user: AuthUserDto;
}
