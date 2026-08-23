import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, Repository } from 'typeorm';
import { Product } from '../entities/product.entity';
import { ProductImage } from '../entities/product-image.entity';
import { Score } from '../entities/score.entity';
import { Review } from '../entities/review.entity';
import { User } from '../entities/user.entity';
import { Order } from '../entities/order.entity';
import { Payment } from '../entities/payment.entity';
import { Report } from '../entities/report.entity';
import { ChatThread } from '../entities/chat-thread.entity';
import { CategoriesService } from './categories.service';
import { CreateProductDto } from './dto/create-product.dto';
import { ProductQueryDto, ProductSort } from './dto/product-query.dto';
import { toPublicUploadPath } from './product-upload.config';
import { formatVnd } from '../common/utils/format.util';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class ProductsService {
  constructor(
    @InjectRepository(Product)
    private readonly productRepo: Repository<Product>,
    @InjectRepository(ProductImage)
    private readonly imageRepo: Repository<ProductImage>,
    @InjectRepository(Score)
    private readonly scoreRepo: Repository<Score>,
    @InjectRepository(Review)
    private readonly reviewRepo: Repository<Review>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Order)
    private readonly orderRepo: Repository<Order>,
    private readonly dataSource: DataSource,
    private readonly categoriesService: CategoriesService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async findAll(query: ProductQueryDto): Promise<Record<string, unknown>[]> {
    const qb = this.productRepo
      .createQueryBuilder('p')
      .leftJoin('p.seller', 'seller')
      .addSelect([
        'seller.userId',
        'seller.displayName',
        'seller.email',
        'seller.kycStatus',
      ])
      .leftJoinAndSelect('p.category', 'category')
      .where('p.status IN (:...statuses)', {
        statuses: ['Available', 'Reserved'],
      });

    if (query.categoryId) {
      qb.andWhere('p.categoryId = :categoryId', {
        categoryId: query.categoryId,
      });
    }

    if (query.search?.trim()) {
      const keyword = `%${query.search.trim()}%`;
      qb.andWhere(
        '(p.title LIKE :keyword OR p.description LIKE :keyword OR p.location LIKE :keyword)',
        { keyword },
      );
    }

    if (query.minPrice != null) {
      qb.andWhere('p.price >= :minPrice', { minPrice: query.minPrice });
    }
    if (query.maxPrice != null) {
      qb.andWhere('p.price <= :maxPrice', { maxPrice: query.maxPrice });
    }

    if (query.location?.trim()) {
      const patterns = this.locationLikePatterns(query.location.trim());
      const orClauses = patterns
        .map((_, i) => `p.location LIKE :loc${i}`)
        .join(' OR ');
      const params = Object.fromEntries(
        patterns.map((p, i) => [`loc${i}`, p]),
      );
      qb.andWhere(`(${orClauses})`, params);
    }

    if (query.verifiedOnly) {
      qb.andWhere('seller.kycStatus = :kyc', { kyc: 'Verified' });
    }

    switch (query.sort ?? ProductSort.NEWEST) {
      case ProductSort.PRICE_ASC:
        qb.orderBy('p.price', 'ASC').addOrderBy('p.productId', 'DESC');
        break;
      case ProductSort.PRICE_DESC:
        qb.orderBy('p.price', 'DESC').addOrderBy('p.productId', 'DESC');
        break;
      case ProductSort.OLDEST:
        qb.orderBy('p.productId', 'ASC');
        break;
      default:
        qb.orderBy('p.productId', 'DESC');
    }

    qb.take(100);

    const rows = await qb.getMany();
    const sellerIds = [
      ...new Set(rows.map((p) => Number(p.seller?.userId ?? p.sellerId))),
    ].filter((id) => id > 0);
    const scores =
      sellerIds.length > 0
        ? await this.scoreRepo.find({ where: { userId: In(sellerIds) } })
        : [];
    const scoreByUser = new Map(
      scores.map((s) => [Number(s.userId), s.currentPoint]),
    );
    return rows.map((p) => this.toListJson(p, scoreByUser));
  }

  /** Một số tin ghi "TP.HCM" thay vì tên tỉnh đầy đủ — gom alias khi lọc. */
  private locationLikePatterns(province: string): string[] {
    const aliases: Record<string, string[]> = {
      'TP. Hồ Chí Minh': [
        '%TP. Hồ Chí Minh%',
        '%TP.HCM%',
        '%Hồ Chí Minh%',
        '%Sài Gòn%',
      ],
      'Hà Nội': ['%Hà Nội%'],
      'Đà Nẵng': ['%Đà Nẵng%'],
      'Hải Phòng': ['%Hải Phòng%'],
      'Cần Thơ': ['%Cần Thơ%'],
      Huế: ['%Huế%', '%Thừa Thiên%'],
    };
    return aliases[province] ?? [`%${province}%`];
  }

  async findOne(productId: number): Promise<Record<string, unknown>> {
    const product = await this.productRepo.findOne({
      where: { productId },
      relations: ['seller', 'category'],
    });
    if (!product) throw new NotFoundException('Sản phẩm không tồn tại');

    const images = await this.imageRepo.find({
      where: { productId },
      order: { sortOrder: 'ASC' },
    });
    const imageUrls = images.map((i) => i.imageUrl);
    if (imageUrls.length === 0 && product.thumbnailUrl) {
      imageUrls.push(product.thumbnailUrl);
    }

    const sellerId = Number(product.seller!.userId);
    const score = await this.scoreRepo.findOne({ where: { userId: sellerId } });
    const list = this.toListJson(
      product,
      new Map([[sellerId, score?.currentPoint ?? 500]]),
    );
    return {
      ...list,
      description: product.description,
      imageUrls,
      seller: await this.toSellerJson(product.seller!),
    };
  }

  async createProduct(
    sellerId: number,
    dto: CreateProductDto,
    files?: Express.Multer.File[],
  ): Promise<Record<string, unknown>> {
    const seller = await this.userRepo.findOne({ where: { userId: sellerId } });
    if (!seller || seller.kycStatus !== 'Verified') {
      throw new ForbiddenException(
        'Bạn cần xác thực danh tính (eKYC) trước khi đăng bán sản phẩm',
      );
    }

    await this.categoriesService.findOne(dto.categoryId);

    const imageUrls = (files ?? [])
      .filter((f) => f?.filename)
      .map((f) => toPublicUploadPath(f.filename));
    const thumbnailUrl = imageUrls.length > 0 ? imageUrls[0] : null;

    const product = this.productRepo.create({
      title: dto.title,
      description: dto.description,
      price: dto.price,
      conditionPct: dto.conditionPct,
      categoryId: dto.categoryId,
      location: dto.location ?? null,
      sellerId,
      thumbnailUrl,
      status: 'Available',
    });

    const saved = await this.productRepo.save(product);
    if (imageUrls.length > 0) {
      await this.imageRepo.save(
        imageUrls.map((url, index) => ({
          productId: saved.productId,
          imageUrl: url,
          sortOrder: index,
        })),
      );
    }
    await this.notificationsService.notifyNewProduct(sellerId, saved);
    return this.findOne(Number(saved.productId));
  }

  async updateProduct(
    productId: number,
    sellerId: number,
    patch: Partial<CreateProductDto>,
  ): Promise<void> {
    const product = await this.requireSellerProduct(productId, sellerId);
    if (product.status === 'Sold') {
      throw new BadRequestException('Không thể sửa tin đã bán');
    }
    if (product.status === 'Reserved') {
      throw new BadRequestException(
        'Tin đang có người đặt — không thể sửa. Hãy hủy đơn hoặc hoàn tất giao dịch trước.',
      );
    }
    if (patch.title != null) product.title = patch.title;
    if (patch.description != null) product.description = patch.description;
    if (patch.price != null) product.price = patch.price;
    if (patch.conditionPct != null) product.conditionPct = patch.conditionPct;
    if (patch.location != null) product.location = patch.location;
    if (patch.categoryId != null) {
      await this.categoriesService.findOne(patch.categoryId);
      product.categoryId = patch.categoryId;
    }
    await this.productRepo.save(product);
  }

  async hideProduct(productId: number, sellerId: number): Promise<void> {
    const product = await this.requireSellerProduct(productId, sellerId);
    if (product.status !== 'Available') {
      throw new BadRequestException(
        'Chỉ ẩn được tin đang Available (chưa có người đặt / chưa bán).',
      );
    }
    product.status = 'Hidden';
    await this.productRepo.save(product);
  }

  /** Hiện lại tin đã ẩn → Available. */
  async unhideProduct(productId: number, sellerId: number): Promise<void> {
    const product = await this.requireSellerProduct(productId, sellerId);
    if (product.status !== 'Hidden') {
      throw new BadRequestException('Chỉ hiện lại được tin đang ở trạng thái Hidden');
    }
    product.status = 'Available';
    await this.productRepo.save(product);
  }

  async deleteProduct(productId: number, sellerId: number): Promise<{ message: string }> {
    const product = await this.requireSellerProduct(productId, sellerId);
    if (product.status === 'Sold') {
      throw new BadRequestException('Không thể xóa tin đã bán (giữ lịch sử)');
    }
    if (product.status === 'Reserved') {
      throw new BadRequestException(
        'Tin đang có người đặt — không thể xóa. Hãy xử lý đơn trước.',
      );
    }

    const linkedOrder = await this.orderRepo.findOne({
      where: { productId },
    });
    if (linkedOrder && linkedOrder.orderStatus !== 'Cancelled') {
      throw new BadRequestException(
        'Còn đơn hàng liên quan tới tin này. Hãy hủy đơn (hoặc hoàn tất) trước khi xóa.',
      );
    }

    try {
      await this.dataSource.transaction(async (manager) => {
        if (linkedOrder) {
          const orderId = Number(linkedOrder.orderId);
          await manager.delete(Review, { orderId });
          await manager.delete(Payment, { orderId });
          await manager
            .createQueryBuilder()
            .update(ChatThread)
            .set({ orderId: null, productId: null })
            .where('order_id = :orderId OR product_id = :productId', {
              orderId,
              productId,
            })
            .execute();
          await manager.delete(Order, { orderId });
        } else {
          await manager
            .createQueryBuilder()
            .update(ChatThread)
            .set({ productId: null })
            .where('product_id = :productId', { productId })
            .execute();
        }

        await manager
          .createQueryBuilder()
          .update(Report)
          .set({ productId: null })
          .where('product_id = :productId', { productId })
          .execute();

        await manager.delete(ProductImage, { productId });
        await manager.delete(Product, { productId });
      });
    } catch (err) {
      if (err instanceof BadRequestException) throw err;
      const msg = err instanceof Error ? err.message : String(err);
      throw new BadRequestException(
        `Không xóa được tin (còn dữ liệu liên quan): ${msg}`,
      );
    }

    return { message: 'Đã xóa tin đăng' };
  }

  private async requireSellerProduct(
    productId: number,
    sellerId: number,
  ): Promise<Product> {
    const product = await this.productRepo.findOne({ where: { productId } });
    if (!product) throw new NotFoundException('Sản phẩm không tồn tại');
    if (Number(product.sellerId) !== sellerId) {
      throw new ForbiddenException('Bạn không phải người bán sản phẩm này');
    }
    return product;
  }

  private toListJson(
    product: Product,
    scoreByUser?: Map<number, number>,
  ): Record<string, unknown> {
    const seller = product.seller!;
    const sellerId = Number(seller.userId);
    const trustScore = scoreByUser?.get(sellerId) ?? 500;
    const price = Number(product.price);

    return {
      id: Number(product.productId),
      title: product.title,
      price,
      priceFormatted: formatVnd(price),
      location: product.location ?? '',
      conditionPct: product.conditionPct,
      status: product.status,
      sellerName: seller.displayName ?? seller.email,
      sellerId,
      trustScore,
      sellerVerified: seller.kycStatus === 'Verified',
      categoryName: product.category?.name ?? '',
      categoryId: product.categoryId,
      thumbnailUrl: product.thumbnailUrl,
    };
  }

  private async toSellerJson(seller: User): Promise<Record<string, unknown>> {
    const userId = Number(seller.userId);
    const score = await this.scoreRepo.findOne({ where: { userId } });
    const reviewRows = await this.reviewRepo.find({
      where: { revieweeId: userId },
    });
    const reviewCount = reviewRows.length;
    const averageRating =
      reviewCount > 0
        ? Math.round(
            (reviewRows.reduce((s, r) => s + r.rating, 0) / reviewCount) * 10,
          ) / 10
        : 0;

    return {
      userId,
      email: seller.email,
      phoneNumber: seller.phoneNumber,
      displayName: seller.displayName,
      kycStatus: seller.kycStatus,
      accountStatus: seller.accountStatus,
      isAdmin: !!seller.isAdmin,
      trustScore: score?.currentPoint ?? 500,
      reviewCount,
      averageRating,
    };
  }
}
