// THIS IS AN APHELION UI FILE
import {
  drawPreviewFacing,
  type PreviewView,
} from '../CharacterPreview/drawing';
import type { SpriteDir } from '../SpeciesRegistry/constants';

const facings = new Map<string, string>();
// Every facing is drawn on this one canvas and read back as an image. It is
// kept on the CPU (willReadFrequently): a GPU canvas stalls the page on each read.
let canvas: HTMLCanvasElement | undefined;
let context: CanvasRenderingContext2D | null = null;

/** One facing of a drawing, its rows moved, as an image: what the rim light is masked by. */
export function facingImage(
  image: HTMLImageElement,
  preview: PreviewView['shown']['preview'],
  dir: SpriteDir,
) {
  const key = `${preview.id} ${dir}`;
  const known = facings.get(key);
  if (known) {
    return known;
  }
  if (!canvas) {
    canvas = document.createElement('canvas');
    context = canvas.getContext('2d', { willReadFrequently: true });
  }
  if (!context) {
    return undefined;
  }
  // Sizing it clears it.
  canvas.width = preview.width;
  canvas.height = preview.height;
  drawPreviewFacing(context, image, preview, dir);
  const url = canvas.toDataURL();
  if (facings.size > 16) {
    facings.clear();
  }
  facings.set(key, url);
  return url;
}
