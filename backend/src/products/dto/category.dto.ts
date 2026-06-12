import { ApiProperty } from '@nestjs/swagger';

export class CategoryDto {
  @ApiProperty({ example: 1 })
  categoryId: number;

  @ApiProperty({ example: 'Điện tử' })
  name: string;

  @ApiProperty({ example: 'dien-tu', nullable: true })
  slug: string | null;
}
