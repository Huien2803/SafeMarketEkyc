import { ApiProperty } from '@nestjs/swagger';

export class EkycStatusDto {
  @ApiProperty({ example: 'Verified', enum: ['Unverified', 'Pending', 'Verified', 'Rejected'] })
  status: string;

  @ApiProperty({ example: 'NGUYỄN VĂN AN', nullable: true })
  fullName: string | null;

  @ApiProperty({ example: '079203xxxxxx', nullable: true, description: 'Đã che bớt' })
  idNumber: string | null;

  @ApiProperty({ example: '1998-05-15', nullable: true })
  dob: string | null;

  @ApiProperty({ nullable: true })
  address: string | null;

  @ApiProperty({ example: '2026-05-26T18:00:00.000Z', nullable: true })
  submittedAt: Date | null;

  @ApiProperty({ example: '2026-05-26T18:00:30.000Z', nullable: true })
  verifiedAt: Date | null;

  @ApiProperty({ nullable: true, description: 'Lý do bị từ chối nếu status = Rejected' })
  rejectionReason: string | null;
}
