import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Category } from '../entities/category.entity';
import { CategoryDto } from './dto/category.dto';

@Injectable()
export class CategoriesService {
  constructor(
    @InjectRepository(Category)
    private readonly categoryRepo: Repository<Category>,
  ) {}

  async findAll(): Promise<CategoryDto[]> {
    const rows = await this.categoryRepo.find({ order: { categoryId: 'ASC' } });
    return rows.map((c) => ({
      categoryId: c.categoryId,
      name: c.name,
      slug: c.slug,
    }));
  }

  async findOne(id: number): Promise<Category> {
    const cat = await this.categoryRepo.findOne({ where: { categoryId: id } });
    if (!cat) throw new NotFoundException('Danh mục không tồn tại');
    return cat;
  }
}
