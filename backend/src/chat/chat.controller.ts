import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';
import { ChatService } from './chat.service';
import {
  chatImageFilter,
  chatImageStorage,
  toPublicChatPath,
} from './chat-upload.config';

@ApiTags('chat')
@ApiBearerAuth('JWT-auth')
@UseGuards(AuthGuard('jwt'))
@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Post('open')
  open(
    @CurrentUser() user: User,
    @Body() body: { sellerId: number; productId?: number; orderId?: number },
  ) {
    return this.chatService.openThread(
      Number(user.userId),
      body.sellerId,
      body.productId,
      body.orderId,
    );
  }

  @Get('threads')
  threads(@CurrentUser() user: User) {
    return this.chatService.getThreads(Number(user.userId));
  }

  @Get('threads/:threadId')
  threadDetail(
    @CurrentUser() user: User,
    @Param('threadId', ParseIntPipe) threadId: number,
  ) {
    return this.chatService.getThreadDetail(threadId, Number(user.userId));
  }

  @Get('threads/:threadId/messages')
  messages(
    @CurrentUser() user: User,
    @Param('threadId', ParseIntPipe) threadId: number,
  ) {
    return this.chatService.getMessages(threadId, Number(user.userId));
  }

  @Post('threads/:threadId/messages')
  sendMessage(
    @CurrentUser() user: User,
    @Param('threadId', ParseIntPipe) threadId: number,
    @Body() body: { body: string },
  ) {
    return this.chatService.sendMessage(threadId, Number(user.userId), body.body);
  }

  @Post('threads/:threadId/purchase-request')
  purchaseRequest(
    @CurrentUser() user: User,
    @Param('threadId', ParseIntPipe) threadId: number,
    @Body()
    body: {
      shippingAddress: string;
      paymentMethod?: string;
      deliveryMethod?: string;
    },
  ) {
    return this.chatService.purchaseRequest(
      threadId,
      Number(user.userId),
      body.shippingAddress,
      body.paymentMethod,
      body.deliveryMethod,
    );
  }

  @Post('threads/:threadId/confirm-sale')
  confirmSale(
    @CurrentUser() user: User,
    @Param('threadId', ParseIntPipe) threadId: number,
    @Body() body: { messageId: number },
  ) {
    return this.chatService.confirmSale(
      threadId,
      Number(user.userId),
      body.messageId,
    );
  }

  @Post('upload-image')
  @UseInterceptors(
    FileInterceptor('image', {
      storage: chatImageStorage,
      fileFilter: chatImageFilter,
      limits: { fileSize: 5 * 1024 * 1024 },
    }),
  )
  uploadImage(@UploadedFile() file: Express.Multer.File) {
    if (!file?.filename) {
      return { imageUrl: null };
    }
    return { imageUrl: toPublicChatPath(file.filename) };
  }
}
