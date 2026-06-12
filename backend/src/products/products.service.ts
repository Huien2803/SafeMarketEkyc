import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { FindOptionsWhere, In, Like, Repository } from 'typeorm';
import { Product } from '../entities/product.entity';
import { ProductImage } from '../entities/product-image.entity';
import { Score } from '../entities/score.entity';
import { Review } from '../entities/review.entity';
import { User } from '../entities/user.entity';
import { CategoriesService } from './categories.service';
import { CreateProductDto } from './dto/create-product.dto';
import { ProductQueryDto } from './dto/product-query.dto';
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
    private readonly categoriesService: CategoriesService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async findAll(query: ProductQueryDto): Promise<Record<string, unknown>[]> {
    const base: FindOptionsWhere<Product> = {
      status: In(['Available', 'Reserved']),
    };
    if (query.categoryId) base.categoryId = query.categoryId;

    let where: FindOptionsWhere<Product> | FindOptionsWhere<Product>[] = base;
    if (query.search?.trim()) {
      const keyword = `%${query.search.trim()}%`;
      where = [
        { ...base, title: Like(keyword) },
        { ...base, description: Like(keyword) },
        { ...base, location: Like(keyword) },
      ];
    }

    const rows = await this.productRepo.find({
      where,
      relations: ['seller', 'category'],
      order: { productId: 'DESC' },
      take: 100,
    });

    let filtered = rows;
    if (query.verifiedOnly) {
      filtered = rows.filter((p) => p.seller?.kycStatus === 'Verified');
    }

    return Promise.all(filtered.map((p) => this.toListJson(p)));
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

    const list = await this.toListJson(product);
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
    file?: Express.Multer.File,
  ): Promise<Record<string, unknown>> {
    await this.categoriesService.findOne(dto.categoryId);

    let thumbnailUrl: string | null = null;
    if (file?.filename) {
      thumbnailUrl = toPublicUploadPath(file.filename);
    }

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
    if (thumbnailUrl) {
      await this.imageRepo.save({
        productId: saved.productId,
        imageUrl: thumbnailUrl,
        sortOrder: 0,
      });
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
    product.status = 'Hidden';
    await this.productRepo.save(product);
  }

  async deleteProduct(productId: number, sellerId: number): Promise<void> {
    const product = await this.requireSellerProduct(productId, sellerId);
    await this.imageRepo.delete({ productId });
    await this.productRepo.remove(product);
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

  private async toListJson(product: Product): Promise<Record<string, unknown>> {
    const seller = product.seller!;
    const score = await this.scoreRepo.findOne({
      where: { userId: Number(seller.userId) },
    });
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
      trustScore: score?.currentPoint ?? 500,
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
