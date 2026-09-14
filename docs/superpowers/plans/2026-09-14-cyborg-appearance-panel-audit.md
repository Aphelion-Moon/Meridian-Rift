# Cyborg Appearance panel audit

Scope: browser and source audit of the complete Appearance panel on `cyborg-customizer`, preserving the confirmed model defaults and native placement behavior.

## Findings corrected

| Finding | Cause and correction | Browser evidence |
| --- | --- | --- |
| Breasts button taller and wider | Core Button margins disappear on its last child. Remove button margins inside the Parts grid and let grid gaps own spacing. | Before: five buttons 124.89 by 20px; Breasts 126.92 by 22.03px. After: all six 126.92 by 20px. |
| Exact inputs and slider ends drift between units | Flex layout let `px`, degrees, percent, and empty units consume different widths. Use shared grid tracks and spacing variables for the slider, exact input, unit, and range labels. | All five override inputs start at X=1073px; every slider and maximum label ends at X=1067px. |
| Reset controls move during confirmation | Content-sized flex buttons change width when their labels become `Confirm?`. Use three equal grid columns. | All three widths remain 126.92px and their X positions stay fixed before and after confirmation. |
| Compact Identity panel is mostly hidden | The two-column breakpoint fixed the sidebar at 160px tall. Allocate flexible rows with usable minimums for both Identity and preview. | At the 920px fixture, Identity grows from 160px to 330px. Name, pronouns, size, pose, arousal, and layout source are visible together. |
| Disabled controls appear interactive | Native range and color inputs retained the pointer cursor and full opacity. Give disabled inputs a disabled cursor and faded styling. | Saved-model preview ranges and color inputs are disabled, opacity 0.5, with `not-allowed` cursors. |
| Part-drag instructions describe the wrong scope | Text always said all views, despite wide-model placement groups. Derive it from the same placement-group helper as drag actions. Also explain when the selected part has no visible sprite. | East/West guidance agrees with the placement editor; absent Breasts sprite gets an explicit explanation. |
| Camera mode can remain unavailable after editing is disabled | A preview already in parts mode did not return to camera mode when its edit permission changed. Extend the existing movement-mode effect to cover disabled editing. | Regression test covers the permission change and restored camera guidance. |

## Coverage

- Selected all six parts and verified matching headings, selected state, identical button dimensions, and no horizontal inspector overflow.
- Reviewed identity, presets and spawn assignment, standing/arousal controls, placement and pose/state overrides, sprite size, numeric entry and limits, colors, reset confirmations, camera toolbar and expanded settings, movement/placement modes, and saved-model preview.
- Reviewed the model picker: department and rotation controls share a 24px height and baseline; skin tiles share 112px height. Gallery rotation remains local, runs only while open, and clears its timer on close.
- Inspected the existing debounce/flush and preview memoization paths. This pass adds no server requests, render loops, or per-frame work beyond a small selected-part lookup for help text.
- Checked the 1200 by 940 target, 920 by 940 compact fixture, and smaller 740 by 650 fixture. The target layout fits without column scrolling; compact layouts retain contained vertical scrolling where their available height requires it, with no horizontal clipping. At the smallest fixture, Movement wraps onto a second toolbar row.

## Validation

- New behavior test first failed against the incorrect all-views guidance, then passed after the correction. It also checks north/south/side scope, missing-sprite guidance, and permission-driven camera fallback.
- Frontend suite: 61 passed, zero failed, 145 assertions.
- TypeScript and production TGUI build passed. Scoped Biome, SCSS formatting, and whitespace checks passed.
- Native code is unchanged in this pass; native compilation/tests were not rerun. Browser fixtures verify layout and UI behavior, not DreamSeeker rendering or actual saved-player data.

No commit, push, or live-server restart was performed. Load the rebuilt UI and reopen Setup Character for the next playtest, especially Parts, numeric columns, and reset confirmation alignment at the user's display scale.
