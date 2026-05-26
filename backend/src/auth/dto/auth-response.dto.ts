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

  @ApiProperty({ example: 'Bearer' })
  tokenType: string;

  @ApiProperty({ example: 604800, description: 'Số giây token có hiệu lực' })
  expiresIn: number;

  @ApiProperty({ type: AuthUserDto })
  user: AuthUserDto;
}
