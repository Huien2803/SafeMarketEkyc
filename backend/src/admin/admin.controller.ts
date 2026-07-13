import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AdminGuard } from '../common/guards/admin.guard';
import { AdminService } from './admin.service';

@ApiTags('admin')
@ApiBearerAuth('JWT-auth')
@UseGuards(AuthGuard('jwt'), AdminGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('stats')
  stats() {
    return this.adminService.getStats();
  }

  @Get('users')
  users() {
    return this.adminService.getUsers();
  }

  @Get('users/ranking')
  userRanking(@Query('order') order?: string) {
    const dir = order === 'asc' ? 'asc' : 'desc';
    return this.adminService.getUserRanking(dir);
  }

  @Get('reports')
  reports() {
    return this.adminService.getReports();
  }

  @Get('ekyc/pending')
  pendingEkyc() {
    return this.adminService.getPendingEkyc();
  }

  @Get('users/locked')
  lockedUsers() {
    return this.adminService.getLockedUsers();
  }

  @Post('ekyc/:userId/approve')
  approveEkyc(@Param('userId', ParseIntPipe) userId: number) {
    return this.adminService.approveEkyc(userId);
  }

  @Post('ekyc/:userId/reject')
  rejectEkyc(
    @Param('userId', ParseIntPipe) userId: number,
    @Body() body: { reason: string },
  ) {
    return this.adminService.rejectEkyc(userId, body.reason);
  }

  @Post('users/:userId/warn')
  warnUser(
    @Param('userId', ParseIntPipe) userId: number,
    @Body() body: { reason?: string },
  ) {
    return this.adminService.warnUser(userId, body.reason ?? 'Vi phạm quy định');
  }

  @Post('users/:userId/lock')
  lockUser(
    @Param('userId', ParseIntPipe) userId: number,
    @Body() body: { reason?: string },
  ) {
    return this.adminService.lockUser(userId, body.reason ?? 'Vi phạm');
  }

  @Post('users/:userId/suspend')
  suspendUser(
    @Param('userId', ParseIntPipe) userId: number,
    @Body() body: { days?: number; reason?: string },
  ) {
    return this.adminService.suspendUser(
      userId,
      Number(body.days ?? 7),
      body.reason ?? 'Vi phạm quy định',
    );
  }

  @Post('users/:userId/ban')
  banUser(
    @Param('userId', ParseIntPipe) userId: number,
    @Body() body: { reason?: string },
  ) {
    return this.adminService.banUser(userId, body.reason ?? 'Cấm vĩnh viễn');
  }

  @Post('users/:userId/punish')
  punishUser(
    @Param('userId', ParseIntPipe) userId: number,
    @Body() body: { points: number; reason?: string },
  ) {
    return this.adminService.punishUser(
      userId,
      body.points,
      body.reason ?? 'Vi phạm quy định',
    );
  }

  @Post('users/:userId/delete')
  deleteUser(@Param('userId', ParseIntPipe) userId: number) {
    return this.adminService.deleteUser(userId);
  }

  @Post('users/:userId/unlock')
  unlockUser(@Param('userId', ParseIntPipe) userId: number) {
    return this.adminService.unlockUser(userId);
  }

  @Post('reports/:reportId/resolve')
  resolveReport(
    @Param('reportId', ParseIntPipe) reportId: number,
    @Body() body: { status?: string },
  ) {
    return this.adminService.resolveReport(reportId, body.status ?? 'Resolved');
  }

  @Post('products/:productId/hide')
  hideProduct(@Param('productId', ParseIntPipe) productId: number) {
    return this.adminService.hideReportedProduct(productId);
  }

  @Get('disputes')
  disputes() {
    return this.adminService.getDisputes();
  }

  @Post('disputes/:orderId/resolve')
  resolveDispute(
    @Param('orderId', ParseIntPipe) orderId: number,
    @Body()
    body: {
      decision: 'REFUND_BUYER' | 'RELEASE_SELLER';
      note?: string;
      penaltyPoints?: number;
      skipPenalty?: boolean;
    },
  ) {
    return this.adminService.resolveDispute(orderId, body.decision, body);
  }

  @Get('withdrawals')
  withdrawals(@Query('status') status?: string) {
    return this.adminService.listPendingWithdrawals(status);
  }

  @Post('withdrawals/:id/approve')
  approveWithdrawal(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { note?: string },
  ) {
    return this.adminService.approveWithdrawal(id, body.note);
  }

  @Post('withdrawals/:id/reject')
  rejectWithdrawal(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { note?: string },
  ) {
    return this.adminService.rejectWithdrawal(id, body.note);
  }
}
