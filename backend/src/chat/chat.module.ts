import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { ChatThread } from '../entities/chat-thread.entity';
import { ChatMessage } from '../entities/chat-message.entity';
import { User } from '../entities/user.entity';
import { Product } from '../entities/product.entity';
import { Score } from '../entities/score.entity';
import { OrdersModule } from '../orders/orders.module';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      ChatThread,
      ChatMessage,
      User,
      Product,
      Score,
    ]),
    AuthModule,
    OrdersModule,
  ],
  controllers: [ChatController],
  providers: [ChatService],
})
export class ChatModule {}
