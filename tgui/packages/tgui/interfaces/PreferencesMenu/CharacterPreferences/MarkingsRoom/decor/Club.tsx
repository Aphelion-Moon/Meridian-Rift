// THIS IS AN APHELION UI FILE
// The club room's decor (Cyberpunk and Augmentation), and the neon its mirror shares with Aphelion's.
import { memo } from 'react';

/** Tagged on the tiles behind the header: BEWARE, pun pun, and the bartender's monkey himself, furious about it. */
export const Header = memo(function ClubHeader() {
  return (
    <>
      <span className="AugmentsRoom__tag AugmentsRoom__tag--g1">BEWARE</span>
      <span className="AugmentsRoom__tag AugmentsRoom__tag--g2">pun pun</span>
      <svg
        className="AugmentsRoom__tag AugmentsRoom__tag--g3"
        viewBox="0 0 40 36"
        aria-hidden="true"
      >
        <path d="M11 25.6C8.6 21.6 8.8 15.4 12 11.8C14 9.6 16.4 8.6 19 8.6C21.6 8.6 24 9.6 26 11.8C29.2 15.4 29.4 21.6 27 25.6" />
        <path d="M10 16.8C6.4 14.8 3 17.6 4 21C4.9 24 8.6 24 10 21.8M7.2 18.6c-1.3.8-1.3 2.3-.2 3.1M28 16.6C31.6 14.6 35 17.4 34 20.8C33.1 23.8 29.4 23.8 28 21.6M30.8 18.4c1.3.8 1.3 2.3.2 3.1" />
        <path
          className="m"
          d="M19 14.4C17.6 12 13.6 12 13 15.2C12.6 17.4 13.6 19 12.4 21C10.6 24.6 12.4 31.4 19 31.6C25.6 31.4 27.4 24.6 25.6 21C24.4 19 25.4 17.4 25 15.2C24.4 12 20.4 12 19 14.4Z"
        />
        <path className="m" d="M14.2 15 17.6 16.8M23.8 15 20.4 16.8" />
        <path
          className="f"
          d="M15 18.2a1.2 1.2 0 1 0 2.4 0a1.2 1.2 0 1 0-2.4 0M20.6 18.2a1.2 1.2 0 1 0 2.4 0a1.2 1.2 0 1 0-2.4 0M17.3 21.2a.7.7 0 1 0 1.4 0a.7.7 0 1 0-1.4 0M19.3 21.2a.7.7 0 1 0 1.4 0a.7.7 0 1 0-1.4 0"
        />
        <path
          className="m"
          d="M13.6 23.6C16 22.8 22 22.8 24.4 23.6C24 29.6 14 29.6 13.6 23.6Z"
        />
        <path
          className="t"
          d="M14.6 23.6 16 26.4 17.4 23.3 19 26.6 20.6 23.3 22 26.4 23.4 23.6M16.2 28.6 17.4 26.6 18.6 28.9M19.4 28.9 20.6 26.6 21.8 28.6"
        />
      </svg>
    </>
  );
});

/** The club's neon round the glass: a tube above it, another down its side, and the four clips holding it. */
export const Tubes = memo(function ClubTubes() {
  return (
    <>
      <span className="MarkingsRoom__neon MarkingsRoom__neon--top" />
      <span className="MarkingsRoom__neon MarkingsRoom__neon--side" />
      <span className="MarkingsRoom__clip MarkingsRoom__clip--a" />
      <span className="MarkingsRoom__clip MarkingsRoom__clip--b" />
      <span className="MarkingsRoom__clip MarkingsRoom__clip--c" />
      <span className="MarkingsRoom__clip MarkingsRoom__clip--d" />
    </>
  );
});

/** What is stuck and scratched on the club's glass. */
export const Glass = memo(function ClubGlass() {
  return (
    <>
      <svg className="MarkingsRoom__crack" viewBox="0 0 332 520">
        <path
          className="MarkingsRoom__crackShadow"
          d="M318 12 296 38 284 44 262 70M318 12 326 46 320 78M318 12 300 15 276 9M296 38 304 60"
        />
        <path d="M318 12 296 38 284 44 262 70M318 12 326 46 320 78M318 12 300 15 276 9M296 38 304 60" />
      </svg>
      <svg className="MarkingsRoom__scratch" viewBox="0 0 332 520">
        <path d="M22 404c6-14 14-16 12-4-2 9-8 12-2 10 8-3 12-16 18-12 4 3-4 12 2 12 7 0 9-14 15-11 4 2-1 9 4 8M28 414c12 2 26-1 40-6" />
        <path d="M236 128c5-8 9-6 8 0s-6 8-1 7 7-9 11-6-2 8 3 7" />
      </svg>
      <span className="MarkingsRoom__sticker MarkingsRoom__sticker--future">
        NO FUTURE
      </span>
      <span className="MarkingsRoom__sticker MarkingsRoom__sticker--wake">
        wake up
      </span>
    </>
  );
});

/**
 * The stickers that glow under the blacklight, over the glass's decor, which
 * the dark dims: 404, and the game's harm intent in the club's neon with a
 * banana peel below it. Each pixel sticker holds its art in fluorescent inks,
 * shown when the lights go out.
 */
export const GlassAfter = memo(function ClubGlassAfter() {
  return (
    <>
      <span className="MarkingsRoom__sticker MarkingsRoom__sticker--404">
        404
      </span>
      <span className="MarkingsRoom__sticker MarkingsRoom__sticker--harm">
        <i className="MarkingsRoom__stickerUv" />
      </span>
      <span className="MarkingsRoom__sticker MarkingsRoom__sticker--peel">
        <i className="MarkingsRoom__stickerUv" />
      </span>
    </>
  );
});
