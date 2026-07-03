import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { AuthResponseDto, AuthUserDto } from './dto/auth-response.dto';
import {
  RequestOtpResponseDto,
  VerifyOtpDto,
} from './dto/verify-otp.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register/request-otp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Gửi mã OTP về email để bắt đầu đăng ký (chống mail ảo)',
  })
  @ApiResponse({ status: 200, type: RequestOtpResponseDto })
  @ApiResponse({ status: 409, description: 'Email hoặc SĐT đã tồn tại' })
  async requestOtp(@Body() dto: RegisterDto): Promise<RequestOtpResponseDto> {
    const r = await this.authService.requestRegistrationOtp(dto);
    return {
      email: r.email,
      expiresInSeconds: r.expiresInSeconds,
      message: r.devOtp
        ? 'SMTP chưa cấu hình — dùng mã OTP hiển thị trên app để test.'
        : 'Đã gửi mã OTP tới email của bạn. Mã có hiệu lực 5 phút.',
      devOtp: r.devOtp,
    };
  }

  @Post('register/verify-otp')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Xác thực OTP và tạo tài khoản' })
  @ApiResponse({ status: 201, type: AuthResponseDto })
  @ApiResponse({ status: 400, description: 'OTP sai hoặc hết hạn' })
  verifyOtp(@Body() dto: VerifyOtpDto): Promise<AuthResponseDto> {
    return this.authService.verifyRegistrationOtp(dto.email, dto.otp);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đăng nhập bằng email hoặc SĐT' })
  @ApiResponse({ status: 200, type: AuthResponseDto })
  @ApiResponse({ status: 401, description: 'Sai thông tin đăng nhập' })
  login(@Body() dto: LoginDto): Promise<AuthResponseDto> {
    return this.authService.login(dto);
  }

  @Get('me')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Thông tin tài khoản đang đăng nhập' })
  @ApiResponse({ status: 200, type: AuthUserDto })
  me(@CurrentUser() user: User): AuthUserDto {
    return {
      userId: Number(user.userId),
      email: user.email,
      phoneNumber: user.phoneNumber,
      displayName: user.displayName,
      kycStatus: user.kycStatus,
      accountStatus: user.accountStatus,
      isAdmin: !!user.isAdmin,
    };
  }
}
