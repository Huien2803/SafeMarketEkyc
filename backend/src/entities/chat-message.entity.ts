import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';
import { ChatThread } from './chat-thread.entity';

@Entity({ schema: 'Market', name: 'Chat_Messages' })
export class ChatMessage {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'message_id' })
  messageId: number;

  @Column({ name: 'thread_id', type: 'bigint' })
  threadId: number;

  @Column({ name: 'sender_id', type: 'bigint' })
  senderId: number;

  @Column({ name: 'body', type: 'nvarchar', length: 'MAX' })
  body: string;

  @Column({ name: 'message_type', type: 'varchar', length: 30, default: 'TEXT' })
  messageType: string;

  @Column({ name: 'meta', type: 'nvarchar', length: 'MAX', nullable: true })
  meta: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;

  @ManyToOne(() => ChatThread, (t) => t.messages)
  @JoinColumn({ name: 'thread_id' })
  thread?: ChatThread;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'sender_id' })
  sender?: User;
}
