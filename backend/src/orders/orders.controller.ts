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
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';
import { OrdersService } from './orders.service';
import {
  CancelOrderDto,
  ChangePaymentMethodDto,
  CreateOrderDto,
  DisputeOrderDto,
} from './dto/order.dto';
import {
  orderProofFilter,
  orderProofStorage,
  toPublicOrderProofPath,
} from './order-upload.config';

@ApiTags('orders')
@ApiBearerAuth('JWT-auth')
@UseGuards(AuthGuard('jwt'))
@Controller('orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Post()
  @ApiOperation({ summary: 'Tạo đơn mua hàng' })
  create(@CurrentUser() user: User, @Body() dto: CreateOrderDto) {
    return this.ordersService.createOrder(Number(user.userId), dto);
  }

  @Get('my')
  @ApiOperation({ summary: 'Đơn hàng của tôi (mua + bán)' })
  myOrders(@CurrentUser() user: User) {
    return this.ordersService.getMyOrders(Number(user.userId));
  }

  @Get(':orderId')
  @ApiOperation({ summary: 'Chi tiết đơn hàng' })
  getOne(
    @CurrentUser() user: User,
    @Param('orderId', ParseIntPipe) orderId: number,
  ) {
    return this.ordersService.getOrder(orderId, Number(user.userId));
  }

  @Post(':orderId/payment-method')
  @ApiOperation({ summary: 'Đổi phương thức thanh toán / giao hàng (đơn Pending)' })
  changePaymentMethod(
    @CurrentUser() user: User,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Body() dto: ChangePaymentMethodDto,
  ) {
    return this.ordersService.changePaymentMethod(
      orderId,
      Number(user.userId),
      dto,
    );
  }

  @Post(':orderId/ship')
  ship(
    @CurrentUser() user: User,
    @Param('orderId', ParseIntPipe) orderId: number,
  ) {
    return this.ordersService.markShipped(orderId, Number(user.userId));
  }

  @Post(':orderId/confirm-payment')
  confirmPayment(
    @CurrentUser() user: User,
    @Param('orderId', ParseIntPipe) orderId: number,
  ) {
    return this.ordersService.confirmPayment(orderId, Number(user.userId));
  }

  @Post(':orderId/confirm-handover')
  confirmHandover(
    @CurrentUser() user: User,
    @Param('orderId', ParseIntPipe) orderId: number,
  ) {
    return this.ordersService.confirmHandover(orderId, Number(user.userId));
  }

  @Post(':orderId/complete')
  @ApiOperation({
    summary: 'Người mua xác nhận đã nhận hàng kèm ảnh bằng chứng',
  })
  @UseInterceptors(
    FileInterceptor('proof', {
      storage: orderProofStorage,
      fileFilter: orderProofFilter,
      limits: { fileSize: 8 * 1024 * 1024 },
    }),
  )
  complete(
    @CurrentUser() user: User,
    @Param('orderId', ParseIntPipe) orderId: number,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    const proofUrl = file?.filename ? toPublicOrderProofPath(file.filename) : null;
    return this.ordersService.complete(orderId, Number(user.userId), proofUrl);
  }

  @Post(':orderId/cancel')
  cancel(
    @CurrentUser() user: User,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Body() dto: CancelOrderDto,
  ) {
    return this.ordersService.cancel(orderId, Number(user.userId), dto);
  }

  @Post(':orderId/dispute')
  dispute(
    @CurrentUser() user: User,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Body() dto: DisputeOrderDto,
  ) {
    return this.ordersService.dispute(orderId, Number(user.userId), dto);
  }
}
