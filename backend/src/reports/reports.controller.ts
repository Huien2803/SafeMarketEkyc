import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';
import { ReportsService } from './reports.service';

@ApiTags('reports')
@ApiBearerAuth('JWT-auth')
@UseGuards(AuthGuard('jwt'))
@Controller('reports')
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Post()
  create(
    @CurrentUser() user: User,
    @Body()
    body: {
      reportedId: number;
      reason: string;
      severity?: string;
      productId?: number;
    },
  ) {
    return this.reportsService.create(
      Number(user.userId),
      body.reportedId,
      body.reason,
      body.severity ?? 'medium',
      body.productId,
    );
  }
}
