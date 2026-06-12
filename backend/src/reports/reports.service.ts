import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Report } from '../entities/report.entity';

@Injectable()
export class ReportsService {
  constructor(
    @InjectRepository(Report) private readonly reportRepo: Repository<Report>,
  ) {}

  async create(
    reporterId: number,
    reportedId: number,
    reason: string,
    severity: string,
    productId?: number,
  ) {
    await this.reportRepo.save({
      reporterId,
      reportedId,
      reason,
      severity: severity || 'medium',
      productId: productId ?? null,
      status: 'Open',
    });
  }
}
