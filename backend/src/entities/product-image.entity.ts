import {
  Column,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Product } from './product.entity';

@Entity({ schema: 'Market', name: 'Product_Images' })
export class ProductImage {
  @PrimaryGeneratedColumn({ type: 'bigint', name: 'image_id' })
  imageId: number;

  @Column({ name: 'product_id', type: 'bigint' })
  productId: number;

  @Column({ name: 'image_url', type: 'varchar', length: 500 })
  imageUrl: string;

  @Column({ name: 'sort_order', type: 'tinyint', default: 0 })
  sortOrder: number;

  @ManyToOne(() => Product, (product) => product.images, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'product_id' })
  product?: Product;
}
