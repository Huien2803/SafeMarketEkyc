import {
  Controller,
  Get,
  Header,
  Param,
  ParseIntPipe,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';
import { PaymentsService } from './payments.service';

@ApiTags('payments')
@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post('orders/:orderId/checkout')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Tạo link VNPay — tiền vào escrow SafeMarket' })
  checkout(
    @Param('orderId', ParseIntPipe) orderId: number,
    @CurrentUser() user: User,
    @Req() req: Request,
  ) {
    const ip =
      (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ||
      req.ip ||
      '127.0.0.1';
    return this.paymentsService.createCheckout(
      orderId,
      Number(user.userId),
      ip,
    );
  }

  @Post('orders/:orderId/simulate-pay')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({
    summary: 'Dev: giả lập thanh toán escrow (khi chưa cấu hình VNPay)',
  })
  simulatePay(
    @Param('orderId', ParseIntPipe) orderId: number,
    @CurrentUser() user: User,
  ) {
    return this.paymentsService.simulatePayment(orderId, Number(user.userId));
  }

  @Get('vnpay-return')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @ApiOperation({ summary: 'VNPay redirect sau thanh toán' })
  vnpayReturn(@Query() query: Record<string, string>) {
    return this.paymentsService.handleVnpayReturn(query);
  }

  @Get('vnpay-ipn')
  @ApiOperation({ summary: 'VNPay IPN webhook' })
  vnpayIpn(@Query() query: Record<string, string>) {
    return this.paymentsService.handleVnpayIpn(query);
  }
}
