import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';
import { Category } from './category.entity';
import { ProductImage } from './product-image.entity';

export type ProductStatus = 'Available' | 'Reserved' | 'Sold' | 'Hidden';

@Entity({ schema: 'Market', name: 'Products' })
@Index('IX_Products_Seller', ['sellerId'])
@Index('IX_Products_Category', ['categoryId'])
@Index('IX_Products_Status', ['status'])
export class Product {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'product_id' })
  productId: number;

  @Column({ name: 'title', type: 'nvarchar', length: 255 })
  title: string;

  @Column({ name: 'description', type: 'nvarchar', length: 'MAX' })
  description: string;

  @Column({ name: 'price', type: 'bigint' })
  price: number;

  @Column({ name: 'condition_pct', type: 'tinyint' })
  conditionPct: number;

  @Column({ name: 'status', type: 'varchar', length: 20, default: 'Available' })
  status: ProductStatus;

  @Column({ name: 'location', type: 'nvarchar', length: 100, nullable: true })
  location: string | null;

  @Column({ name: 'thumbnail_url', type: 'varchar', length: 500, nullable: true })
  thumbnailUrl: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'datetime2' })
  createdAt: Date;

  @Column({ name: 'seller_id', type: 'bigint' })
  sellerId: number;

  @Column({ name: 'category_id', type: 'int' })
  categoryId: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'seller_id' })
  seller?: User;

  @ManyToOne(() => Category, (category) => category.products)
  @JoinColumn({ name: 'category_id' })
  category?: Category;

  @OneToMany(() => ProductImage, (image) => image.product)
  images?: ProductImage[];
}
