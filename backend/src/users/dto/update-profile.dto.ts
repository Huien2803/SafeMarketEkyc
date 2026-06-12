import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import {
  DISPLAY_NAME_MESSAGE,
  DISPLAY_NAME_PATTERN,
  VN_PHONE_MESSAGE,
  VN_PHONE_PATTERN,
} from '../../common/validation.constants';

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: 'Nguyễn Văn An' })
  @IsOptional()
  @IsString()
  @MinLength(2, { message: 'Họ và tên tối thiểu 2 ký tự' })
  @MaxLength(100)
  @Matches(DISPLAY_NAME_PATTERN, { message: DISPLAY_NAME_MESSAGE })
  displayName?: string;

  @ApiPropertyOptional({ example: '0912345678' })
  @IsOptional()
  @IsString()
  @Matches(VN_PHONE_PATTERN, { message: VN_PHONE_MESSAGE })
  phoneNumber?: string;

  @ApiPropertyOptional({ example: 'Quận 1, TP.HCM' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  location?: string;

  @ApiPropertyOptional({ example: 'https://example.com/avatar.jpg' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  avatarUrl?: string;
}
