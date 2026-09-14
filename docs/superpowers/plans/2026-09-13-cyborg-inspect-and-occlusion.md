# Cyborg inspect and occlusion follow-up

Scope: preserve the playtested offsets and named-preset behavior; correct live occlusion, inspect portrait framing, and cyborg profile notes.

## Findings and implementation

1. The live part container uses `KEEP_TOGETHER` but does not set its image layer. Its child layers cannot lower the whole group below the separately rendered chassis mask. Give the group an explicit `ABOVE_MOB_LAYER`, below the existing mask. Preserve owner-relative geometry, animation, and viewer gates. [BYOND's image and appearance-flags reference](https://www.byond.com/docs/ref/info.html) describes the image default layer and grouped drawing behavior.
2. Inspect puts a sprite in a single-tile map view, discards its horizontal offset, and resets its transform. Extract the existing portrait construction into `preview_appearance()`, center the full icon canvas on the tile, and scale oversized canvases to fit. Clear W/Z world shifts as well as X/Y. Normal 32-pixel portraits retain their existing size. This framing intentionally normalizes portraits instead of depicting world-scale comparisons.
3. Add a character-saved `ooc_notes_silicon_nsfw` field using the existing bounded text preference. Both SFW and NSFW cyborg notes use the corresponding human field only when empty. Preserve the inspect panel's adult preference summary prefix. Label the flavor sections `SFW Flavor Text` and `NSFW Flavor Text`.
4. Add reusable placeholder metadata to preference inputs. The two OOC textareas explain their fallback inside the empty input; placeholder text is never saved as notes.

## Verification plan

- Reproduce the native layer ordering and wide-portrait bounds failures before fixing them.
- Check portrait bounds across the model catalog and preserve live-mob placement.
- Check SFW/NSFW fallback, independent overrides, clearing, and persistence.
- Run the cyborg native test group, frontend tests, typecheck, scoped formatting, and production build.
- Reopen Setup Character and inspect in a rebuilt game for human acceptance: East/West occlusion at rest and walking; complete centered wide portraits; both OOC fallbacks and overrides.

## Validation results

- Native red run reproduced all three failures: unordered part container, inherited portrait W shift, and missing saved NSFW notes. Frontend red tests reproduced the old flavor labels and missing placeholder.
- All 29 focused native cyborg tests passed. The portrait test checks centering and fit across the model catalog; the notes test checks matching human fallbacks, independent cyborg overrides, save/reload, and clearing. Existing offset, scaling, preset, and lifecycle regressions remain green.
- Final native artifacts: `data/logs/cyborg-inspect-final-20260913/clean_run.lk` contains `Success!`; runtime log contains `Shutdown complete` and no runtime exception/failure markers. The Windows launcher returned 19984; acceptance uses the result JSON and clean shutdown artifacts. The owned process exited naturally.
- Production `BUILD.cmd`: DM 516.1687, zero errors and warnings; Rspack succeeded. After the final profile grouping edit, the TGUI build succeeded again. Focused native compilation had only the two existing test instrumentation warnings.
- Frontend suite: 60 passed, zero failed. The four affected profile/placeholder tests passed again after the final layout edit. TypeScript passed; scoped Biome, SCSS formatting, and `git diff --check` passed.
- Browser review at 1200 by 940: both OOC fields share an aligned row, bottom edges at 788.56px. Inspector client/scroll heights are both 725px, so the profile needs no internal scrollbar at that size. Both placeholders appear in empty fields; typing hides the SFW placeholder while the untouched NSFW placeholder remains visible. Narrow layouts stack the fields.
- Temporary native binaries, DME includes, test server, browser tab, viewport override, and fixture server were cleaned up. Previous `data/unit_tests.json` was restored byte-for-byte. No commit, push, or live-server restart was performed.

## Next playtest

Restart using the rebuilt game, then reopen Setup Character and inspect. Check East/West chassis occlusion while stationary and walking, complete centered wide portraits, and each OOC field with blank text, an override, and then cleared text. DreamSeeker raster output and multiplayer acceptance remain human checks; native ordering/bounds assertions and browser fixtures do not substitute for them.
