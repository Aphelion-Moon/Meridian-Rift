import { inflateSync } from 'node:zlib';

const signature = Buffer.from('89504e470d0a1a0a', 'hex');
const crcTable = Array.from({ length: 256 }, (_, n) => {
  for (let k = 0; k < 8; k++) n = (n & 1) ? (0xedb88320 ^ (n >>> 1)) : n >>> 1;
  return n >>> 0;
});
function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) crc = crcTable[(crc ^ byte) & 255] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

/** Validate the actual PNG stream, including checksums and decompressed bounds. */
export function inspectPng(bytes) {
  const bad = () => { throw new Error('Invalid or unsupported PNG'); };
  if (bytes.length < 45 || !bytes.subarray(0, 8).equals(signature)) bad();
  let offset = 8, header, ended = false, sawData = false, dataClosed = false, palette = false;
  const data = [];
  while (offset < bytes.length) {
    if (offset + 12 > bytes.length) bad();
    const length = bytes.readUInt32BE(offset), end = offset + 12 + length;
    if (end > bytes.length) bad();
    const type = bytes.toString('ascii', offset + 4, offset + 8), content = bytes.subarray(offset + 8, end - 4);
    if (!/^[A-Za-z]{4}$/.test(type) || crc32(bytes.subarray(offset + 4, end - 4)) !== bytes.readUInt32BE(end - 4)) bad();
    if (!header && type !== 'IHDR') bad();
    if (type === 'IHDR') {
      if (header || length !== 13) bad();
      const width = content.readUInt32BE(0), height = content.readUInt32BE(4), depth = content[8], color = content[9];
      if (!width || !height || width > 1024 || height > 1024 || !({ 0: [1, 2, 4, 8, 16], 2: [8, 16], 3: [1, 2, 4, 8], 4: [8, 16], 6: [8, 16] }[color]?.includes(depth)) || content[10] !== 0 || content[11] !== 0 || content[12] > 1) bad();
      header = { width, height, depth, color, interlace: content[12] };
    } else if (type === 'IDAT') {
      if (dataClosed || (header.color === 3 && !palette)) bad();
      sawData = true; data.push(content);
    } else if (type === 'PLTE') {
      if (palette || sawData || !length || length % 3 || length > 768 || [0, 4].includes(header.color) || (header.color === 3 && length / 3 > 2 ** header.depth)) bad();
      palette = true;
    } else if (type === 'IEND') {
      if (length || !sawData || end !== bytes.length) bad();
      ended = true;
    } else {
      if (sawData) dataClosed = true;
      if (type[0] === type[0].toUpperCase() && type !== 'PLTE') bad();
    }
    offset = end;
  }
  if (!ended) bad();
  const channels = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[header.color];
  const passes = header.interlace ? [[0, 0, 8, 8], [4, 0, 8, 8], [0, 4, 4, 8], [2, 0, 4, 4], [0, 2, 2, 4], [1, 0, 2, 2], [0, 1, 1, 2]] : [[0, 0, 1, 1]];
  let expected = 0;
  const rows = [];
  for (const [x, y, dx, dy] of passes) {
    const w = Math.max(0, Math.ceil((header.width - x) / dx)), h = Math.max(0, Math.ceil((header.height - y) / dy));
    if (!w || !h) continue;
    const size = Math.ceil(w * channels * header.depth / 8) + 1;
    expected += size * h; rows.push([size, h]);
  }
  const raw = inflateSync(Buffer.concat(data), { maxOutputLength: expected + 1 });
  if (raw.length !== expected) bad();
  offset = 0;
  for (const [size, count] of rows) for (let i = 0; i < count; i++) {
    if (raw[offset] > 4) bad();
    offset += size;
  }
  return { width: header.width, height: header.height };
}
