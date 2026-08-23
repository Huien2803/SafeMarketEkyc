import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { getLanIPv4 } from '../common/utils/lan-host.util';
import { setupPhoneDevTools } from './phone-setup.util';

@Injectable()
export class DevService {
  constructor(private readonly config: ConfigService) {}

  getClientConfig() {
    const port = parseInt(this.config.get<string>('PORT', '3000'), 10);
    const lanHost =
      this.config.get<string>('DEV_LAN_HOST', '').trim() || getLanIPv4();
    const host = lanHost ?? '127.0.0.1';
    const origin = `http://${host}:${port}`;

    return {
      apiBaseUrl: `${origin}/api`,
      mediaBaseUrl: origin,
      lanHost: host,
      port,
      phoneUrl: `${origin}/api/products/categories`,
      loopbackUrl: `http://127.0.0.1:${port}/api`,
      adbReverse: `adb reverse tcp:${port} tcp:${port}`,
      hint:
        'App Android: thử 127.0.0.1 (adb reverse) hoặc IP LAN cùng WiFi. ' +
        'Chỉ cần CHAY-BACKEND.bat — backend tự adb reverse khi khởi động.',
    };
  }

  async runPhoneSetup(): Promise<string[]> {
    if (this.config.get<string>('NODE_ENV') === 'production') {
      return ['Dev phone setup bị tắt trên production.'];
    }
    if (this.config.get<string>('DEV_AUTO_PHONE_SETUP', 'true') === 'false') {
      return ['DEV_AUTO_PHONE_SETUP=false — bỏ qua adb reverse.'];
    }
    const port = parseInt(this.config.get<string>('PORT', '3000'), 10);
    return setupPhoneDevTools(port);
  }
}
