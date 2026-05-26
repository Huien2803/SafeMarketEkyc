import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from '../entities/user.entity';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { JwtPayload } from './strategies/jwt.strategy';

const BCRYPT_ROUNDS = 10;

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(dto: RegisterDto): Promise<AuthResponseDto> {
    const existing = await this.userRepo.findOne({
      where: [{ email: dto.email }, { phoneNumber: dto.phoneNumber }],
    });
    if (existing) {
      throw new ConflictException(
        existing.email === dto.email
          ? 'Email đã được sử dụng'
          : 'Số điện thoại đã được sử dụng',
      );
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);

    const user = this.userRepo.create({
      phoneNumber: dto.phoneNumber,
      email: dto.email,
      passwordHash,
      displayName: dto.displayName ?? null,
      location: dto.location ?? null,
      kycStatus: 'Unverified',
      accountStatus: 'Active',
      isAdmin: false,
    });

    const saved = await this.userRepo.save(user);
    return this.buildAuthResponse(saved);
  }

  async login(dto: LoginDto): Promise<AuthResponseDto> {
    const user = await this.userRepo.findOne({
      where: [{ email: dto.identifier }, { phoneNumber: dto.identifier }],
    });
    if (!user) {
      throw new UnauthorizedException('Email/SĐT hoặc mật khẩu không đúng');
    }

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('Email/SĐT hoặc mật khẩu không đúng');
    }

    if (user.accountStatus !== 'Active') {
      throw new UnauthorizedException(
        `Tài khoản đang bị ${
          user.accountStatus === 'Locked' ? 'khoá' : 'cấm'
        }${user.lockReason ? `: ${user.lockReason}` : ''}`,
      );
    }

    return this.buildAuthResponse(user);
  }

  private buildAuthResponse(user: User): AuthResponseDto {
    const payload: JwtPayload = {
      sub: Number(user.userId),
      email: user.email,
      isAdmin: !!user.isAdmin,
    };

    const expiresIn = this.parseDurationSeconds(
      this.config.get<string>('JWT_EXPIRES_IN', '7d'),
    );
    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      tokenType: 'Bearer',
      expiresIn,
      user: {
        userId: Number(user.userId),
        email: user.email,
        phoneNumber: user.phoneNumber,
        displayName: user.displayName,
        kycStatus: user.kycStatus,
        accountStatus: user.accountStatus,
        isAdmin: !!user.isAdmin,
      },
    };
  }

  private parseDurationSeconds(input: string): number {
    const match = /^(\d+)([smhd])?$/.exec(input);
    if (!match) {
      throw new BadRequestException(`JWT_EXPIRES_IN không hợp lệ: ${input}`);
    }
    const value = Number(match[1]);
    const unit = match[2] ?? 's';
    const multiplier: Record<string, number> = {
      s: 1,
      m: 60,
      h: 3600,
      d: 86400,
    };
    return value * multiplier[unit];
  }
}
