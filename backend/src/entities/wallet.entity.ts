import {
  Column,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity({ schema: 'Finance', name: 'Wallets' })
export class Wallet {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'wallet_id' })
  walletId: number;

  @Column({ name: 'user_id', type: 'bigint', unique: true })
  userId: number;

  @Column({ name: 'balance', type: 'bigint', default: 0 })
  balance: number;

  @UpdateDateColumn({ name: 'updated_at', type: 'datetime2' })
  updatedAt: Date;
}
