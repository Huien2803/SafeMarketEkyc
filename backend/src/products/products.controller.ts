import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Query,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FilesInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';
import { CategoriesService } from './categories.service';
import { ProductsService } from './products.service';
import { CreateProductDto } from './dto/create-product.dto';
import { ProductQueryDto } from './dto/product-query.dto';
import {
  MAX_PRODUCT_IMAGES,
  productImageFilter,
  productImageStorage,
} from './product-upload.config';

@ApiTags('products')
@Controller('products')
export class ProductsController {
  constructor(
    private readonly categoriesService: CategoriesService,
    private readonly productsService: ProductsService,
  ) {}

  @Get('categories')
  @ApiOperation({ summary: 'Danh sách danh mục' })
  getCategories() {
    return this.categoriesService.findAll();
  }

  @Get()
  @ApiOperation({ summary: 'Danh sách sản phẩm đang rao bán' })
  getProducts(@Query() query: ProductQueryDto) {
    return this.productsService.findAll(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Chi tiết sản phẩm' })
  getProduct(@Param('id', ParseIntPipe) id: number) {
    return this.productsService.findOne(id);
  }

  @Post()
  @ApiBearerAuth('JWT-auth')
  @UseGuards(AuthGuard('jwt'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['title', 'description', 'price', 'conditionPct', 'categoryId', 'images'],
      properties: {
        title: { type: 'string' },
        description: { type: 'string' },
        price: { type: 'integer' },
        conditionPct: { type: 'integer' },
        categoryId: { type: 'integer' },
        location: { type: 'string' },
        images: {
          type: 'array',
          items: { type: 'string', format: 'binary' },
          description: `Tối đa ${MAX_PRODUCT_IMAGES} ảnh; ảnh đầu tiên là ảnh bìa`,
        },
      },
    },
  })
  @UseInterceptors(
    FilesInterceptor('images', MAX_PRODUCT_IMAGES, {
      storage: productImageStorage,
      fileFilter: productImageFilter,
      limits: { fileSize: 5 * 1024 * 1024 },
    }),
  )
  createProduct(
    @CurrentUser() user: User,
    @Body() dto: CreateProductDto,
    @UploadedFiles() images: Express.Multer.File[],
  ) {
    return this.productsService.createProduct(Number(user.userId), dto, images);
  }

  @Put(':id')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(AuthGuard('jwt'))
  updateProduct(
    @CurrentUser() user: User,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: Partial<CreateProductDto>,
  ) {
    return this.productsService.updateProduct(id, Number(user.userId), dto);
  }

  @Post(':id/hide')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'Ẩn tin đăng (Available → Hidden)' })
  hideProduct(
    @CurrentUser() user: User,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.productsService.hideProduct(id, Number(user.userId));
  }

  @Post(':id/unhide')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'Hiện lại tin đã ẩn (Hidden → Available)' })
  unhideProduct(
    @CurrentUser() user: User,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.productsService.unhideProduct(id, Number(user.userId));
  }

  @Delete(':id')
  @ApiBearerAuth('JWT-auth')
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'Xóa tin đăng (Available hoặc Hidden)' })
  deleteProduct(
    @CurrentUser() user: User,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.productsService.deleteProduct(id, Number(user.userId));
  }
}
