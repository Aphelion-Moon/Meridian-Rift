// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { crc32, inflateSync } from 'node:zlib';

const repositoryRoot = resolve(import.meta.dir, '../../..');
const titleScreenRoot = resolve(
  repositoryRoot,
  'modular_nova/modules/title_screen',
);
const fallbackPng = resolve(titleScreenRoot, 'icons/loading_screen.png');
const retiredGif = resolve(titleScreenRoot, 'icons/loading_screen.gif');

function readIdatPayload(png: Buffer) {
  const chunks: Buffer[] = [];
  let offset = 8;

  while (offset < png.byteLength) {
    const length = png.readUInt32BE(offset);
    const type = png.subarray(offset + 4, offset + 8).toString('ascii');
    if (type === 'IDAT') {
      chunks.push(png.subarray(offset + 8, offset + 8 + length));
    }
    offset += 12 + length;
  }

  return inflateSync(Buffer.concat(chunks));
}

/**
 * Every chunk's stored CRC against its actual contents.
 *
 * This file shipped for a while with a correct 1x1 transparent payload and a
 * wrong IDAT checksum, so the assertions below all passed while browsers
 * refused to decode it at all -- naturalWidth came back 0 and the startup
 * fallback rendered nothing.
 */
function chunkChecksums(png: Buffer) {
  const results: Array<{ type: string; ok: boolean }> = [];
  let offset = 8;

  while (offset < png.byteLength) {
    const length = png.readUInt32BE(offset);
    const type = png.subarray(offset + 4, offset + 8).toString('ascii');
    const body = png.subarray(offset + 4, offset + 8 + length);
    const stored = png.readUInt32BE(offset + 8 + length);
    results.push({ type, ok: crc32(body) >>> 0 === stored });
    offset += 12 + length;
  }

  return results;
}

describe('title-screen startup fallback', () => {
  it('is a real 1x1 transparent RGBA PNG rather than a renamed image', () => {
    const png = readFileSync(fallbackPng);

    expect(png.subarray(0, 8).toString('hex')).toBe('89504e470d0a1a0a');
    expect(png.readUInt32BE(16)).toBe(1);
    expect(png.readUInt32BE(20)).toBe(1);
    expect(png[24]).toBe(8);
    expect(png[25]).toBe(6);
    expect([...readIdatPayload(png)]).toEqual([0, 0, 0, 0, 0]);
    // A valid payload is not enough: a decoder rejects the whole file if any
    // chunk's checksum disagrees with it.
    expect(chunkChecksums(png)).toEqual([
      { type: 'IHDR', ok: true },
      { type: 'IDAT', ok: true },
      { type: 'IEND', ok: true },
    ]);
    expect(existsSync(retiredGif)).toBe(false);
  });

  it('uses the transparent fallback only after configured startup_splash', () => {
    const defines = readFileSync(
      resolve(titleScreenRoot, 'code/_title_screen_defines.dm'),
      'utf8',
    );
    const subsystem = readFileSync(
      resolve(titleScreenRoot, 'code/title_screen_subsystem.dm'),
      'utf8',
    );

    expect(defines).toContain(
      "#define DEFAULT_TITLE_LOADING_SCREEN 'modular_nova/modules/title_screen/icons/loading_screen.png'",
    );
    expect(defines).not.toContain('loading_screen.gif');

    const configuredSplash = subsystem.indexOf(
      'change_title_screen(startup_splash)',
    );
    const defaultFallback = subsystem.indexOf(
      'change_title_screen(DEFAULT_TITLE_LOADING_SCREEN)',
    );
    expect(configuredSplash).toBeGreaterThan(-1);
    expect(defaultFallback).toBeGreaterThan(configuredSplash);
  });
});
