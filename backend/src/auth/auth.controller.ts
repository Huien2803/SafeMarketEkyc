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
import { Throttle } from '@nestjs/throttler';
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
import {
  ForgotPasswordDto,
  ResetPasswordDto,
} from './dto/password-reset.dto';
import { LogoutDto, RefreshTokenDto } from './dto/refresh.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../entities/user.entity';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register/request-otp')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
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
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiOperation({ summary: 'Xác thực OTP và tạo tài khoản' })
  @ApiResponse({ status: 201, type: AuthResponseDto })
  @ApiResponse({ status: 400, description: 'OTP sai hoặc hết hạn' })
  verifyOtp(@Body() dto: VerifyOtpDto): Promise<AuthResponseDto> {
    return this.authService.verifyRegistrationOtp(dto.email, dto.otp);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiOperation({ summary: 'Đăng nhập bằng email hoặc SĐT' })
  @ApiResponse({ status: 200, type: AuthResponseDto })
  @ApiResponse({ status: 401, description: 'Sai thông tin đăng nhập' })
  login(@Body() dto: LoginDto): Promise<AuthResponseDto> {
    return this.authService.login(dto);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @ApiOperation({ summary: 'Làm mới access token bằng refresh token' })
  @ApiResponse({ status: 200, type: AuthResponseDto })
  @ApiResponse({ status: 401, description: 'Refresh token không hợp lệ' })
  refresh(@Body() dto: RefreshTokenDto): Promise<AuthResponseDto> {
    return this.authService.refresh(dto.refreshToken);
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đăng xuất — thu hồi refresh token' })
  @ApiResponse({ status: 200, description: 'Đã đăng xuất' })
  logout(@Body() dto: LogoutDto): Promise<{ message: string }> {
    return this.authService.logout(dto.refreshToken);
  }

  @Post('password/forgot')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiOperation({ summary: 'Quên mật khẩu — gửi OTP về email' })
  @ApiResponse({ status: 200, type: RequestOtpResponseDto })
  async forgotPassword(
    @Body() dto: ForgotPasswordDto,
  ): Promise<RequestOtpResponseDto> {
    const r = await this.authService.requestPasswordResetOtp(dto.email);
    return {
      email: r.email,
      expiresInSeconds: r.expiresInSeconds,
      message: r.devOtp
        ? 'SMTP chưa cấu hình — dùng mã OTP hiển thị trên app để test.'
        : 'Nếu email tồn tại, mã OTP đặt lại mật khẩu đã được gửi. Mã có hiệu lực 5 phút.',
      devOtp: r.devOtp,
    };
  }

  @Post('password/reset')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiOperation({ summary: 'Đặt lại mật khẩu bằng OTP' })
  @ApiResponse({ status: 200, description: 'Đặt lại mật khẩu thành công' })
  @ApiResponse({ status: 400, description: 'OTP sai hoặc hết hạn' })
  resetPassword(@Body() dto: ResetPasswordDto): Promise<{ message: string }> {
    return this.authService.resetPassword(dto.email, dto.otp, dto.newPassword);
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
