import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';
import { WalletService } from './wallet.service';
import { CreateWithdrawalDto } from './dto/withdraw.dto';

@ApiTags('wallet')
@ApiBearerAuth('JWT-auth')
@UseGuards(AuthGuard('jwt'))
@Controller('wallet')
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get()
  @ApiOperation({ summary: 'Số dư ví + lịch sử giao dịch' })
  getWallet(@CurrentUser() user: User) {
    return this.walletService.getWallet(Number(user.userId));
  }

  @Get('withdrawals')
  @ApiOperation({ summary: 'Lịch sử rút tiền' })
  getWithdrawals(@CurrentUser() user: User) {
    return this.walletService.getWithdrawals(Number(user.userId));
  }

  @Post('withdrawals')
  @ApiOperation({ summary: 'Yêu cầu rút tiền về tài khoản ngân hàng' })
  requestWithdrawal(
    @CurrentUser() user: User,
    @Body() dto: CreateWithdrawalDto,
  ) {
    return this.walletService.requestWithdrawal(Number(user.userId), dto);
  }
}
