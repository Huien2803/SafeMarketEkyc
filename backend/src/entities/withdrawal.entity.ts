import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

export type WithdrawalStatus = 'Pending' | 'Completed' | 'Rejected';

@Entity({ schema: 'Finance', name: 'Withdrawals' })
export class Withdrawal {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'withdrawal_id' })
  withdrawalId: number;

  @Column({ name: 'user_id', type: 'bigint' })
  userId: number;

  @Column({ name: 'amount', type: 'bigint' })
  amount: number;

  @Column({ name: 'bank_name', type: 'nvarchar', length: 100 })
  bankName: string;

  @Column({ name: 'bank_account', type: 'varchar', length: 50 })
  bankAccount: string;

  @Column({ name: 'account_holder', type: 'nvarchar', length: 100 })
  accountHolder: string;

  @Column({ name: 'status', type: 'varchar', length: 20, default: 'Pending' })
  status: WithdrawalStatus;

  @Column({
    name: 'transaction_ref',
    type: 'varchar',
    length: 100,
    nullable: true,
  })
  transactionRef: string | null;

  @Column({ name: 'admin_note', type: 'nvarchar', length: 255, nullable: true })
  adminNote: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;

  @Column({ name: 'processed_at', type: 'datetime2', nullable: true })
  processedAt: Date | null;
}
