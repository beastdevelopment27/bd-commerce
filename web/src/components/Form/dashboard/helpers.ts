export function getDiscountedPrice(price: number, discount: number): number {
  const safePrice = Number.isFinite(price) ? price : 0;
  const safeDiscount = Math.min(Math.max(Number.isFinite(discount) ? discount : 0, 0), 100);
  return safePrice - (safePrice * safeDiscount) / 100;
}

export function toMoney(value: number, formatter: Intl.NumberFormat): string {
  return `$${formatter.format(Number.isFinite(value) ? value : 0)}`;
}

export const MONTH_LABELS = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
];
