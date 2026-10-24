// THIS IS AN APHELION UI FILE

/** A face as the page's FontFaceSet holds it */
export type DrawnFace = Pick<
  FontFace,
  'family' | 'style' | 'weight' | 'stretch' | 'unicodeRange' | 'status'
>;

/** A @font-face rule, as far as telling its face goes */
export type FaceRule = { style: Pick<CSSStyleDeclaration, 'getPropertyValue'> };

/** The descriptors that pick a face, as one key that reads the same from a FontFace and from its @font-face rule */
function faceKey(
  family: string,
  style: string,
  weight: string,
  stretch: string,
  unicodeRange: string,
) {
  return [
    family.trim().replace(/["']/g, ''),
    style || 'normal',
    weight || 'normal',
    stretch || 'normal',
    unicodeRange || 'U+0-10FFFF',
  ].join('|');
}

/**
 * Which @font-face rules a snapshot needs. The page loads a face only to draw a glyph with it, as a fallback too,
 * so a face it never loaded drew nothing and the SVG draws the same without it. A rule no face answers goes in
 */
export function drawnFontFaces(
  faces: { forEach(callback: (face: DrawnFace) => void): void } | undefined,
): ((rule: FaceRule) => boolean) | null {
  if (!faces) return null;
  const known = new Set<string>();
  const drawn = new Set<string>();
  faces.forEach((face) => {
    const key = faceKey(
      face.family,
      face.style,
      face.weight,
      face.stretch,
      face.unicodeRange,
    );
    known.add(key);
    if (face.status !== 'unloaded') drawn.add(key);
  });
  return (rule) => {
    const read = (name: string) => rule.style.getPropertyValue(name);
    const key = faceKey(
      read('font-family'),
      read('font-style'),
      read('font-weight'),
      read('font-stretch'),
      read('unicode-range'),
    );
    return drawn.has(key) || !known.has(key);
  };
}
