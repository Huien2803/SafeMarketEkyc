import {
  Column,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';

@Entity({ schema: 'Identity', name: 'eKYC_Profiles' })
export class EkycProfile {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'kyc_id' })
  kycId: number;

  @Column({ name: 'id_number', type: 'varchar', length: 20, nullable: true })
  idNumber: string | null;

  @Column({ name: 'full_name', type: 'nvarchar', length: 100, nullable: true })
  fullName: string | null;

  @Column({ name: 'dob', type: 'date', nullable: true })
  dob: Date | null;

  @Column({ name: 'address', type: 'nvarchar', length: 255, nullable: true })
  address: string | null;

  @Column({
    name: 'id_front_url',
    type: 'varchar',
    length: 500,
    nullable: true,
  })
  idFrontUrl: string | null;

  @Column({ name: 'id_back_url', type: 'varchar', length: 500, nullable: true })
  idBackUrl: string | null;

  @Column({
    name: 'face_video_url',
    type: 'varchar',
    length: 500,
    nullable: true,
  })
  faceVideoUrl: string | null;

  @Column({ name: 'submitted_at', type: 'datetime2', nullable: true })
  submittedAt: Date | null;

  @Column({ name: 'verified_at', type: 'datetime2', nullable: true })
  verifiedAt: Date | null;

  @Column({
    name: 'rejection_reason',
    type: 'nvarchar',
    length: 500,
    nullable: true,
  })
  rejectionReason: string | null;

  @Column({ name: 'user_id', type: 'bigint' })
  userId: number;

  @OneToOne(() => User, (user) => user.ekycProfile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;
}
