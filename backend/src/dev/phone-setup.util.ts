import { execFile } from 'child_process';
import { existsSync } from 'fs';
import { join } from 'path';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

function adbPath(): string | null {
  const local = process.env.LOCALAPPDATA ?? '';
  const candidates = [
    join(local, 'Android', 'Sdk', 'platform-tools', 'adb.exe'),
    join(local, 'Android', 'Sdk', 'platform-tools', 'adb'),
  ];
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  return null;
}

/** adb reverse + liệt kê thiết bị (dev Windows). */
export async function setupPhoneDevTools(port: number): Promise<string[]> {
  const logs: string[] = [];
  const adb = adbPath();
  if (!adb) {
    logs.push('adb: không tìm thấy (cài Android SDK platform-tools).');
    return logs;
  }

  try {
    await execFileAsync(adb, ['start-server'], { windowsHide: true });
    logs.push('adb: start-server OK');
  } catch (e) {
    logs.push(`adb start-server: ${(e as Error).message}`);
  }

  try {
    const { stdout } = await execFileAsync(adb, ['devices'], {
      windowsHide: true,
    });
    const lines = stdout
      .split(/\r?\n/)
      .map((l) => l.trim())
      .filter((l) => l && !l.startsWith('List'));
    logs.push(
      lines.length
        ? `adb devices: ${lines.join(' | ')}`
        : 'adb devices: (chưa có máy — bật USB debugging / wireless)',
    );
  } catch (e) {
    logs.push(`adb devices: ${(e as Error).message}`);
  }

  try {
    await execFileAsync(
      adb,
      ['reverse', `tcp:${port}`, `tcp:${port}`],
      { windowsHide: true },
    );
    logs.push(`adb reverse: tcp:${port} → tcp:${port} OK`);
  } catch (e) {
    logs.push(`adb reverse: ${(e as Error).message}`);
  }

  return logs;
}
