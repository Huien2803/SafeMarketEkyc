import { Controller, Get, NotFoundException } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { DevService } from './dev.service';

@ApiTags('dev')
@Controller('dev')
export class DevController {
  constructor(
    private readonly devService: DevService,
    private readonly config: ConfigService,
  ) {}

  private assertDev() {
    if (this.config.get<string>('NODE_ENV') === 'production') {
      throw new NotFoundException();
    }
  }

  @Get('client-config')
  @ApiOperation({
    summary: 'Cấu hình URL cho app Flutter (chỉ development)',
  })
  clientConfig() {
    this.assertDev();
    return this.devService.getClientConfig();
  }

  @Get('phone-setup')
  @ApiOperation({
    summary: 'Chạy lại adb reverse (chỉ development)',
  })
  async phoneSetup() {
    this.assertDev();
    const logs = await this.devService.runPhoneSetup();
    return { ok: true, logs };
  }
}
