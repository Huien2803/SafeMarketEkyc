import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Report } from '../entities/report.entity';
import { User } from '../entities/user.entity';
import { Product } from '../entities/product.entity';
import {
  CreateReportDto,
  ReportCategory,
} from './dto/create-report.dto';

const CATEGORY_LABELS: Record<ReportCategory, string> = {
  SCAM: 'Lừa đảo / chiếm đoạt',
  FAKE_OR_BANNED: 'Hàng giả / hàng cấm',
  MISLEADING: 'Thông tin sai lệch',
  OFFENSIVE_SPAM: 'Nội dung phản cảm / spam',
  HARASSMENT: 'Quấy rối / đe dọa',
  OTHER: 'Vi phạm khác',
};

const CATEGORY_SEVERITY: Record<ReportCategory, string> = {
  SCAM: 'high',
  FAKE_OR_BANNED: 'high',
  MISLEADING: 'medium',
  OFFENSIVE_SPAM: 'medium',
  HARASSMENT: 'high',
  OTHER: 'medium',
};

@Injectable()
export class ReportsService {
  constructor(
    @InjectRepository(Report) private readonly reportRepo: Repository<Report>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Product) private readonly productRepo: Repository<Product>,
  ) {}

  async create(reporterId: number, dto: CreateReportDto) {
    if (reporterId === dto.reportedId) {
      throw new BadRequestException('Bạn không thể báo cáo chính mình');
    }

    const reported = await this.userRepo.findOne({
      where: { userId: dto.reportedId },
    });
    if (!reported) {
      throw new NotFoundException('Người dùng bị báo cáo không tồn tại');
    }
    if (reported.isAdmin) {
      throw new ForbiddenException('Không thể báo cáo tài khoản admin');
    }

    if (dto.productId != null) {
      const product = await this.productRepo.findOne({
        where: { productId: dto.productId },
      });
      if (!product) {
        throw new NotFoundException('Sản phẩm không tồn tại');
      }
      if (Number(product.sellerId) !== dto.reportedId) {
        throw new BadRequestException(
          'Sản phẩm không thuộc về người bán được báo cáo',
        );
      }
    }

    const label = CATEGORY_LABELS[dto.category];
    const reason = `[${label}] ${dto.detail.trim()}`;
    const severity = dto.severity ?? CATEGORY_SEVERITY[dto.category];

    const saved = await this.reportRepo.save({
      reporterId,
      reportedId: dto.reportedId,
      reason,
      severity,
      productId: dto.productId ?? null,
      status: 'Open',
    });

    return {
      reportId: Number(saved.reportId),
      message: 'Đã gửi báo cáo. Admin sẽ kiểm duyệt trong thời gian sớm nhất.',
    };
  }
}
