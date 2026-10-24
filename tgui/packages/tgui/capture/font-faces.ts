// THIS IS AN APHELION UI FILE

/** A face as the page's FontFaceSet holds it */
export type DrawnFace = Pick<
  FontFace,
  'family' | 'style' | 'weight' | 'stretch' | 'unicodeRange' | 'status'
>;

/** A @font-face rule, as far as telling its face goes */
export type FaceRule = { style: Pick<CSSStyleDeclaration, 'getPropertyValue'> };

/** The unicode-range of a face whose rule leaves it out */
const WHOLE_RANGE = 'U+0-10FFFF';

/** The descriptors besides unicode-range that pick a face, as one key that reads the same from a FontFace and its rule */
function faceShape(
  family: string,
  style: string,
  weight: string,
  stretch: string,
) {
  return [
    family.trim().replace(/["']/g, ''),
    style || 'normal',
    weight || 'normal',
    stretch || 'normal',
  ].join('|');
}

/**
 * Which @font-face rules a snapshot needs. The page loads a face only to draw a glyph with it, as a fallback too,
 * so a whole-range face it never loaded was picked by no text and the SVG draws the same without it. A part-range
 * face is picked for its style, weight and stretch before its range is checked, so text outside its range falls
 * through to the next family without loading it, and without that face the SVG would pick another weight. So an
 * unloaded part-range face stays out only beside a drawn face of the same style, weight and stretch. A rule no face
 * answers goes in
 */
export function drawnFontFaces(
  faces: { forEach(callback: (face: DrawnFace) => void): void } | undefined,
): ((rule: FaceRule) => boolean) | null {
  if (!faces) return null;
  const known = new Set<string>();
  const drawn = new Set<string>();
  const drawnShapes = new Set<string>();
  faces.forEach((face) => {
    const shape = faceShape(face.family, face.style, face.weight, face.stretch);
    const key = `${shape}|${face.unicodeRange || WHOLE_RANGE}`;
    known.add(key);
    if (face.status === 'unloaded') return;
    drawn.add(key);
    drawnShapes.add(shape);
  });
  return (rule) => {
    const read = (name: string) => rule.style.getPropertyValue(name);
    const shape = faceShape(
      read('font-family'),
      read('font-style'),
      read('font-weight'),
      read('font-stretch'),
    );
    const range = read('unicode-range') || WHOLE_RANGE;
    const key = `${shape}|${range}`;
    return (
      drawn.has(key) ||
      !known.has(key) ||
      (range !== WHOLE_RANGE && !drawnShapes.has(shape))
    );
  };
}
