import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
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

  @Post('users/:userId/lock')
  lockUser(
    @Param('userId', ParseIntPipe) userId: number,
    @Body() body: { reason?: string },
  ) {
    return this.adminService.lockUser(userId, body.reason ?? 'Vi phạm');
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
}
