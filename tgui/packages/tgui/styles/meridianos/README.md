# MeridianOS visual system

MeridianOS is a scoped console family layered on top of tgui-core. It does not
restyle terminal, synth, paper, cat, spooky, syndicate, wizard, clockwork,
hackerman, retro-95, or other specialty themes.

## Architecture

The module owns its own subtrees: `assets/` holds every texture, font and
licence it inlines, `tests/` holds its contract and catalog tests, and
`debug/` holds the Kitchen Sink showcase and loader preview. Only
`styles/assets/bg-deforest.svg` stays outside, because upstream interfaces
use it.

1. `_palette.scss` contains named color maps, mirrored by the small theme
   definitions in [`constants/meridian-themes/`](../../constants/meridian-themes/).
   The palette contract test checks that both representations agree.
2. `_display-font.scss` exposes the licensed display face to both TGUI bundles.
3. `_tokens.scss` defines runtime semantic variables and maps them to the
   public tgui-core component variables.
4. `_themes.scss` emits every registered Sass palette automatically, then adds
   theme-specific construction profiles.
5. `_components.scss` applies shared component states using semantic variables
   only.
6. `_loader.scss` provides the fixed diagnostic-instrument layer set shared by
   the ordinary TGUI and lobby bundles. Theme variables reshape it without
   cloning component markup per theme. An optional aria-hidden light layer reuses
   the same geometry for local neon glow and stays hidden in forced colors.
7. `_decoration.scss` owns pointer-transparent shell, title-rail, and corner
   motifs.
8. `_motion.scss` owns the small interaction transitions, reduced-motion
   behavior, and forced-colors fallback.
9. `_aphelion-fonts.scss` shares the website fonts and grain with both bundles;
   `_aphelion.scss` adds the scoped Aphelion window and control treatment.
10. `_scavenger.scss` applies Scavenger's rust material and casing geometry while
    preserving opaque reading surfaces and caller-owned section colors.
11. `_forge-materials.scss` shares the Foundry and Hephaestus metal tiles and
    frame assets with the lobby. `_forge.scss` applies their window and control
    finishes; `_forge-loaders.scss` places the iris/turbine artwork on the
    existing loader layers while retaining shared motion and accessibility.
12. `_control-layout.scss` adapts existing upstream form markup through small,
    marked class hooks. `MeridianControlRow` wraps actions; its `__fill` item
    shrinks fields. `MeridianControlGrid` collapses sibling sections, while
    `MeridianControlForm` handles block fields followed by an inline action.
    Inline sizing overrides stay scoped to these adapters. Header action bounds
    apply to all player themes. Upstream handlers and component imports stay intact.
13. `_prompt.scss` and `hooks/usePromptSizing.ts` fit shared input dialogs and
    glassblowing to their rendered content before opening. The hook accounts for
    fonts, theme changes, native window timing, display scaling, and screen bounds.
    Long content remains scrollable; choice lists retain a bounded scroll area.
    Register other compact forms in the hook to reuse this behavior.

`Layout` resolves the window-local development override first, then an authored
specialty theme, the saved player base theme, an ordinary requested/device
theme, and finally Aphelion. It reconciles only the classes it owns, so
unrelated root modifiers and multi-class specialty themes survive updates. The
old base IDs are accepted as invisible compatibility aliases; new devices
request `meridian`.

## Skin catalog

The title-bar gear exposes one account-wide base-theme preference in this
order: **Aphelion**, **Classic**, **Electra**, Vector, Synapse, Highline,
Hephaestus, Diagnostic, Augmentation, Hotline, Cyberpunk, Scavenger,
Wastelander, Shadowbroker, and Foundry.
Aphelion is the default. Classic selects the original `theme-nanotrasen`
component styling without the MeridianOS console layer. Authored specialty
interfaces remain specialized while their gear still updates the saved base
theme used elsewhere.

Alongside Electra, the other thirteen palette-bearing MeridianOS skins are:

- Wastelander — muted phosphor, weathered olive casing, inset label plates,
  and CRT calibration rails. The stored `meridian_pipboy` ID is retained so
  existing player preferences continue selecting the renamed theme.
- Vector — paired notches, calibration ticks, and measurement rails.
- Foundry — hammered bronze housings, engraved borders, warm recessed controls,
  and a six-bladed mechanical iris loader.
- Diagnostic — square brackets, alignment ticks, and acquisition nodes.
- Highline — accessibility-first square boundaries and inverse selection.
- Synapse — aubergine glass, asymmetric cuts, reflective cyan controls, and
  cyan light confined to its original inset loader accents.
- Hotline (`meridian_synapse_xxxo`) — dark plum surfaces, reflective pink controls, neon glass
  trim, and red loader accents.
- Cyberpunk — red broken rails, black glass, reflective cyan controls, and
  illuminated cyan registration marks, progress ring and diamond core.
- Augmentation — machined black glass, reflective red controls, cyan
  instrumentation, and clean red fan segments matching the Augments workstation.
- Hephaestus (`meridian_afterlight`) — blue-grey gunmetal, aged bronze fittings, smoked green instrument
  glass, and a geared turbine loader.
- Shadowbroker (`meridian_relay`) — manufactured-spacecraft equipment bays, labels, and lamp blocks.
- Scavenger (`meridian_bastion`) — rusted olive casing, patched plates, recessed fasteners, and flush
  perimeter rails surrounding quiet cream-on-dark reading surfaces.
- Aphelion — warm brown instrument housings, cream labels, cyan controls, and
  restrained spectrum calibration rules drawn from the Meridian website.

The Change Lobby Title Screen manager also offers **Aphelion** as an independent
bezel choice. Its brown casing works with every interface theme; selecting a
player theme does not change the saved per-screen bezel.

Cyberpunk uses original, two-color nine-slice SVG chassis artwork for its outer
window and first-level panels. Its previous fixed-percentage title dashes are
removed: every remaining seam terminates into a corner, title plate, panel edge,
or status socket. The Vecteezy packs remain composition references because
their ordinary license does not grant AGPL-compatible source redistribution.

In a development build, open the Kitchen Sink with the title-bar bug button or
F12. Use **Inherit**, previous, next, or the skin dropdown. The selection applies
to the current window immediately, remains active after leaving the Kitchen
Sink, and is discarded when that TGUI window closes.

The **Loader** page previews the production Meridian-authored instrument at
48/64/96/144px, three scaling factors, determinate checkpoints, and a manual
reduced-motion freeze. `LOADER_STUDY.md` records why this geometry ships.

The Preferences character preview relies on the geometry-ready lifecycle in
`PREVIEW_INTEGRATION.md`. That document records the tiny-first-open root cause
and the BYOND 516 stress matrix still required on a runtime host.

## Adding a theme

Start by copying [`electra.ts`](../../constants/meridian-themes/electra.ts).
Each theme is a plain object in its own file; the shared
[`types.ts`](../../constants/meridian-themes/types.ts) checks its fields.
The filename and display name can be readable names. The `id` is the stable
value stored in player preferences and used in CSS, so keep existing IDs when
renaming themes.

1. Copy the definition to a new file, rename its export, and set a unique ID
   such as `meridian_example`, a display name, and its palette. `construction`
   is the short description beneath the name; leave it empty for no subtitle.
   Optional `preview` sets the menu swatch background for themes whose two
   accents do not describe them, as Aphelion's spectrum rule does.
2. Import the object into
   [`meridian-themes/index.ts`](../../constants/meridian-themes/index.ts) and
   put it directly in `MERIDIAN_BASE_THEME_OPTIONS` where it belongs in the
   menu. All frontend ID lists and types derive from this list.
3. Copy a named map in [`_palette.scss`](./_palette.scss), give it the same ID,
   and use the same ten colors. Append new maps to retain existing CSS order.
   Both TGUI and the lobby receive the new palette automatically.
4. Add the ID to `/datum/preference/choiced/meridian_theme/init_possible_values()`
   in [the backend preference](../../../../../modular_aphelion/modules/meridian_ui/code/preferences.dm).
   This allows the server to accept and save the selection.
5. Update the expected catalog in
   [`theme.test.ts`](./tests/theme.test.ts) and
   [the backend preference tests](../../../../../code/modules/unit_tests/~nova/meridian_preferences.dm).
   Keep menu order and the backend choice list aligned.

For example, registration is a direct list of imported objects:

```ts
export const MERIDIAN_BASE_THEME_OPTIONS = [
	aphelion,
	classic,
	electra,
	example,
	// Remaining themes...
] as const;
```

Classic intentionally has no `palette`: it selects upstream Nanotrasen styles.
The console-theme list filters for palette-bearing entries, so adding or moving
a normal theme needs no separate list edits. Changing
`DEFAULT_MERIDIAN_BASE_THEME` is independent of menu order; update the backend
`create_default_value()` too if changing that default.

The TypeScript and Sass palettes use six-digit hex colors and the same field names:

| Field             | Purpose                                         |
| ----------------- | ----------------------------------------------- |
| `canvas`          | Window background and text on selected controls |
| `panel`           | Main reading surface                            |
| `raised`          | Raised panels and overlays                      |
| `recessed`        | Inset surfaces                                  |
| `boundary`        | Visible control boundaries                      |
| `text`            | Primary text                                    |
| `mutedText`       | Secondary text                                  |
| `accent`          | Interactive accents                             |
| `secondaryAccent` | Selected controls                               |
| `focus`           | Keyboard focus indicator                        |

The palette is kept in both languages because Sass emits the styles while
TypeScript supplies picker swatches and contrast checks. There is no generation
step; [`palette.test.ts`](./tests/palette.test.ts) compiles the actual theme stylesheet
and verifies every named color against its TypeScript definition.

A palette-only theme inherits the common console layout and decoration.
For custom geometry, add a scoped `.theme-meridian_example` profile in
[`_themes.scss`](./_themes.scss) and override the semantic variables defined in
[`_tokens.scss`](./_tokens.scss). More extensive artwork or component finishes
can live in their own Sass partial, following the existing imports in
[`_index.scss`](./_index.scss). Shared lobby styles enter through
[`_shared.scss`](./_shared.scss); preserve the existing cascade order in both.

From `tgui/`, run:

```sh
bun test packages/tgui/styles/meridianos/tests
bun run tgui:tsc
bun run tgui:build
```

When adding a server choice, also run the backend preference tests. Preview the
theme in the Kitchen Sink and lobby, including keyboard focus and selection;
the palette contrast tests do not cover every custom material or decoration.
