import { Injectable, NotFoundException } from '@nestjs/common';

import { I18nService } from '../i18n/i18n.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  CreateProductDto,
  UpdateProductDto,
  ProductResponseDto,
  QueryProductDto,
} from './dto';

@Injectable()
export class ProductsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly i18nService: I18nService,
  ) {}

  async create(
    createProductDto: CreateProductDto,
  ): Promise<ProductResponseDto> {
    if (!createProductDto.userId) {
      throw new Error('User ID is required');
    }

    return await this.prisma.products.create({
      data: {
        name: createProductDto.name,
        description: createProductDto.description,
        price: createProductDto.price,
        userId: createProductDto.userId,
      },
    });
  }

  async findAll(query: QueryProductDto): Promise<{
    data: ProductResponseDto[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  }> {
    const { search, userId, page = 1, limit = 10 } = query;
    const skip = (page - 1) * limit;

    const where: any = {};

    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
      ];
    }

    if (userId) {
      where.userId = userId;
    }

    const total = await this.prisma.products.count({ where });

    const products = await this.prisma.products.findMany({
      where,
      skip,
      take: limit,
      orderBy: { createdAt: 'desc' },
    });

    const totalPages = Math.ceil(total / limit);

    return {
      data: products,
      total,
      page,
      limit,
      totalPages,
    };
  }

  async findOne(id: string): Promise<ProductResponseDto> {
    const product = await this.prisma.products.findUnique({
      where: { id },
    });

    if (!product) {
      throw new NotFoundException(
        this.i18nService.translate('error.PRODUCT_NOT_FOUND'),
      );
    }

    return product;
  }

  async findByUserId(userId: string): Promise<ProductResponseDto[]> {
    return await this.prisma.products.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async update(
    id: string,
    updateProductDto: UpdateProductDto,
  ): Promise<ProductResponseDto> {
    await this.findOne(id);

    return await this.prisma.products.update({
      where: { id },
      data: updateProductDto,
    });
  }

  async remove(id: string): Promise<{ message: string }> {
    await this.findOne(id);

    await this.prisma.products.delete({
      where: { id },
    });

    return {
      message: this.i18nService.translate('common.PRODUCT_DELETED'),
    };
  }

  async getProductCountByUser(userId: string): Promise<number> {
    return await this.prisma.products.count({
      where: { userId },
    });
  }
}
