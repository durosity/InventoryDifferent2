export function formatCurrency(value: number, locale: string, currencyCode: string): string {
  return new Intl.NumberFormat(locale, { style: "currency", currency: currencyCode }).format(value);
}

function getCurrencySymbolInfo(
  locale: string,
  currencyCode: string
): { symbol: string; isPrefix: boolean } {
  const parts = new Intl.NumberFormat(locale, { style: "currency", currency: currencyCode }).formatToParts(1);
  const symbol = parts.find((p) => p.type === "currency")?.value ?? currencyCode;
  const isPrefix = parts[0]?.type === "currency";
  return { symbol, isPrefix };
}

export function formatCurrencyCompact(value: number, locale: string, currencyCode: string): string {
  const { symbol, isPrefix } = getCurrencySymbolInfo(locale, currencyCode);
  const abs = Math.abs(value);
  const sign = value < 0 ? "-" : "";
  const numStr = abs >= 1000 ? `${(abs / 1000).toFixed(1)}k` : abs.toFixed(0);
  return isPrefix ? `${sign}${symbol}${numStr}` : `${sign}${numStr} ${symbol}`;
}
