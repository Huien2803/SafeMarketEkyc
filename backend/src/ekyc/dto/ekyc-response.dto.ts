import { ApiProperty } from '@nestjs/swagger';

export class ScanIdFrontResponseDto {
  @ApiProperty({ example: '079203001234', description: 'Số CCCD/CMND' })
  idNumber: string;

  @ApiProperty({ example: 'NGUYỄN VĂN AN', description: 'Họ và tên trên CCCD' })
  fullName: string;

  @ApiProperty({ example: '15/05/1998', description: 'Ngày sinh dd/MM/yyyy' })
  dob: string;

  @ApiProperty({ example: 'NAM' })
  sex: string;

  @ApiProperty({ example: 'VIỆT NAM' })
  nationality: string;

  @ApiProperty({ example: 'TP. Hồ Chí Minh', description: 'Quê quán' })
  home: string;

  @ApiProperty({ example: '123 Lê Lợi, Quận 1, TP.HCM', description: 'Nơi thường trú' })
  address: string;

  @ApiProperty({ example: '15/05/2033', description: 'Ngày hết hạn' })
  doe: string;

  @ApiProperty({ example: 'cccd', description: 'cccd | cmnd | chip_front' })
  type: string;
}

export class ScanIdBackResponseDto {
  @ApiProperty({ example: 'Sẹo chấm c: 1cm trên trán', description: 'Đặc điểm nhận dạng' })
  features: string;

  @ApiProperty({ example: '01/01/2021', description: 'Ngày cấp' })
  issueDate: string;

  @ApiProperty({ example: 'Cục Cảnh sát ĐKQL cư trú và DLQG về dân cư' })
  issueLoc: string;
}

export class FaceMatchResponseDto {
  @ApiProperty({ example: true, description: 'true nếu cùng một người' })
  isMatch: boolean;

  @ApiProperty({ example: 0.92, description: 'Độ giống nhau 0..1' })
  similarity: number;

  @ApiProperty({ example: 'Khuôn mặt khớp' })
  message: string;
}
