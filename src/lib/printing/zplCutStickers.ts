export interface ThermalCutSticker {
  soNumber?: string | null;
  moNumber: string;
  stationCode: 'CUT-PROFILE' | 'CUT-ROLL';
  sku: string;
  itemName?: string | null;
  cutWidthMm?: number | null;
  cutHeightMm?: number | null;
  curtainWidthMm?: number | null;
  curtainHeightMm?: number | null;
  refId?: string | null;
}

function toAscii(input: string): string {
  return input
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[\^~\\]/g, ' ')
    .replace(/[^\x20-\x7E]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function trimText(input: string, maxLen: number): string {
  const cleaned = toAscii(input);
  return cleaned.length > maxLen ? `${cleaned.slice(0, Math.max(0, maxLen - 3))}...` : cleaned;
}

function mm(n?: number | null): string {
  if (n == null || Number.isNaN(Number(n))) return '-';
  return `${Math.round(Number(n))}`;
}

function buildSingleLabelZpl(label: ThermalCutSticker): string {
  const so = trimText(label.soNumber ?? '-', 20);
  const mo = trimText(label.moNumber || '-', 20);
  const station = label.stationCode;
  const sku = trimText(label.sku || '-', 26);
  const item = trimText(label.itemName || '-', 28);
  const cut = `${mm(label.cutWidthMm)}x${mm(label.cutHeightMm)} mm`;
  const curtain = `${mm(label.curtainWidthMm)}x${mm(label.curtainHeightMm)} mm`;
  const ref = trimText(label.refId || '-', 28);
  const qrPayload = toAscii(
    `SO:${so}|MO:${mo}|ST:${station}|SKU:${sku}|CUT:${cut}|CURTAIN:${curtain}|REF:${ref}`
  );

  // 4x1 in @203dpi -> width ~812 dots, height ~203 dots
  return [
    '^XA',
    '^PW812',
    '^LL203',
    '^LH0,0',
    `^FO12,8^A0N,22,22^FDSO ${so} | MO ${mo}^FS`,
    `^FO12,33^A0N,20,20^FD${station}^FS`,
    `^FO12,56^A0N,28,28^FD${sku}^FS`,
    `^FO12,89^A0N,24,24^FDCUT ${cut}^FS`,
    `^FO12,116^A0N,22,22^FDCURTAIN ${curtain}^FS`,
    `^FO12,141^A0N,20,20^FD${item}^FS`,
    `^FO12,165^A0N,18,18^FDREF ${ref}^FS`,
    `^FO650,20^BQN,2,4^FDLA,${qrPayload}^FS`,
    '^XZ',
  ].join('\n');
}

export function buildCutStickersZpl(labels: ThermalCutSticker[]): string {
  const printable = labels.filter((l) => l.stationCode === 'CUT-PROFILE' || l.stationCode === 'CUT-ROLL');
  return printable.map(buildSingleLabelZpl).join('\n');
}

