import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

export type WalletTxnType =
  | 'CREDIT_SALE'
  | 'DEBIT_WITHDRAW'
  | 'REFUND_WITHDRAW';

@Entity({ schema: 'Finance', name: 'Wallet_Transactions' })
export class WalletTransaction {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'txn_id' })
  txnId: number;

  @Column({ name: 'user_id', type: 'bigint' })
  userId: number;

  @Column({ name: 'amount', type: 'bigint' })
  amount: number;

  @Column({ name: 'type', type: 'varchar', length: 30 })
  type: WalletTxnType;

  @Column({ name: 'ref', type: 'varchar', length: 100, nullable: true })
  ref: string | null;

  @Column({ name: 'note', type: 'nvarchar', length: 255, nullable: true })
  note: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;
}
