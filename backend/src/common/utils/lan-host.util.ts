import { networkInterfaces } from 'os';

/** IPv4 LAN của PC (192.168.x / 10.x) — dùng cho app điện thoại dev. */
export function getLanIPv4(): string | null {
  const nets = networkInterfaces();
  const candidates: string[] = [];

  for (const name of Object.keys(nets)) {
    for (const net of nets[name] ?? []) {
      const family = net.family as string | number;
      const isV4 = family === 'IPv4' || family === 4;
      if (!isV4 || net.internal) continue;
      if (
        net.address.startsWith('192.168.') ||
        net.address.startsWith('10.')
      ) {
        candidates.push(net.address);
      }
    }
  }

  const preferred = candidates.find((ip) => ip.startsWith('192.168.'));
  return preferred ?? candidates[0] ?? null;
}
