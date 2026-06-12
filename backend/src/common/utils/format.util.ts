/** Định dạng VND cho Flutter (vd: 15.500.000 đ) */
export function formatVnd(amount: number): string {
  const n = Math.round(amount);
  const s = n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return `${s} đ`;
}

export const PAYMENT_LABELS: Record<string, string> = {
  BANK_TRANSFER: 'Chuyển khoản',
  CASH: 'Tiền mặt',
};

export const DELIVERY_LABELS: Record<string, string> = {
  SHIP: 'Giao ship',
  DIRECT: 'Giao trực tiếp',
};
