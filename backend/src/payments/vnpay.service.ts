import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import * as querystring from 'querystring';

export interface VnpayCreateResult {
  paymentUrl: string;
  txnRef: string;
}

@Injectable()
export class VnpayService {
  constructor(private readonly config: ConfigService) {}

  isConfigured(): boolean {
    return !!(
      this.config.get<string>('VNPAY_TMN_CODE') &&
      this.config.get<string>('VNPAY_HASH_SECRET')
    );
  }

  createPaymentUrl(input: {
    amount: number;
    orderId: number;
    orderInfo: string;
    ipAddr: string;
  }): VnpayCreateResult {
    const tmnCode = this.config.get<string>('VNPAY_TMN_CODE', '');
    const hashSecret = this.config.get<string>('VNPAY_HASH_SECRET', '');
    const vnpUrl = this.config.get<string>(
      'VNPAY_URL',
      'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html',
    );
    const returnUrl = this.config.get<string>(
      'VNPAY_RETURN_URL',
      'http://localhost:3000/api/payments/vnpay-return',
    );

    const txnRef = `SM${input.orderId}${Date.now()}`.slice(0, 32);
    const createDate = this.formatDate(new Date());

    const params: Record<string, string | number> = {
      vnp_Version: '2.1.0',
      vnp_Command: 'pay',
      vnp_TmnCode: tmnCode,
      vnp_Amount: Math.round(input.amount) * 100,
      vnp_CurrCode: 'VND',
      vnp_TxnRef: txnRef,
      vnp_OrderInfo: input.orderInfo.slice(0, 255),
      vnp_OrderType: 'other',
      vnp_Locale: 'vn',
      vnp_ReturnUrl: returnUrl,
      vnp_IpAddr: input.ipAddr || '127.0.0.1',
      vnp_CreateDate: createDate,
    };

    const signed = this.signParams(params, hashSecret);
    const url = `${vnpUrl}?${signed}`;
    return { paymentUrl: url, txnRef };
  }

  verifyCallback(query: Record<string, string>): {
    valid: boolean;
    success: boolean;
    txnRef: string;
    amount: number;
    responseCode: string;
  } {
    const hashSecret = this.config.get<string>('VNPAY_HASH_SECRET', '');
    const secureHash = query.vnp_SecureHash;
    const params = { ...query };
    delete params.vnp_SecureHash;
    delete params.vnp_SecureHashType;

    const signed = this.signParams(
      this.normalizeParams(params),
      hashSecret,
    ).split('=').pop() ?? '';
    const valid = secureHash === signed;
    const responseCode = query.vnp_ResponseCode ?? '';
    const success = valid && responseCode === '00';
    const amount = parseInt(query.vnp_Amount ?? '0', 10) / 100;
    return {
      valid,
      success,
      txnRef: query.vnp_TxnRef ?? '',
      amount,
      responseCode,
    };
  }

  private signParams(
    params: Record<string, string | number>,
    hashSecret: string,
  ): string {
    const sorted = this.sortObject(params);
    const signData = querystring.stringify(sorted, null, null, {
      encodeURIComponent: querystring.unescape,
    });
    const hmac = crypto.createHmac('sha512', hashSecret);
    hmac.update(Buffer.from(signData, 'utf-8'));
    const secureHash = hmac.digest('hex');
    return `${signData}&vnp_SecureHash=${secureHash}`;
  }

  private sortObject(
    obj: Record<string, string | number>,
  ): Record<string, string | number> {
    const sorted: Record<string, string | number> = {};
    const keys = Object.keys(obj).sort();
    for (const key of keys) {
      const val = obj[key];
      if (val !== undefined && val !== null && val !== '') {
        sorted[key] = val;
      }
    }
    return sorted;
  }

  private normalizeParams(
    query: Record<string, string>,
  ): Record<string, string | number> {
    const out: Record<string, string | number> = {};
    for (const [k, v] of Object.entries(query)) {
      if (k.startsWith('vnp_') && v !== '') out[k] = v;
    }
    return out;
  }

  private formatDate(d: Date): string {
    const pad = (n: number) => n.toString().padStart(2, '0');
    return (
      `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}` +
      `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
    );
  }
}
