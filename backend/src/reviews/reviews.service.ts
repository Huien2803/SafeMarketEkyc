import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Review } from '../entities/review.entity';
import { Order } from '../entities/order.entity';
import { User } from '../entities/user.entity';
import { Score, RankLevel } from '../entities/score.entity';
import { PointLog } from '../entities/point-log.entity';

@Injectable()
export class ReviewsService {
  constructor(
    @InjectRepository(Review) private readonly reviewRepo: Repository<Review>,
    @InjectRepository(Order) private readonly orderRepo: Repository<Order>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Score) private readonly scoreRepo: Repository<Score>,
    @InjectRepository(PointLog) private readonly pointLogRepo: Repository<PointLog>,
  ) {}

  async submit(
    reviewerId: number,
    orderId: number,
    rating: number,
    comment?: string,
  ) {
    const order = await this.orderRepo.findOne({
      where: { orderId },
      relations: ['product', 'product.seller'],
    });
    if (!order) throw new NotFoundException('Đơn hàng không tồn tại');
    if (order.orderStatus !== 'Completed') {
      throw new BadRequestException('Chỉ đánh giá sau khi hoàn tất đơn');
    }
    if (rating < 1 || rating > 5) {
      throw new BadRequestException('Điểm đánh giá phải từ 1 đến 5 sao');
    }

    const sellerId = Number(order.product!.sellerId);
    const buyerId = Number(order.buyerId);
    if (reviewerId !== buyerId && reviewerId !== sellerId) {
      throw new ForbiddenException('Bạn không thuộc đơn hàng này');
    }

    const revieweeId = reviewerId === buyerId ? sellerId : buyerId;

    const existing = await this.reviewRepo.findOne({
      where: { orderId, reviewerId },
    });
    if (existing) throw new BadRequestException('Bạn đã đánh giá đơn này');

    const saved = await this.reviewRepo.save({
      orderId,
      reviewerId,
      revieweeId,
      rating,
      comment: comment ?? null,
    });

    const reviewer = await this.userRepo.findOne({ where: { userId: reviewerId } });
    const reviewee = await this.userRepo.findOne({ where: { userId: revieweeId } });

    await this.applyReviewReward(revieweeId, rating);

    return {
      reviewId: Number(saved.reviewId),
      orderId: Number(orderId),
      rating,
      comment: saved.comment,
      reviewerId,
      reviewerName: reviewer?.displayName ?? reviewer?.email ?? '',
      revieweeId,
      revieweeName: reviewee?.displayName ?? reviewee?.email ?? '',
      createdAt: saved.createdAt.toISOString(),
    };
  }

  async getOrderStatus(orderId: number, userId: number) {
    const order = await this.orderRepo.findOne({
      where: { orderId },
      relations: ['product'],
    });
    if (!order) throw new NotFoundException('Đơn hàng không tồn tại');

    const sellerId = Number(order.product!.sellerId);
    const buyerId = Number(order.buyerId);
    if (userId !== buyerId && userId !== sellerId) {
      throw new ForbiddenException('Bạn không thuộc đơn hàng này');
    }

    const reviews = await this.reviewRepo.find({ where: { orderId } });
    const buyerReviewed = reviews.some((r) => Number(r.reviewerId) === buyerId);
    const sellerReviewed = reviews.some((r) => Number(r.reviewerId) === sellerId);
    const revieweeId = userId === buyerId ? sellerId : buyerId;
    const reviewee = await this.userRepo.findOne({ where: { userId: revieweeId } });

    return {
      canReview:
        order.orderStatus === 'Completed' &&
        !(userId === buyerId ? buyerReviewed : sellerReviewed),
      buyerReviewed,
      sellerReviewed,
      revieweeId,
      revieweeName: reviewee?.displayName ?? reviewee?.email ?? '',
    };
  }

  private async applyReviewReward(revieweeId: number, rating: number) {
    if (rating !== 5) return;

    let score = await this.scoreRepo.findOne({ where: { userId: revieweeId } });
    if (!score) {
      score = await this.scoreRepo.save(
        this.scoreRepo.create({
          userId: revieweeId,
          currentPoint: 500,
          rankLevel: 'Bronze',
        }),
      );
    }

    // Chỉ ghi log — trigger SQL cộng điểm (tránh cộng 2 lần).
    await this.pointLogRepo.save({
      userId: revieweeId,
      delta: 30,
      reasonCode: 'REVIEW_5_STAR',
      note: 'Nhận đánh giá 5 sao',
    });
  }

  private rankFor(point: number): RankLevel {
    if (point >= 850) return 'Diamond';
    if (point >= 600) return 'Gold';
    if (point >= 300) return 'Silver';
    return 'Bronze';
  }

  async getUserReviews(userId: number) {
    const rows = await this.reviewRepo.find({
      where: { revieweeId: userId },
      relations: ['reviewer', 'reviewee'],
      order: { createdAt: 'DESC' },
    });
    return rows.map((r) => ({
      reviewId: Number(r.reviewId),
      orderId: Number(r.orderId),
      rating: r.rating,
      comment: r.comment,
      reviewerId: Number(r.reviewerId),
      reviewerName: r.reviewer?.displayName ?? r.reviewer?.email ?? '',
      revieweeId: Number(r.revieweeId),
      revieweeName: r.reviewee?.displayName ?? r.reviewee?.email ?? '',
      createdAt: r.createdAt.toISOString(),
    }));
  }
}
