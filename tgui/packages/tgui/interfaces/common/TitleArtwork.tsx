// THIS IS AN APHELION UI FILE

import type { CSSProperties } from 'react';
import { classes } from 'tgui-core/react';

export const LOBBY_TITLE_ART_VARIANTS = ['flat', 'edge', 'convex'] as const;

/**
 * The bezel used to be baked into the variant as `convex-bezel`, which meant
 * only a convex screen could have one. It is its own choice now; this maps the
 * stored value forward so saved settings keep working.
 */
const LEGACY_BEZEL_VARIANT = 'convex-bezel';

export type LobbyTitleArtVariant = (typeof LOBBY_TITLE_ART_VARIANTS)[number];

export const LOBBY_TITLE_BEZELS = [
  'rusty',
  'rusty-dark',
  'aphelion',
  'classic',
  'none',
] as const;
export type LobbyTitleBezel = (typeof LOBBY_TITLE_BEZELS)[number];

export const LOBBY_TITLE_TEXTURES = ['none', 'scanlines-light', 'scanlines-classic'] as const;

export type LobbyTitleTexture = (typeof LOBBY_TITLE_TEXTURES)[number];

export const LOBBY_TITLE_PRESENTATIONS = ['classic', 'classic-alt'] as const;

export type LobbyTitlePresentation = (typeof LOBBY_TITLE_PRESENTATIONS)[number];

export const LOBBY_TITLE_TREATMENTS = [
  'none',
  'mask',
  'overlay',
  'screen',
] as const;

/**
 * How the lobby renders the current title screen.
 *
 * `mask` tints a neutral alpha master with the active theme. `overlay` keeps a
 * finished picture at full colour and composites the themed wordmark above it.
 * `screen` is that same treated picture with no wordmark. `none` remains a
 * defensive fallback for an unmanaged/operator-provided picture; the title
 * screen manager no longer exposes an option that produces it.
 */
export type LobbyTitleTreatment = (typeof LOBBY_TITLE_TREATMENTS)[number];

export function resolveLobbyTitleTreatment(value?: string): LobbyTitleTreatment {
  return LOBBY_TITLE_TREATMENTS.includes(value as LobbyTitleTreatment)
    ? (value as LobbyTitleTreatment)
    : 'none';
}

// Virgin per-title records use the full CRT treatment. Keep the other
// controlled variants available for deliberate per-screen overrides.
export const DEFAULT_LOBBY_TITLE_ART_VARIANT: LobbyTitleArtVariant = 'convex';
export const DEFAULT_LOBBY_TITLE_BEZEL: LobbyTitleBezel = 'rusty-dark';
export const DEFAULT_LOBBY_TITLE_TEXTURE: LobbyTitleTexture = 'scanlines-classic';
export const DEFAULT_LOBBY_TITLE_PRESENTATION: LobbyTitlePresentation =
  'classic-alt';

export function resolveLobbyTitleArtVariant(
  value?: string,
): LobbyTitleArtVariant {
  if (value === LEGACY_BEZEL_VARIANT) {
    return 'convex';
  }
  return LOBBY_TITLE_ART_VARIANTS.includes(value as LobbyTitleArtVariant)
    ? (value as LobbyTitleArtVariant)
    : DEFAULT_LOBBY_TITLE_ART_VARIANT;
}

/** Preserve the original rim for old booleans and the retired combined effect. */
export function resolveLobbyTitleBezel(
  bezel: string | boolean | number | null | undefined,
  variant?: string,
): LobbyTitleBezel {
  if (LOBBY_TITLE_BEZELS.includes(bezel as LobbyTitleBezel)) {
    return bezel as LobbyTitleBezel;
  }
  if (bezel === false || bezel === 0) {
    return 'none';
  }
  if (bezel === true || bezel === 1) {
    return 'classic';
  }
  return bezel === undefined && variant === LEGACY_BEZEL_VARIANT
    ? 'classic'
    : DEFAULT_LOBBY_TITLE_BEZEL;
}

export function resolveLobbyTitleTexture(
  value?: string,
  hasClassicTexture = true,
): LobbyTitleTexture {
  if (value === 'none') {
    return 'none';
  }
  if (value === 'scanlines-light') {
    return 'scanlines-light';
  }
  if (value === 'scanlines-classic') {
    return hasClassicTexture ? 'scanlines-classic' : 'scanlines-light';
  }
  return hasClassicTexture ? DEFAULT_LOBBY_TITLE_TEXTURE : 'scanlines-light';
}

export function resolveLobbyTitlePresentation(
  value?: string,
): LobbyTitlePresentation {
  return LOBBY_TITLE_PRESENTATIONS.includes(value as LobbyTitlePresentation)
    ? (value as LobbyTitlePresentation)
    : DEFAULT_LOBBY_TITLE_PRESENTATION;
}

/**
 * The gradient-on-wordmark master is now the primary default. The option still
 * labelled "default, alt" deliberately retains the former classic treatment;
 * ordinary configured artwork is unaffected by the master swap.
 */
export function resolveLobbyScreenPresentation(
  treatment: LobbyTitleTreatment,
  isAlternateMaster: boolean,
): LobbyTitlePresentation {
  return treatment === 'mask' && !isAlternateMaster
    ? 'classic-alt'
    : 'classic';
}

function cssUrl(url: string): string {
  return `url("${url.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}")`;
}

export function TitleArtwork({
  bezel: bezelProp,
  markSrc,
  presentation: presentationProp,
  src,
  texture: textureProp,
  textureSrc,
  treatment: treatmentProp,
  variant: variantProp,
}: {
  /** The monitor rim, independent of the screen effect. */
  bezel?: LobbyTitleBezel | boolean | number;
  /** Neutral wordmark, composited over `src` in the overlay treatment. */
  markSrc?: string;
  presentation?: LobbyTitlePresentation;
  src: string;
  texture?: LobbyTitleTexture;
  textureSrc?: string;
  treatment?: LobbyTitleTreatment;
  variant?: LobbyTitleArtVariant;
}) {
  const treatment = resolveLobbyTitleTreatment(treatmentProp);

  // Overlay needs a wordmark to composite; without one there is nothing the
  // treatment can add, so fall back to the untouched picture.
  if (treatment === 'none' || (treatment === 'overlay' && !markSrc)) {
    return <img className="bg" src={src} alt="" />;
  }

  const requestedVariant =
    variantProp ?? document.documentElement.dataset.lobbyTitleVariant;
  const variant = resolveLobbyTitleArtVariant(requestedVariant);
  const bezel = resolveLobbyTitleBezel(bezelProp, requestedVariant);
  const requestedTexture =
    textureProp ?? document.documentElement.dataset.lobbyTitleTexture;
  const texture = resolveLobbyTitleTexture(requestedTexture, !!textureSrc);
  const presentation = resolveLobbyTitlePresentation(
    presentationProp ??
      (document.documentElement.dataset.lobbyTitleClassicAlt === 'true'
        ? 'classic-alt'
        : undefined),
  );
  // In mask treatment the screen image *is* the wordmark. In overlay it stays
  // the backdrop and the separate neutral master supplies the mark.
  const imageStyle = {
    '--lobby-title-art-image': cssUrl(treatment === 'overlay' ? markSrc! : src),
    '--lobby-title-backdrop-image': cssUrl(src),
  } as CSSProperties;
  const textureStyle = textureSrc
    ? ({
        '--lobby-title-scanline-image': cssUrl(textureSrc),
      } as CSSProperties)
    : undefined;

  return (
    <div
      aria-hidden="true"
      className={classes([
        'lobby-title-art',
        `lobby-title-art--${variant}`,
        // Namespaced: `treatment` already owns lobby-title-art--none, so an
        // unprefixed texture called "none" would silently collide with it.
        `lobby-title-art--texture-${texture}`,
        `lobby-title-art--${presentation}`,
        `lobby-title-art--${treatment}`,
        bezel !== 'none' && 'lobby-title-art--bezel',
        `lobby-title-art--bezel-${bezel}`,
      ])}
      data-bezel={bezel}
      data-presentation={presentation}
      data-texture={texture}
      data-treatment={treatment}
      data-variant={variant}
    >
      <div className="lobby-title-art__bezel">
        <div className="lobby-title-art__screen" style={imageStyle}>
          <img className="lobby-title-art__fallback" src={src} alt="" />
          {/* CSS enables these decorative copies only for Aphelion. */}
          {treatment !== 'screen' &&
            ['far', 'near'].map((layer) => (
              <div
                key={layer}
                className={`lobby-title-art__bloom lobby-title-art__bloom--${layer}`}
              >
                <div className="lobby-title-art__bloom-source" />
              </div>
            ))}
          <div className="lobby-title-art__mark" style={imageStyle} />
          <div className="lobby-title-art__scanlines" style={textureStyle} />
        </div>
      </div>
    </div>
  );
}
