import { Column, Entity, OneToMany, PrimaryGeneratedColumn } from 'typeorm';
import { Product } from './product.entity';

@Entity({ schema: 'Market', name: 'Categories' })
export class Category {
  @PrimaryGeneratedColumn({ type: 'int', name: 'category_id' })
  categoryId: number;

  @Column({ name: 'name', type: 'nvarchar', length: 100, unique: true })
  name: string;

  @Column({ name: 'slug', type: 'varchar', length: 50, nullable: true })
  slug: string | null;

  @OneToMany(() => Product, (product) => product.category)
  products?: Product[];
}
