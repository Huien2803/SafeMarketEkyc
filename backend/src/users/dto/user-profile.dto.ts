import { ApiProperty } from '@nestjs/swagger';

export class TrustScoreDto {
  @ApiProperty({ example: 500, minimum: 0, maximum: 1000 })
  currentPoint: number;

  @ApiProperty({ example: 1000 })
  maxPoint: number;

  @ApiProperty({ example: 'Bronze', enum: ['Bronze', 'Silver', 'Gold', 'Diamond'] })
  rankLevel: string;

  @ApiProperty({ example: '2026-04-10T03:21:00.000Z' })
  updatedAt: Date;
}

export class EkycSummaryDto {
  @ApiProperty({ example: 'Verified' })
  status: string;

  @ApiProperty({ example: 'Trương Trí Hiền', nullable: true })
  fullName: string | null;

  @ApiProperty({ example: '079202xxxxxx', nullable: true })
  idNumber: string | null;

  @ApiProperty({ example: '2026-04-10T03:21:00.000Z', nullable: true })
  verifiedAt: Date | null;
}

export class UserProfileDto {
  @ApiProperty({ example: 1 })
  userId: number;

  @ApiProperty({ example: 'hien@huflit.edu.vn' })
  email: string;

  @ApiProperty({ example: '0359599503' })
  phoneNumber: string;

  @ApiProperty({ example: 'Trương Trí Hiền', nullable: true })
  displayName: string | null;

  @ApiProperty({ example: 'TP.HCM', nullable: true })
  location: string | null;

  @ApiProperty({ example: null, nullable: true })
  avatarUrl: string | null;

  @ApiProperty({ example: 'Active' })
  accountStatus: string;

  @ApiProperty({ example: false })
  isAdmin: boolean;

  @ApiProperty({ example: '2026-04-10T03:21:00.000Z' })
  createdAt: Date;

  @ApiProperty({ type: TrustScoreDto, nullable: true })
  trustScore: TrustScoreDto | null;

  @ApiProperty({ type: EkycSummaryDto })
  ekyc: EkycSummaryDto;

  @ApiProperty({ example: 2 })
  activeListingCount: number;

  @ApiProperty({ example: 1 })
  soldCount: number;

  @ApiProperty({ example: 3 })
  boughtCount: number;

  @ApiProperty({ example: 5 })
  reviewCount: number;

  @ApiProperty({ example: 4.5 })
  averageRating: number;

  @ApiProperty({ example: 12 })
  followerCount: number;

  @ApiProperty({ example: 5 })
  followingCount: number;

  @ApiProperty({ example: false })
  isFollowing: boolean;
}
