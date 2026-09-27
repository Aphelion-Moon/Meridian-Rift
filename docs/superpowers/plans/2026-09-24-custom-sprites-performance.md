# Custom Sprites Performance Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. One Opus agent implements every task natively, as Pol asked. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut the custom sprite editors' server cost and update size without changing what players see or save.
- The preview render after each stroke pause costs 60-209 ms of server CPU today.
- Updates are 93-196 KB each, sent twice per stroke.

**Architecture:**
- **Server CPU:** rewrite the codec's string building with lists and a single join, and draw guides and previews only for the view the window shows.
- **Update size:** stop needless updates, move rarely-changing keys (guides, masks, region map) to static data sent only when they change, and send the canvas as a palette plus index strings.
- **Salon:** refreshes are grouped over one second, and held items are ignored.

**Tech Stack:** BYOND DM 516.1687 (tgstation/Nova/Aphelion), tgui (React + jotai, bun test, biome, rspack).

**Spec:** `docs/superpowers/specs/2026-09-24-custom-sprites-performance-design.md`. Read it first: section 1 has the measurements, section 2 Pol's decisions, sections 3-4 the new window contract.

**Worktree:** `C:\Users\Pol\Documents\Meridian-Rift\.worktrees\scenegirlsimulator` (branch `scenegirlsimulator`, BASE `29fd12cefa6d`). All paths below are relative to it.

**Ledger and tools:** `.superpowers/sdd/2026-09-24-custom-sprites-performance/` (git-ignored).
- `progress.md` is the ledger. Add one `Task N: complete (...)` line per task, plus `Ruling:` and `note:` lines, in the phase-2 style (see `../2026-09-24-whole-body-markings-phase2-tattoo/progress.md`).
- `dm-compile.sh <label> all` compiles `tgstation.test.dmb` with a TEST_FOCUS line for every custom_sprites test root, without starting DreamDaemon. It takes ~2 min.
- `dm-launch.sh <label>` runs that build once no BYOND process has been busy for a quiet minute, and judges the run by `clean_run.lk`. It takes ~2-3 min.
  - `ALONGSIDE=1 bash dm-launch.sh <label>` runs beside a server that's already up.
- `run-ok.sh` passes when the latest launch was clean.
- `final-checks.sh` runs DreamChecker (`-e tgstation.dme`), `tgui:build` and `run-ok.sh`.
- `dreamchecker.exe` is SpacemanDMM suite-1.11, matching CI.
- `bench/bench.sh <label>` compiles and runs the benchmark harness `bench/zz_custom_sprites_bench.dm` in a separate `tgstation.bench.dme`. Results land in `bench/<label>/`.
  - `python bench/compare.py bench/baseline/results.json bench/<label>/results.json` prints before/after medians.
  - `bench/baseline/` is the pre-change measurement.

## Global Constraints

- **No commits and no pushes.** This is Pol's standing rule. Leave every change in the working tree. `docs/` is untracked on purpose; leave it untracked.
- **Preserve what's there.** Don't touch unrelated working-tree changes, and don't reset or discard anything.
- **Before any DreamDaemon launch:**
  - Run `git status --porcelain | grep -i '\.dmi'`. A run rewrites `.dmi` files in the tree, so uncommitted sprite edits must be stashed first.
  - Never revert the regenerated `icons/map_icons/**` or `icons/obj/fluff/map_previews.dmi`.
  - Check `tasklist | grep -iE '^(dreamdaemon|dd|dm)\.exe'`. Never kill a DreamDaemon you didn't start: Pol runs play servers from other worktrees.
- **Don't change these:**
  - Saved drawings, sidecar and export formats.
  - SpriteEditor, paintings and NanoPaint behavior. Only `CustomSpriteEditor` decodes the new canvas.
  - The recipient's approval mirror images, which still render all four views.
- **DM style:**
  - Tests use `TEST_ASSERT`. They live in `code/modules/unit_tests/~nova/custom_sprites/` and release anything later tests depend on in `Destroy()`. No trivial asserts, and no tests for wording.
  - Use `for(var/key, value in list)` key/value loops. Use typed locals before calling procs on list-index results, because DreamChecker rejects the other form.
  - Inline comments are rare and one line. New procs get `/** */` or `///` doc blocks in the house style of `modular_nova/modules/customization/datums/dna/mutant_bodyparts.dm`: a verb-first first line, then `Arguments:` / `Returns:` only when they carry information.
  - No `APHELION EDIT` markers anywhere in this plan. Every DM file touched is Aphelion-owned (`modular_aphelion/**`, `code/modules/unit_tests/~nova/**`).
- **tgui:**
  - Every new file starts with `// THIS IS AN APHELION UI FILE`.
  - Keep each test file under 50 KB. bun 1.3.13 breaks bigger ones on cached runs, and `CustomSpriteEditor.test.tsx` is already 45 KB, so new tests go in new files.
  - Format changed files with `bunx biome check --write <files>` from the repo root. Never run the tree-wide `tgui:fix`.
- **Verification order:** DM tests are written first but not run red on their own, because one compile and run costs ~5 min. Run the suite at the checkpoints named in the tasks. tgui tests run red, then green.

## Review Focus

These are the conditions most likely to bite a player that no task's happy path exercises. Each is pinned by a test in the task named.

1. **A salon lock change while the window is open and idle** (the recipient pulls on gloves). The new paintable mask must still reach the window, because it is now static data. Task 6's `held_items` test asserts the lock and the `static_dirty` flag; Task 3's `static_data` test covers the full update itself.
2. **Switching views quickly** (Back, then Front, before the server answers). The window must converge on the view it shows. Task 5: the tgui test sends `setView` only when `visibleView` differs; the DM test checks that `setView` is idempotent.
3. **A whole-body canvas holding more than 64 distinct pixel values** (old saves and imports). The canvas must switch to two-character codes. Task 4's DM `canvas_wire` test and tgui `canvas.test.ts` cover it.
4. **Self-styling hand mirror** (pick it up, put it down). The Back view must lock and unlock at once, although held items no longer redraw guides. The existing `custom_sprite_salon/self_styling` and `self_tattoo` tests must still pass after Task 6.
5. **Reopening an editor closed while showing another view.** The server must draw the Front view the window reopens on, and the eyedropper must still sample a view that was never drawn. Task 5's `visible_view` test asserts the reset on close and sampling a stale view.

---

### Task 1: Codec rewrite

**Files:**
- Modify: `modular_aphelion/modules/custom_sprites/code/codec.dm`: `custom_sprite_encode_grid()`, `custom_sprite_decode_grid()`, `custom_style_recolor_drawing()`, plus new `custom_sprite_run_text()` and `custom_sprite_index_values()`
- Modify: `modular_aphelion/modules/custom_sprites/code/composite.dm`: `custom_sprite_drawing_pixels()`
- Modify: `modular_aphelion/modules/custom_sprites/code/regions.dm`: `custom_sprite_region_mask()`, and the row loop in `custom_sprite_region_map()`
- Modify: `modular_aphelion/modules/custom_sprites/code/images.dm`: the row loop in `custom_sprite_body_draw_mask()`
- Test: `code/modules/unit_tests/~nova/custom_sprites/codec.dm`, `code/modules/unit_tests/~nova/custom_sprites/regions.dm`

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `/proc/custom_sprite_run_text(pixel, run)` returns `pixel` repeated `run` (1-15) times.
  - `/proc/custom_sprite_index_values()` returns the alphabet character → palette index map (`"0"` → 0).
  - Every existing proc keeps its signature and returns byte-identical output. The A/B in `bench/baseline-codec-ab/` measured exactly this code.

- [ ] **Step 1: Write the characterization tests**

These pin today's output, so they pass before and after the rewrite. Append to `code/modules/unit_tests/~nova/custom_sprites/codec.dm`:

```dm
/// Dense art stores flat and sparse art stores runs; both must round-trip exactly at both canvas widths.
/datum/unit_test/custom_sprite_codec_round_trips/Run()
	for(var/width in list(32, CUSTOM_SPRITE_TAUR_WIDTH))
		var/pixel_count = width * 32
		var/list/dense = list()
		var/list/sparse = list()
		for(var/position in 0 to pixel_count - 1)
			var/x = position % width
			var/y = round(position / width)
			var/dense_index = (x + y) % 5 ? (round(x / 3) + y) % 40 + 1 : 0
			var/sparse_index = (y % 4 == 0 || x < width / 4 || x >= width * 3 / 4) ? 0 : (round(x / 7) + round(y / 3)) % 40 + 1
			dense += copytext(CUSTOM_SPRITE_INDEX_ALPHABET, dense_index + 1, dense_index + 2)
			sparse += copytext(CUSTOM_SPRITE_INDEX_ALPHABET, sparse_index + 1, sparse_index + 2)
		for(var/grid in list(jointext(dense, ""), jointext(sparse, "")))
			var/runs = 0
			for(var/i = 1; i <= pixel_count; i += min(15, spantext(grid, copytext(grid, i, i + 1), i)))
				runs++
			var/encoded = custom_sprite_encode_grid(grid, 40, pixel_count)
			TEST_ASSERT(copytext(encoded, 1, 2) == (1 + runs * 2 >= pixel_count + 1 ? "f" : "r"), "A grid must store flat exactly when its runs wouldn't be shorter.")
			TEST_ASSERT(custom_sprite_decode_grid(encoded, 40, pixel_count) == grid, "Encoding must round-trip at width [width].")
			TEST_ASSERT(custom_sprite_encode_grid(custom_sprite_decode_grid(encoded, 40, pixel_count), 40, pixel_count) == encoded, "Re-encoding a decoded grid must reproduce it byte for byte.")
```

Append to `code/modules/unit_tests/~nova/custom_sprites/regions.dm`:

```dm
/// A region map's paintable mask keeps every owned pixel except the locked regions', region 1 included.
/datum/unit_test/custom_sprite_region_mask_locks/Run()
	var/list/map = list("2" = list("0123456789", "9876543210"))
	TEST_ASSERT(json_encode(custom_sprite_region_mask(map)) == json_encode(list("2" = list("0111111111", "1111111110"))), "With nothing locked, every owned pixel must be paintable.")
	TEST_ASSERT(json_encode(custom_sprite_region_mask(map, list("1", "9"))) == json_encode(list("2" = list("0011111110", "0111111100"))), "Locked regions must leave the mask, region 1 included.")
```

- [ ] **Step 2: Rewrite encode and decode in `codec.dm`**

Replace the whole of `custom_sprite_encode_grid()` with:

```dm
/// Each run is a hex length (1-f), followed by one palette-index character.
/// Coordinates are row-major from the top left, matching SpriteEditor.
/proc/custom_sprite_encode_grid(grid, palette_size = 15, pixel_count = 1024)
	if(!custom_sprite_grid_args_valid(palette_size, pixel_count) || !istext(grid) || length(grid) != pixel_count)
		return null
	// Validate the entire grid before allowing an early flat fallback.
	if(spantext(grid, copytext(CUSTOM_SPRITE_INDEX_ALPHABET, 1, palette_size + 2)) != pixel_count)
		return null
	var/hex_digits = "0123456789abcdef"
	// Joined once at the end: growing one string run by run copies it every time.
	var/list/runs = list("r")
	var/encoded_length = 1
	for(var/i = 1; i <= pixel_count;)
		var/pixel = copytext(grid, i, i + 1)
		var/run = min(15, spantext(grid, pixel, i))
		runs += "[copytext(hex_digits, run + 1, run + 2)][pixel]"
		encoded_length += 2
		if(encoded_length >= pixel_count + 1)
			return "f[grid]"
		i += run
	return jointext(runs, "")
```

Replace the whole of `custom_sprite_decode_grid()` with this, and add `custom_sprite_run_text()` directly after it:

```dm
/// Reject before expanding, and stop at the supported pixel count even for hostile runs.
/proc/custom_sprite_decode_grid(encoded, palette_size = 15, pixel_count = 1024)
	if(!custom_sprite_grid_args_valid(palette_size, pixel_count) || !istext(encoded) || length(encoded) < 2 || length(encoded) > pixel_count + 1)
		return null
	var/hex_digits = "0123456789abcdef"
	var/format = copytext(encoded, 1, 2)
	var/grid = ""
	switch(format)
		if("f")
			if(length(encoded) != pixel_count + 1)
				return null
			grid = copytext(encoded, 2)
			if(spantext(grid, copytext(CUSTOM_SPRITE_INDEX_ALPHABET, 1, palette_size + 2)) != pixel_count)
				return null
		if("r")
			if((length(encoded) - 1) % 2)
				return null
			var/list/runs = list()
			var/decoded_length = 0
			var/encoded_length = length(encoded)
			for(var/i = 2; i < encoded_length; i += 2)
				var/run = findtextEx(hex_digits, copytext(encoded, i, i + 1)) - 1
				var/pixel = copytext(encoded, i + 1, i + 2)
				var/index = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, pixel) - 1
				if(run < 1 || index < 0 || index > palette_size || decoded_length + run > pixel_count)
					return null
				runs += custom_sprite_run_text(pixel, run)
				decoded_length += run
			grid = jointext(runs, "")
		else
			return null
	if(length(grid) != pixel_count)
		return null
	return grid

/// One index character repeated `run` times (1-15), cut from a string built once per character.
/proc/custom_sprite_run_text(pixel, run)
	var/static/list/repeated = list()
	var/full = repeated[pixel]
	if(!full)
		full = "[pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel]"
		repeated[pixel] = full
	return copytext(full, 1, run + 1)

/// CUSTOM_SPRITE_INDEX_ALPHABET character -> its palette index. "0" is transparent.
/proc/custom_sprite_index_values()
	var/static/list/values
	if(!values)
		values = list()
		for(var/position in 1 to length(CUSTOM_SPRITE_INDEX_ALPHABET))
			values[copytext(CUSTOM_SPRITE_INDEX_ALPHABET, position, position + 1)] = position - 1
	return values
```

In `custom_style_recolor_drawing()`, replace the per-direction body from `var/recolored = ""` through the `directions[direction] = ...` line with:

```dm
		var/list/recolored = list()
		for(var/position in 1 to pixel_count)
			// Alphabet position 1 is transparent, so palette index 1 lives at position 2.
			var/alphabet_position = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, copytext(grid, position, position + 1))
			if(alphabet_position <= 1)
				recolored += "0"
				continue
			var/mapped = index_map[alphabet_position - 1] + 1
			recolored += copytext(CUSTOM_SPRITE_INDEX_ALPHABET, mapped, mapped + 1)
		directions[direction] = custom_sprite_encode_grid(jointext(recolored, ""), length(new_palette), pixel_count)
```

- [ ] **Step 3: Use the index map in `composite.dm`**

In `custom_sprite_drawing_pixels()`, add `var/list/index_values = custom_sprite_index_values()` right before `for(var/direction in GLOB.custom_style_directions)`. Then replace

```dm
				var/index = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, copytext(grid, position, position + 1)) - 1
```

with

```dm
				var/index = index_values[copytext(grid, position, position + 1)]
```

- [ ] **Step 4: Region mask and row joins in `regions.dm` and `images.dm`**

Replace the whole of `custom_sprite_region_mask()` with:

```dm
/// The paintable mask of a region map: every pixel an unlocked region owns. `locked` holds region characters.
/proc/custom_sprite_region_mask(list/region_map, list/locked)
	var/static/regex/owned = regex(@"[1-9]", "g")
	var/regex/locked_regions = length(locked) ? regex("\[[jointext(locked, "")]\]", "g") : null
	. = list()
	for(var/direction, map_rows in region_map)
		var/list/rows = list()
		for(var/row in map_rows)
			rows += owned.Replace(locked_regions ? locked_regions.Replace(row, "0") : row, "1")
		.[direction] = rows
```

In `custom_sprite_region_map()`, replace the inner row loop (`var/row = ""` through `rows += row`) with:

```dm
			var/list/row = list()
			for(var/x in 0 to width - 1)
				var/pixel = composite.GetPixel(x + 1, 32 - y, "", direction)
				row += pixel ? (ids[LOWER_TEXT(copytext(pixel, 1, 8))] || custom_sprite_region_fallback(ordered, x, y, direction)) : "0"
			rows += jointext(row, "")
```

In `images.dm` `custom_sprite_body_draw_mask()`, replace the inner row loop (`var/row = ""` through `rows += row`) with:

```dm
			var/list/row = list()
			for(var/x in 0 to width - 1)
				row += silhouette.GetPixel(x + 1, 32 - y, "", direction) ? "1" : "0"
			rows += jointext(row, "")
```

- [ ] **Step 5: DreamChecker and the Task 1 checkpoint run**

Run: `cd <worktree> && .superpowers/sdd/2026-09-24-custom-sprites-performance/dreamchecker.exe -e tgstation.dme > .superpowers/sdd/2026-09-24-custom-sprites-performance/t1-dreamchecker.log 2>&1; tail -1 .superpowers/sdd/2026-09-24-custom-sprites-performance/t1-dreamchecker.log`
Expected: `Found 0 diagnostics`.

Run: `bash .superpowers/sdd/2026-09-24-custom-sprites-performance/dm-compile.sh t1 all && bash .superpowers/sdd/2026-09-24-custom-sprites-performance/dm-launch.sh t1`
Expected: `clean_run.lk: Success`, with `custom_sprite_codec_round_trips` and `custom_sprite_region_mask_locks` among the PASS lines. The last green count was 184.

- [ ] **Step 6: Ledger**

Append `Task 1: complete (commits 29fd12c..29fd12c, tests: bash .superpowers/sdd/2026-09-24-custom-sprites-performance/dm-launch.sh t1 → clean_run.lk: Success, <N> PASS)`.

---

### Task 2: No redundant updates

**Files:**
- Modify: `modular_aphelion/modules/custom_sprites/code/editor.dm`:
  - new var `can_restore_previous`
  - `context_ui_data()`
  - new `update_restorable()` and `bring_to_front()`
  - `ui_interact()`, the `selectColor` case of `ui_act()`, `refresh_preview()` and `save_drawing()`
- Modify: `modular_aphelion/modules/custom_sprites/code/markings_editor.dm`:
  - the `selectRegion` case of `editor_act()`
  - replace the `context_ui_data()` override with an `update_restorable()` override
  - `refresh_preview()`, `save_drawing()`
- Modify: `modular_aphelion/modules/custom_sprites/code/salon.dm`: `/datum/custom_sprite_editor/salon/update_restorable()` as a no-op
- Test: `code/modules/unit_tests/~nova/custom_sprites/editor.dm`, `code/modules/unit_tests/~nova/custom_sprites/markings_editor.dm`

**Interfaces:**
- Produces:
  - `/datum/custom_sprite_editor/var/can_restore_previous` (TRUE/FALSE)
  - `/datum/custom_sprite_editor/proc/update_restorable()`
  - `/datum/custom_sprite_editor/proc/bring_to_front(mob/user, datum/tgui/ui)`
- `ui_interact(mob/user, datum/tgui/ui)` treats a null `ui` as an explicit open. Task 3 extends this proc and keeps the rule.

- [ ] **Step 1: Write the tests**

Append to `code/modules/unit_tests/~nova/custom_sprites/editor.dm`:

```dm
/// Counts requests to bring the window forward.
/datum/custom_sprite_editor/optimization_test/focus_counting
	var/focus_requests = 0

/datum/custom_sprite_editor/optimization_test/focus_counting/bring_to_front(mob/user, datum/tgui/ui)
	focus_requests++

/datum/unit_test/custom_sprite_editor_refresh_focus/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/datum/custom_sprite_editor/optimization_test/focus_counting/editor = new(preferences, "hair")
	var/datum/tgui/ui = allocate(/datum/tgui, user, editor, "CustomHairEditor")
	LAZYADD(editor.open_uis, ui)
	editor.ui_interact(user, ui)
	TEST_ASSERT(!editor.focus_requests, "tgui's own refreshes must not pull the window in front of what the player is doing.")
	editor.ui_interact(user)
	TEST_ASSERT(editor.focus_requests == 1, "Opening an editor that's already open must bring its window forward.")
	LAZYREMOVE(editor.open_uis, ui)
	editor.finish(FALSE)

/// Picking a swatch the window already shows must not resend the whole canvas.
/datum/unit_test/custom_sprite_editor_quiet_selection/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/color = editor.workspace.palette[length(editor.workspace.palette)]
	TEST_ASSERT(!(editor.ui_act("selectColor", list("color" = "[color]ff"), ui, null) || editor.selected_color != color), "Selecting a palette color must take effect without a window update.")
	editor.finish(FALSE)
```

In `/datum/unit_test/custom_sprite_restore_offer/Run()` (editor.dm), the offer is now worked out by the debounced refresh. Insert `editor.refresh_preview(push = FALSE)` on its own line immediately before each of these four assertions:
- `"A style the draft already matches must not be offered."`
- `"A previous saved style must be offered."`
- `"Restoring the same style again must not be offered."`
- `"Undoing the restore must offer it again."`

In `code/modules/unit_tests/~nova/custom_sprites/markings_editor.dm`, replace

```dm
	TEST_ASSERT(!(!editor.ui_act("selectRegion", list("zone" = BODY_ZONE_L_LEG), ui, null) || editor.selected_zone != BODY_ZONE_L_LEG), "Selecting a present region must work.")
```

with

```dm
	TEST_ASSERT(!(editor.ui_act("selectRegion", list("zone" = BODY_ZONE_L_LEG), ui, null) || editor.selected_zone != BODY_ZONE_L_LEG), "Selecting a present region must work without resending the window, which already shows it.")
```

and replace

```dm
	TEST_ASSERT(!editor.ui_act("selectRegion", list("zone" = BODY_ZONE_L_ARM), ui, null), "A locked region can't be selected.")
```

with

```dm
	editor.ui_act("selectRegion", list("zone" = BODY_ZONE_L_ARM), ui, null)
	TEST_ASSERT(editor.selected_zone != BODY_ZONE_L_ARM, "A locked region can't be selected.")
```

- [ ] **Step 2: Implement in `editor.dm`**

Add to the `/datum/custom_sprite_editor` var block, after `var/hide_underwear = FALSE`:

```dm
	/// Whether a previous saved style differs from the draft, as of the last preview refresh or save.
	var/can_restore_previous = FALSE
```

Replace `context_ui_data()` and add `update_restorable()` next to it:

```dm
/// Context hook: extra window data owned by the context.
/datum/custom_sprite_editor/proc/context_ui_data()
	return list("canRestorePrevious" = can_restore_previous)

/// Works out whether Restore previous saved style is offered. Runs with the debounced preview and after saves, not on every window update.
/datum/custom_sprite_editor/proc/update_restorable()
	can_restore_previous = !!restorable_package()
```

Add `bring_to_front()`, and replace the first part of `ui_interact()` down to its first `return`:

```dm
/// Brings the open window in front of the player's other windows.
/datum/custom_sprite_editor/proc/bring_to_front(mob/user, datum/tgui/ui)
	if(ui.window)
		winset(user, ui.window.id, "focus=true")

/datum/custom_sprite_editor/ui_interact(mob/user, datum/tgui/ui)
	if(!can_edit(user))
		return
	// tgui's own refreshes pass their window; only an explicit open brings it forward.
	var/opening = isnull(ui)
	if(!resources_ready && rebuild_resources())
		refresh_preview(push = FALSE)
	ui = SStgui.try_update_ui(user, src, ui)
	if(ui)
		if(opening)
			bring_to_front(user, ui)
		return
```

The rest of `ui_interact()`, which picks the interface and opens a new window, stays as it is.

In `ui_act()`, the `selectColor` case ends with `return FALSE` instead of `return TRUE`:

```dm
		if("selectColor")
			if(!workspace.is_valid_color(params["color"]))
				return FALSE
			selected_color = LOWER_TEXT(copytext(params["color"], 1, 8))
			selected_custom_color = null
			// The window picked this swatch itself; echoing it back would resend the whole canvas.
			return FALSE
```

In `refresh_preview()`, call `update_restorable()` right after `draft = workspace.serialize_drawing()` and before the `preview_hash` comparison. Previous styles can change without the drawing changing.

In `save_drawing()`, call `update_restorable()` right after `workspace.mark_saved()`.

- [ ] **Step 3: Implement in `markings_editor.dm`**

In `editor_act()`, the `selectRegion` case becomes:

```dm
		if("selectRegion")
			selected_zone = zone
			// The window already shows its own selection.
			return FALSE
```

Replace the `context_ui_data()` override (`return list("canRestorePrevious" = length(restorable_regions()) > 0)`) with:

```dm
/datum/custom_sprite_editor/markings/update_restorable()
	can_restore_previous = length(restorable_regions()) > 0
```

In the markings `refresh_preview()`, call `update_restorable()` right after `var/list/results = region_results()`.

In the markings `save_drawing()`, call `update_restorable()` right after `mark_saved()`.

- [ ] **Step 4: Salon hair editor never offers restoration from the window**

In `salon.dm`, next to `/datum/custom_sprite_editor/salon/context_ui_data()`, add:

```dm
/// The salon restores through the tool, with the recipient's consent, never from the window.
/datum/custom_sprite_editor/salon/update_restorable()
	return
```

This is required, not cosmetic. The base version reads `preferences`, which is the artist's and can be null in tests.

- [ ] **Step 5: DreamChecker**

Run DreamChecker as in Task 1 Step 5, into `t2-dreamchecker.log`. Expected: `Found 0 diagnostics`. The DM run for Tasks 2 and 3 happens at the end of Task 3.

- [ ] **Step 6: Ledger**

Append `Task 2: note: code done; verified with Task 3's run.` When the Task 3 run is green, append `Task 2: complete (...)` with that run.

---

### Task 3: Static data

**Files:**
- Modify: `modular_aphelion/modules/custom_sprites/code/editor.dm`: new var `static_dirty`, `ui_static_data()`, `ui_data()`, `ui_interact()`, `rebuild_resources()`
- Modify: `modular_aphelion/modules/custom_sprites/code/markings_editor.dm`: `ui_static_data()`, `ui_data()`, `apply_region_locks()`
- Test: `code/modules/unit_tests/~nova/custom_sprites/markings_editor.dm`, `code/modules/unit_tests/~nova/custom_sprites/editor.dm`

**Interfaces:**
- Consumes: `bring_to_front()` and the `opening` rule from Task 2.
- Produces: `/datum/custom_sprite_editor/var/static_dirty`. Anything that changes guides, the draw mask or the region map sets it TRUE. Task 5's `render_guide()` sets it too.
- The window contract is unchanged: `useBackend` merges static data and data, so tgui needs no change.

- [ ] **Step 1: Write the tests**

Append to `code/modules/unit_tests/~nova/custom_sprites/markings_editor.dm`:

```dm
/// Counts full updates: only they carry static data.
/datum/tgui/full_update_counting
	var/full_updates = 0

/datum/tgui/full_update_counting/send_full_update(custom_data, force, always_instant)
	full_updates++

/datum/unit_test/custom_sprite_markings_static_data/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_CHEST)
	var/list/data = editor.ui_data(user)
	var/list/static_data = editor.ui_static_data(user)
	for(var/key in list("guides", "drawMask", "regions", "regionZones", "emissive"))
		TEST_ASSERT(!(key in data) && (key in static_data), "[key] must travel as static data, not with every update.")
	var/datum/tgui/full_update_counting/ui = allocate(/datum/tgui/full_update_counting, user, editor, "CustomMarkingsEditor")
	editor.static_dirty = FALSE
	editor.ui_interact(user, ui)
	TEST_ASSERT(!ui.full_updates, "An ordinary refresh must not resend static data.")
	editor.rebuild_resources(reuse_body = TRUE)
	editor.ui_interact(user, ui)
	TEST_ASSERT(!(ui.full_updates != 1 || editor.static_dirty), "Rebuilt guides and masks must reach the open window as one full update.")
	editor.finish(FALSE)
```

In `code/modules/unit_tests/~nova/custom_sprites/editor.dm` (`/datum/unit_test/custom_marking_zone_editor/Run()`), replace `length(data["drawMask"]) != 4` with `length(editor.ui_static_data(mock_client.mob)["drawMask"]) != 4`.

- [ ] **Step 2: Implement in `editor.dm`**

Add to the var block, after `can_restore_previous`:

```dm
	/// Guides, the draw mask or the region map changed since the window last received static data.
	var/static_dirty = FALSE
```

In `rebuild_resources()`, add `static_dirty = TRUE` directly after the `resources_markings = ...` line, so both the success path and the no-body path mark it.

`ui_static_data()` gains two keys at the end:

```dm
	.["guides"] = guide_urls
	.["drawMask"] = workspace.draw_mask
```

In `ui_data()`, the start becomes:

```dm
/datum/custom_sprite_editor/ui_data(mob/user)
	sync_locked_views(push = FALSE)
	// A lock change found here moved the mask, which only a full update carries.
	if(static_dirty && LAZYLEN(open_uis))
		SStgui.update_uis(src)
```

Also remove `"guides" = guide_urls, ` and `"drawMask" = workspace.draw_mask, ` from its big `list(...)` literal. Everything else in `ui_data()` stays.

Replace the part of `ui_interact()` from the Task 2 version (the lines up to the first `return`) with:

```dm
/datum/custom_sprite_editor/ui_interact(mob/user, datum/tgui/ui)
	if(!can_edit(user))
		return
	// tgui's own refreshes pass their window; only an explicit open brings it forward.
	var/opening = isnull(ui)
	if(!resources_ready && rebuild_resources())
		refresh_preview(push = FALSE)
	if(static_dirty)
		ui ||= SStgui.get_open_ui(user, src)
		if(ui)
			// Guides, masks and the region map are static data, which an ordinary refresh leaves out.
			static_dirty = FALSE
			ui.process_status()
			if(ui.status <= UI_CLOSE)
				ui.close()
				return
			ui.send_full_update(always_instant = TRUE)
			if(opening)
				bring_to_front(user, ui)
			return
	ui = SStgui.try_update_ui(user, src, ui)
	if(ui)
		if(opening)
			bring_to_front(user, ui)
		return
```

Also, in the part that opens a new window, add `static_dirty = FALSE` on the line before `ui.open()`: the first payload carries static data anyway.

- [ ] **Step 3: Implement in `markings_editor.dm`**

`ui_static_data()` gains, at the end:

```dm
	.["regions"] = region_map
	.["regionZones"] = region_zones
	.["emissive"] = custom_sprite_emissive_settings(FALSE)
```

In `ui_data()`, delete the lines setting `.["emissive"]`, `.["regions"]` and `.["regionZones"]`, and put this right after `. = ..()`:

```dm
	// Region emission lives in regionEmissive; the all-off view flags are static data.
	. -= "emissive"
```

In `apply_region_locks()`, add `static_dirty = TRUE` directly after `canvas.draw_mask = custom_sprite_region_mask(region_map, locked)`.

- [ ] **Step 4: DreamChecker and the Tasks 2-3 checkpoint run**

Run DreamChecker into `t3-dreamchecker.log`. Expected: 0 diagnostics.

Run: `bash .superpowers/sdd/2026-09-24-custom-sprites-performance/dm-compile.sh t3 all && bash .superpowers/sdd/2026-09-24-custom-sprites-performance/dm-launch.sh t3`
Expected: `clean_run.lk: Success`, with the Task 2 and Task 3 tests passing by name (`refresh_focus`, `quiet_selection`, `restore_offer`, `markings_static_data`).

- [ ] **Step 5: Ledger**

Append `Task 2: complete (...)` and `Task 3: complete (...)`, both citing run t3.

---

### Task 4: Compact pixel format

**Files:**
- Modify: `modular_aphelion/modules/custom_sprites/code/workspace.dm`:
  - new vars `canvas_codes`, `canvas_palette`, `canvas_views`, `canvas_digits`
  - new procs `pixels_changed()` and `canvas_ui_data()`
  - a `sprite_editor_ui_data()` override
  - swap every `pixels_dirty = TRUE` for `pixels_changed(...)`
- Modify: `modular_aphelion/modules/custom_sprites/code/codec.dm`: new `custom_sprite_canvas_code()`
- Create: `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/canvas.ts`
- Modify: `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/types.ts`, `index.tsx`
- Modify: `tgui/packages/tgui/__mocks__/customSpriteEditor.ts`, `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/CustomSpriteEditor.test.tsx`
- Create: `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/canvas.test.ts`
- Test (DM): `code/modules/unit_tests/~nova/custom_sprites/workspace.dm`

**Interfaces:**
- Produces:
  - `/datum/sprite_editor_workspace/custom_sprite/proc/canvas_ui_data()` → `list("palette", "digits", "views")` (spec section 3).
  - `/datum/sprite_editor_workspace/custom_sprite/proc/pixels_changed(direction)`.
  - `/proc/custom_sprite_canvas_code(index, digits)`.
  - tgui: `decodeCanvas(sprite: CompactSprite): SpriteData`, and the types `CompactCanvas`, `CompactSprite`, `CANVAS_ALPHABET` from `canvas.ts`.
  - Mock: `fixtureFrames(width?, height?)` and `compactSprite(width, height, frames)`.

- [ ] **Step 1: DM test (written first, run at the Task 5 checkpoint)**

Append to `code/modules/unit_tests/~nova/custom_sprites/workspace.dm`:

```dm
/// Reads one pixel back out of the window's compact canvas.
/proc/custom_sprite_test_canvas_pixel(list/canvas, direction, x, y, width)
	var/digits = canvas["digits"]
	var/list/views = canvas["views"]
	var/list/palette = canvas["palette"]
	var/codes = views[direction]
	var/offset = (y * width + x) * digits
	var/index = 0
	for(var/digit in 1 to digits)
		index = index * 64 + findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, copytext(codes, offset + digit, offset + digit + 1)) - 1
	return palette[index + 1]

/datum/unit_test/custom_sprite_canvas_wire/Run()
	var/datum/sprite_editor_workspace/custom_sprite/workspace = new(null, list("#123456"), null, null, 32)
	TEST_ASSERT(workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#123456ff", "points" = list(list(0, 0)))), "The fixture must paint one pixel.")
	var/list/editor_data = workspace.sprite_editor_ui_data()
	var/list/sprite = editor_data["sprite"]
	TEST_ASSERT(!("layers" in sprite), "The window must not receive a color string per pixel.")
	var/list/canvas = sprite["canvas"]
	var/list/views = canvas["views"]
	TEST_ASSERT(!(json_encode(canvas["palette"]) != json_encode(list("#123456ff", "#00000000")) || canvas["digits"] != 1), "The palette must list each pixel value once, in first-use order: [json_encode(canvas["palette"])]")
	TEST_ASSERT(!(views["2"] != "0[repeat_string(1023, "1")]" || views["1"] != repeat_string(1024, "1")), "Each view must be one code per pixel, row by row from the top left.")
	TEST_ASSERT(workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#123456ff", "points" = list(list(1, 0)))), "The fixture must paint a second pixel.")
	canvas = workspace.canvas_ui_data()
	views = canvas["views"]
	TEST_ASSERT(!(views["2"] != "00[repeat_string(1022, "1")]" || views["1"] != repeat_string(1024, "1")), "A stroke must update its own view and leave the others' codes alone.")
	workspace.undo()
	TEST_ASSERT(custom_sprite_test_canvas_pixel(workspace.canvas_ui_data(), "2", 1, 0, 32) == "#00000000", "Undo must reach the window's canvas.")
	qdel(workspace)
	var/datum/sprite_editor_workspace/custom_sprite/regions/crowded = new(null, list(), null, null, 32)
	var/list/frames = list()
	for(var/direction in GLOB.custom_style_directions)
		var/list/frame = list()
		for(var/y in 0 to 31)
			var/list/row = list()
			for(var/x in 0 to 31)
				row += y < 3 ? "[rgb(y * 32 + x, 0, 0)]ff" : "#00000000"
			frame += list(row)
		frames[direction] = frame
	crowded.load_frames(frames)
	canvas = crowded.canvas_ui_data()
	TEST_ASSERT(canvas["digits"] == 2, "More than 64 pixel values must use two characters per pixel.")
	TEST_ASSERT(custom_sprite_test_canvas_pixel(canvas, "4", 5, 1, 32) == "[rgb(37, 0, 0)]ff", "Two-character codes must name the right palette entry.")
	qdel(crowded)
```

- [ ] **Step 2: DM implementation**

In `codec.dm`, after `custom_sprite_index_values()`:

```dm
/// A palette index as `digits` characters of CUSTOM_SPRITE_INDEX_ALPHABET, most significant first.
/proc/custom_sprite_canvas_code(index, digits)
	. = ""
	for(var/i in 1 to digits)
		var/digit = index % 64
		. = "[copytext(CUSTOM_SPRITE_INDEX_ALPHABET, digit + 1, digit + 2)][.]"
		index = round(index / 64)
```

In `modular_aphelion/modules/custom_sprites/code/workspace.dm`, add to the `/datum/sprite_editor_workspace/custom_sprite` var block, after `var/list/trimmed_rotations = list()`:

```dm
	/// Pixel value -> its code in the window's canvas.
	var/list/canvas_codes
	/// Every pixel value the window's canvas uses, in first-use order. Null until built.
	var/list/canvas_palette
	/// Direction -> that view as codes. A null entry is rebuilt on the next update.
	var/list/canvas_views
	/// Characters per pixel in canvas_views.
	var/canvas_digits = 1
```

Add these procs after `update_edited_direction()`:

```dm
/// Pixels changed: serialization rebuilds, and so does the window's canvas, only that view when one is named.
/datum/sprite_editor_workspace/custom_sprite/proc/pixels_changed(direction)
	pixels_dirty = TRUE
	if(direction && canvas_views)
		canvas_views[direction] = null
	else
		canvas_palette = null

/**
 * The canvas as the window receives it: every pixel value once, and each view as codes.
 *
 * A code is `canvas_digits` characters of CUSTOM_SPRITE_INDEX_ALPHABET naming a palette entry, most
 * significant first, row by row from the top left. The palette only grows until the next full
 * rebuild, so views that didn't change keep their codes and aren't encoded again.
 *
 * Returns list("palette" = pixel values, "digits" = characters per pixel, "views" = direction -> codes).
 */
/datum/sprite_editor_workspace/custom_sprite/proc/canvas_ui_data()
	var/list/frames = layers[1]["data"]
	var/list/stale = list()
	for(var/direction in frames)
		if(isnull(canvas_palette) || isnull(canvas_views[direction]))
			stale += direction
	if(length(stale))
		var/list/values = canvas_palette ? canvas_palette.Copy() : list()
		for(var/direction in stale)
			for(var/list/row as anything in frames[direction])
				values |= row
		var/digits = length(values) <= 64 ? 1 : (length(values) <= 4096 ? 2 : 3)
		if(isnull(canvas_palette) || digits != canvas_digits)
			// Wider codes change every view.
			canvas_digits = digits
			canvas_codes = list()
			canvas_views = list()
			stale = assoc_to_keys(frames)
		canvas_palette = values
		for(var/index in length(canvas_codes) + 1 to length(canvas_palette))
			canvas_codes[canvas_palette[index]] = custom_sprite_canvas_code(index - 1, canvas_digits)
		for(var/direction in stale)
			var/list/codes = list()
			for(var/list/row as anything in frames[direction])
				for(var/pixel in row)
					codes += canvas_codes[pixel]
			canvas_views[direction] = jointext(codes, "")
	return list("palette" = canvas_palette, "digits" = canvas_digits, "views" = canvas_views)

/// The window gets the canvas as palette indexes rather than a color string per pixel.
/datum/sprite_editor_workspace/custom_sprite/sprite_editor_ui_data()
	. = ..()
	var/list/sprite = .["sprite"]
	sprite -= "layers"
	sprite["canvas"] = canvas_ui_data()
```

Replace each `pixels_dirty = TRUE` in that file:
- `clip_to_allowed()`: `if(changed)` → `pixels_changed()`
- `transact()`: `pixels_changed(transaction["dir"])`, keeping `update_edited_direction(transaction["dir"])` after it
- `reverse_transact()`: `pixels_changed(transaction["dir"])`
- `bake_tint()`: `pixels_changed()`
- `apply_replacement()`: `pixels_changed()`
- regions `load_frames()`: `pixels_changed()`

`serialize_drawing()` keeps reading and clearing `pixels_dirty` as today.

- [ ] **Step 3: tgui: write the failing tests**

Create `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/canvas.test.ts`:

```ts
// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import {
  compactSprite,
  fixtureFrames,
} from '../../../__mocks__/customSpriteEditor';
import { Dir } from '../SpriteEditor/Types/types';
import { decodeCanvas } from './canvas';

it('decodes the canvas the server sends for one painted pixel', () => {
  const sprite = decodeCanvas({
    width: 32,
    height: 32,
    dirs: 4,
    backdrop: '',
    canvas: {
      palette: ['#123456ff', '#00000000'],
      digits: 1,
      views: { 2: `0${'1'.repeat(1023)}`, 1: '1'.repeat(1024) },
    },
  });
  const front = sprite.layers[0].data[Dir.SOUTH]!;
  expect(front[0][0]).toBe('#123456ff');
  expect(front[0][1]).toBe('#00000000');
  expect(front[31][31]).toBe('#00000000');
  expect(sprite.layers[0].data[Dir.NORTH]![0][0]).toBe('#00000000');
  expect(sprite.layers[0].data[Dir.EAST]).toBeUndefined();
});

it('round-trips every view, including two-character codes past 64 values', () => {
  const frames = fixtureFrames(64, 32);
  for (let y = 0; y < 3; y++) {
    for (let x = 0; x < 32; x++) {
      frames[Dir.WEST][y][x] =
        `#${(y * 32 + x).toString(16).padStart(6, '0')}ff`;
    }
  }
  const sprite = compactSprite(64, 32, frames);
  expect(sprite.canvas.digits).toBe(2);
  const decoded = decodeCanvas(sprite);
  expect(decoded.width).toBe(64);
  for (const dir of [Dir.SOUTH, Dir.NORTH, Dir.EAST, Dir.WEST]) {
    expect(decoded.layers[0].data[dir]).toEqual(frames[dir]);
  }
});
```

Run: `cd tgui && bun test packages/tgui/interfaces/common/CustomSpriteEditor/canvas.test.ts`
Expected: FAIL. `./canvas` doesn't exist yet, and neither do the mock's `compactSprite`/`fixtureFrames` exports.

- [ ] **Step 4: tgui: implement**

Create `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/canvas.ts`:

```ts
// THIS IS AN APHELION UI FILE
import type {
  SpriteData,
  SpriteDataLayer,
  StringLayer,
} from '../SpriteEditor/Types/types';

/** The server's CUSTOM_SPRITE_INDEX_ALPHABET: one base-64 digit per character. */
export const CANVAS_ALPHABET =
  '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_';

const DIGIT_VALUES = new Map(
  [...CANVAS_ALPHABET].map((character, value) => [character, value]),
);

/** The canvas as the server sends it: every pixel value once, and each view as index codes. */
export type CompactCanvas = {
  palette: string[];
  digits: number;
  views: Record<string, string>;
};

export type CompactSprite = Omit<SpriteData, 'layers'> & {
  canvas: CompactCanvas;
};

/** Expands the server's compact canvas into the per-pixel layer SpriteEditor draws. */
export const decodeCanvas = (sprite: CompactSprite): SpriteData => {
  const { canvas, ...rest } = sprite;
  const { palette, digits, views } = canvas;
  const data: Record<string, StringLayer> = {};
  for (const [dir, codes] of Object.entries(views)) {
    const frame: StringLayer = [];
    let offset = 0;
    for (let y = 0; y < sprite.height; y++) {
      const row: string[] = new Array(sprite.width);
      for (let x = 0; x < sprite.width; x++) {
        let index = 0;
        for (let digit = 0; digit < digits; digit++) {
          index = index * 64 + (DIGIT_VALUES.get(codes[offset++]) ?? 0);
        }
        row[x] = palette[index];
      }
      frame.push(row);
    }
    data[dir] = frame;
  }
  const layer = {
    name: 'Drawing',
    visible: true,
    data,
  } as unknown as SpriteDataLayer;
  return { ...rest, layers: [layer] };
};
```

In `types.ts`:
- Import `type { CompactSprite } from './canvas'`.
- Change `sprite: SpriteData;` to `sprite: CompactSprite;`.
- Drop `SpriteData` from the `../SpriteEditor/Types/types` import if nothing else uses it.

In `index.tsx`:
- Import `useMemo` alongside `useEffect, useRef, useState`, and add `import { decodeCanvas } from './canvas';`.
- Directly after the `} = data;` destructuring line, add:

```tsx
  const sprite = useMemo(
    () => decodeCanvas(editorData.sprite),
    [editorData.sprite],
  );
```

- Then make these replacements:
  - `const wide = editorData.sprite.width > 32;` becomes `const wide = sprite.width > 32;`
  - `const { width, height } = editorData.sprite;` becomes `const { width, height } = sprite;`
  - `data={editorData.sprite}` becomes `data={sprite}`
  - `imageWidth={editorData.sprite.width}` becomes `imageWidth={sprite.width}`

In `tgui/packages/tgui/__mocks__/customSpriteEditor.ts`:
- Add `import { CANVAS_ALPHABET, type CompactSprite } from '../interfaces/common/CustomSpriteEditor/canvas';`.
- Add these two exports above `fixture`:

```ts
/** Four views of `width` by `height` white pixels, as SpriteEditor holds them, for tests that set pixels. */
export const fixtureFrames = (width = 32, height = 32) => {
  const frame = () =>
    Array.from({ length: height }, () => Array(width).fill('#ffffffff'));
  return {
    [Dir.SOUTH]: frame(),
    [Dir.NORTH]: frame(),
    [Dir.EAST]: frame(),
    [Dir.WEST]: frame(),
  };
};

/** Encodes frames the way the server does: every pixel value once, and each view as index codes. */
export const compactSprite = (
  width: number,
  height: number,
  frames: Partial<Record<Dir, string[][]>>,
): CompactSprite => {
  const palette: string[] = [];
  const indexes = new Map<string, number>();
  for (const frame of Object.values(frames)) {
    for (const row of frame ?? []) {
      for (const pixel of row) {
        if (!indexes.has(pixel)) {
          indexes.set(pixel, palette.length);
          palette.push(pixel);
        }
      }
    }
  }
  const digits = palette.length <= 64 ? 1 : palette.length <= 4096 ? 2 : 3;
  const code = (index: number) => {
    let text = '';
    for (let digit = 0; digit < digits; digit++) {
      text = CANVAS_ALPHABET[index % 64] + text;
      index = Math.floor(index / 64);
    }
    return text;
  };
  const views: Record<string, string> = {};
  for (const [dir, frame] of Object.entries(frames)) {
    views[dir] = (frame ?? [])
      .map((row) => row.map((pixel) => code(indexes.get(pixel)!)).join(''))
      .join('');
  }
  return {
    width,
    height,
    dirs: 4,
    backdrop: '',
    canvas: { palette, digits, views },
  };
};
```

- In `fixture()`, replace the whole `sprite: { ... layers: [...] }` object with `sprite: compactSprite(width, height, fixtureFrames(width, height)),` and delete its local `frame` helper.

In `CustomSpriteEditor.test.tsx`:
- Add `compactSprite` and `fixtureFrames` to the existing `'../../../__mocks__/customSpriteEditor'` import.
- Replace

```ts
  const data = { ...fixture(), context: 'salon' };
  data.editorData.sprite.layers[0].data[Dir.SOUTH]![0][0] = '#12abefff';
  data.editorData.sprite.layers[0].data[Dir.SOUTH]![0][1] = '#00000000';
```

with

```ts
  const frames = fixtureFrames();
  frames[Dir.SOUTH][0][0] = '#12abefff';
  frames[Dir.SOUTH][0][1] = '#00000000';
  const data = { ...fixture(), context: 'salon' };
  data.editorData.sprite = compactSprite(32, 32, frames);
```

- Replace `fixture().editorData.sprite.layers[0].data[Dir.SOUTH],` with `fixtureFrames()[Dir.SOUTH],`.

- [ ] **Step 5: tgui: verify**

Run: `cd tgui && bun test packages/tgui/interfaces/common/CustomSpriteEditor packages/tgui/interfaces/CustomSpriteMirror.test.tsx packages/tgui/interfaces/common/SpriteEditor`
Expected: all pass, including `canvas.test.ts`.

Run: `cd tgui && bun run tgui:tsc`
Expected: exit 0.

Run from the repo root: `bunx biome check --write <each changed or new tgui file>`, then `bun run tgui:lint`.
Expected: clean.

Check the size of `CustomSpriteEditor.test.tsx`; it must stay under 50 KB.

- [ ] **Step 6: DreamChecker; ledger note**

Run DreamChecker into `t4-dreamchecker.log`. Expected: 0 diagnostics.

Append `Task 4: note: tgui focused <N>/<N>, tsc 0, lint clean; DM verified with Task 5's run.`

---

### Task 5: Visible view only

**Files:**
- Modify: `modular_aphelion/modules/custom_sprites/code/editor.dm`:
  - new vars `visible_direction`, `guide_appearance`, `guide_shift`, `stale_guides`, `preview_appearance`, `preview_width`, `stale_previews`
  - `rebuild_resources()`, `release_resources()`
  - new `capture_guide()`, `render_guide()`, `render_preview()`, `render_view()`, `capture_preview()`, `adopt_preview()`
  - `render_previews()`, `refresh_preview()`, `sample_guide()`
  - the `setView` case in `ui_act()`, `visibleView` in `ui_data()`, `ui_close()`
- Modify: `modular_aphelion/modules/custom_sprites/code/markings_editor.dm`: `refresh_preview()`, new `capture_region_previews()`, `render_region_previews()`
- Modify: `modular_aphelion/modules/custom_sprites/code/mirror.dm`: new `custom_sprite_preview_appearance()`, `custom_sprite_preview_width()`, `custom_sprite_render_view()`, `custom_sprite_render_views()`; `custom_sprite_render_directions()` rebuilt on them
- Modify: `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/index.tsx`, `types.ts`
- Create: `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/CustomSpriteEditor.views.test.tsx`
- Test (DM): `editor.dm` (a new test plus updates) and `salon.dm` (updates), both in `code/modules/unit_tests/~nova/custom_sprites/`

**Interfaces:**
- Consumes: `static_dirty` (Task 3), `update_restorable()` (Task 2).
- Produces:
  - `render_view(direction)`, where direction is `"2"`, `"1"`, `"4"` or `"8"`. It returns TRUE when it drew anything. Tests use it to draw views they inspect.
  - The action `setView` (`dir`) and the data key `visibleView`, as in spec section 4.
  - `custom_sprite_render_directions(body, publish, worn_overlays)` keeps its signature and output. The mirror and candidate previews use it.

- [ ] **Step 1: DM tests**

Append to `code/modules/unit_tests/~nova/custom_sprites/editor.dm`:

```dm
/// Only the view the window shows is drawn; the others are drawn once shown.
/datum/unit_test/custom_sprite_editor_visible_view/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	TEST_ASSERT(!(length(editor.guide_urls) != 1 || !editor.guide_urls["2"] || length(editor.preview_urls) != 1 || !editor.preview_urls["2"]), "Opening must draw only the Front view's guide and preview.")
	TEST_ASSERT(editor.ui_data(mock_client.mob)["visibleView"] == "2", "The window must learn which view the server drew.")
	TEST_ASSERT(editor.ui_act("setView", list("dir" = "1"), ui, null), "Showing the Back view must draw it and update the window.")
	TEST_ASSERT(!(!editor.guide_urls["1"] || !editor.preview_urls["1"] || editor.visible_direction != "1"), "The shown view must get its guide and preview.")
	TEST_ASSERT(!editor.ui_act("setView", list("dir" = "1"), ui, null), "Showing the view already shown must not resend the window.")
	TEST_ASSERT(!editor.ui_act("setView", list("dir" = "3"), ui, null), "Unknown views must be refused.")
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "1", "color" = "[editor.workspace.palette[1]]ff", "points" = list(custom_sprite_test_paintable_point(editor, "1")))), "The fixture must paint the Back view.")
	editor.refresh_preview(push = FALSE)
	TEST_ASSERT(!(editor.stale_previews["1"] || !editor.stale_previews["2"]), "A refresh must draw only the shown view and leave the others' last image until shown.")
	TEST_ASSERT(editor.stale_guides["4"], "The fixture needs a view whose guide was never drawn.")
	editor.sample_guide("4", 0, 0)
	TEST_ASSERT(!editor.stale_guides["4"], "Sampling a view must draw its guide first.")
	editor.ui_close(mock_client.mob)
	TEST_ASSERT(editor.visible_direction == "2", "Closing must return to the Front view the window reopens on.")
	editor.finish(FALSE)
```

Update the existing tests that expect four views at once. Add each `render_view()` call as the first statement of the loop body or before the assertion named.
- `editor.dm`, `custom_sprite_editor_lifecycle`: replace `TEST_ASSERT(!(length(editor.guide_urls) != 4 || length(editor.preview_urls) != 4), "Each editor must publish all four guides and previews.")` with

```dm
		TEST_ASSERT(!(length(editor.guide_urls) != 1 || !editor.guide_urls["2"] || length(editor.preview_urls) != 1 || !editor.preview_urls["2"]), "Each editor must publish the Front view's guide and preview on opening.")
		for(var/direction in GLOB.custom_style_directions)
			editor.render_view(direction)
		TEST_ASSERT(!(length(editor.guide_urls) != 4 || length(editor.preview_urls) != 4), "Every view must publish its guide and preview once shown.")
```

- `editor.dm`, `custom_sprite_naked_guide`: in each of its four `for(var/direction in GLOB.cardinals)` loops, add `editor.render_view("[direction]")` as the first statement.
- `editor.dm`, the taur hair alignment test (`expected = getFlatIcon(hair, ...)`) and `custom_sprite_taur_canvas`: add `editor.render_view("[direction]")` before `var/icon/guide = editor.guide_icons["[direction]"]`.
- `editor.dm`, `custom_sprite_editor_close_keeps_draft`: replace `length(editor.guide_urls) != 4` with `!editor.guide_urls["2"]`.
- `salon.dm` (the resume check): replace `length(hair_session.editor.guide_urls) != 4` with `!hair_session.editor.guide_urls["2"]`.
- `salon.dm`, `hair_extension_preview`:
  - In the first loop, add `editor.render_view("[direction]")` before `var/icon/guide = editor.guide_icons["[direction]"]`.
  - Replace

```dm
	editor.published_icons.Cut()
	editor.refresh_preview()
	var/index = 0
	for(var/direction in GLOB.cardinals)
		var/icon/rendered = editor.published_icons[++index]
```

with

```dm
	editor.published_icons.Cut()
	editor.refresh_preview()
	var/list/previews = list("2" = editor.published_icons[length(editor.published_icons)])
	for(var/direction in list("1", "4", "8"))
		editor.published_icons.Cut()
		editor.render_view(direction)
		previews[direction] = editor.published_icons[length(editor.published_icons)]
	for(var/direction in GLOB.cardinals)
		var/icon/rendered = previews["[direction]"]
```

- `salon.dm`, `tattoo_hair_layer`: replace `TEST_ASSERT(json_encode(custom_sprite_render_directions(editor.preview_body, worn_overlays = editor.render_overlays())) == json_encode(editor.preview_urls), "Hiding parts from the guide must leave hair and wings on the preview.")` with

```dm
	var/list/expected_previews = custom_sprite_render_directions(editor.preview_body, worn_overlays = editor.render_overlays())
	for(var/direction, expected in expected_previews)
		editor.render_view(direction)
		TEST_ASSERT(editor.preview_urls[direction] == expected, "Hiding parts from the guide must leave hair and wings on the preview.")
```

Nothing else in the suite reads other views of `guide_icons`, `guide_urls` or `preview_urls`. The remaining uses read `"2"`, the view drawn on opening. Run `grep -n 'guide_urls\|preview_urls\|guide_icons' code/modules/unit_tests/~nova/custom_sprites/*.dm` to confirm.

- [ ] **Step 2: DM implementation: `mirror.dm` helpers**

Replace `custom_sprite_render_directions()` with:

```dm
/// A body's look with worn overlays added, captured so its views can be flattened one at a time.
/proc/custom_sprite_preview_appearance(mob/living/carbon/human/body, list/worn_overlays)
	var/mutable_appearance/appearance = new(body.appearance)
	if(length(worn_overlays))
		appearance.overlays += worn_overlays
	return appearance

/// The canvas width a body's previews are flattened at: a taur organ widens it.
/proc/custom_sprite_preview_width(mob/living/carbon/human/body)
	return custom_sprite_taur_overlay(body) ? CUSTOM_SPRITE_TAUR_WIDTH : 32

/// One view of a captured look as a data URL, published through the callback when one is given.
/proc/custom_sprite_render_view(mutable_appearance/appearance, direction, width, datum/callback/publish)
	var/icon/rendered = custom_sprite_flat_icon(appearance, direction, width)
	return publish ? publish.Invoke(rendered) : "data:image/png;base64,[icon2base64(rendered)]"

/// Front, Back, Right and Left data URLs of a captured look, without flipping any view.
/proc/custom_sprite_render_views(mutable_appearance/appearance, width, datum/callback/publish)
	. = list()
	for(var/direction in GLOB.cardinals)
		.["[direction]"] = custom_sprite_render_view(appearance, direction, width, publish)

/// Front, Back, Right and Left data URLs for a preview body, without flipping any view.
/proc/custom_sprite_render_directions(mob/living/carbon/human/body, datum/callback/publish, list/worn_overlays)
	return custom_sprite_render_views(custom_sprite_preview_appearance(body, worn_overlays), custom_sprite_preview_width(body), publish)
```

- [ ] **Step 3: DM implementation: `editor.dm`**

Add to the var block, after `static_dirty`:

```dm
	/// The view the window shows. Guides and previews are drawn for it at once, and for the others once shown.
	var/visible_direction = "2"
	/// The guide's look as the last rebuild captured it, flattened one view at a time.
	var/mutable_appearance/guide_appearance
	/// Hair guide shifts, applied in order: south by the hairstyle offset, then west and south by the species offset.
	var/list/guide_shift
	/// Direction -> TRUE for views whose guide predates the last rebuild.
	var/list/stale_guides = list()
	/// The previewed look for preview_hash, flattened one view at a time.
	var/mutable_appearance/preview_appearance
	/// Canvas width previews are flattened at.
	var/preview_width = 32
	/// Direction -> TRUE for views whose preview predates preview_hash.
	var/list/stale_previews = list()
```

In `rebuild_resources()`, make three changes:

(a) Delete the `release_resources()` call near its start. In the `if(!preview_body)` branch, add `release_resources()` as its first line.

(b) Directly after that branch, before `if(!isnull(workspace.markings_context))`, insert:

```dm
	// Every view keeps its last guide and preview until it's drawn again.
	preview_hash = null
	preview_appearance = null
	for(var/direction in GLOB.custom_style_directions)
		stale_guides[direction] = TRUE
		stale_previews[direction] = TRUE
```

(c) Replace the block from `var/mutable_appearance/rendered = render_appearance(preview_body)` through the end of the `for(var/direction in GLOB.cardinals)` guide loop with a single call: `capture_guide()`.

Replace `release_resources()`:

```dm
/// Drops the guides and previews built from the preview body.
/datum/custom_sprite_editor/proc/release_resources()
	guide_icons = list()
	guide_urls = list()
	preview_urls = list()
	preview_hash = null
	guide_appearance = null
	preview_appearance = null
	stale_guides = list()
	stale_previews = list()
```

Add these procs after `release_resources()`:

```dm
/// Captures the guide's look from the prepared preview body and draws the visible view. Other views are drawn when shown.
/datum/custom_sprite_editor/proc/capture_guide()
	guide_appearance = new(render_appearance(preview_body))
	var/list/worn = render_overlays()
	if(length(worn))
		guide_appearance.overlays += worn
	guide_shift = null
	if(target == "hair")
		var/datum/sprite_accessory/hair/hairstyle = SSaccessories.hairstyles_list[preview_body.hairstyle]
		guide_shift = list(hairstyle?.y_offset || 0)
		if(LAZYFIND(preview_body.dna.species.offset_features, OFFSET_HAIR))
			guide_shift += list(preview_body.dna.species.offset_features[OFFSET_HAIR][INDEX_W], preview_body.dna.species.offset_features[OFFSET_HAIR][INDEX_Z])
	render_guide(visible_direction)

/// Draws one view of the guide the last rebuild captured. Guides are static data, so the window needs a full update afterwards.
/datum/custom_sprite_editor/proc/render_guide(direction)
	if(!guide_appearance)
		return FALSE
	var/icon/guide = custom_sprite_flat_icon(guide_appearance, text2num(direction), workspace.width)
	if(guide_shift)
		guide.Shift(SOUTH, guide_shift[1])
		if(length(guide_shift) > 1)
			guide.Shift(WEST, guide_shift[2])
			guide.Shift(SOUTH, guide_shift[3])
	guide_icons[direction] = guide
	guide_urls[direction] = publish_icon(guide)
	stale_guides -= direction
	static_dirty = TRUE
	return TRUE

/// Draws one view of the preview captured for preview_hash.
/datum/custom_sprite_editor/proc/render_preview(direction)
	if(!preview_appearance)
		return FALSE
	preview_urls[direction] = custom_sprite_render_view(preview_appearance, text2num(direction), preview_width, CALLBACK(src, PROC_REF(publish_icon)))
	stale_previews -= direction
	return TRUE

/// Brings one view's guide and preview up to date. Returns TRUE when anything was drawn.
/datum/custom_sprite_editor/proc/render_view(direction)
	. = FALSE
	if(stale_guides[direction] && render_guide(direction))
		. = TRUE
	if(stale_previews[direction] && render_preview(direction))
		. = TRUE
```

The guide shifts are applied in the same order as before, one `Shift` per step. Don't merge them: shifts of opposite sign clip different rows.

Replace `refresh_preview()` and `render_previews()`, and add `capture_preview()` and `adopt_preview()`:

```dm
/// Timer callbacks push immediately; synchronous UI actions let TGUI send their single final update.
/datum/custom_sprite_editor/proc/refresh_preview(push = TRUE)
	preview_timer = null
	if(closing || !resources_ready)
		return
	draft = workspace.serialize_drawing()
	update_restorable()
	var/new_hash = custom_sprite_hash(draft)
	if(preview_hash == new_hash)
		return
	adopt_preview(capture_preview(draft, workspace.hair_context), new_hash, push)

/// Takes a newly captured preview look: the visible view is drawn now, the others when shown.
/datum/custom_sprite_editor/proc/adopt_preview(mutable_appearance/look, hash, push)
	preview_appearance = look
	preview_width = custom_sprite_preview_width(preview_body)
	preview_hash = hash
	for(var/direction in GLOB.custom_style_directions)
		stale_previews[direction] = TRUE
	render_preview(visible_direction)
	if(push)
		SStgui.update_uis(src)

/**
 * Puts a drawing on the preview body and captures how it looks, for flattening one view at a time.
 *
 * The preview body keeps the given drawing afterwards. Other base looks are restored to the
 * draft before returning, so resources stay consistent with the guides.
 */
/datum/custom_sprite_editor/proc/capture_preview(list/drawing, list/hair, list/markings)
	var/hair_swapped = custom_style_hair_target(target) && hair && json_encode(hair) != json_encode(workspace.hair_context)
	var/markings_swapped = !isnull(markings) && json_encode(markings) != json_encode(workspace.markings_context)
	custom_sprite_apply_round_style(preview_body, list("target" = target, "zone" = body_zone, "drawing" = drawing, "hair" = hair_swapped ? hair : null, "markings" = markings_swapped ? markings : null), emissives_allowed())
	// Hair-only updates don't rebuild the underwear that was hidden for the guides.
	if(custom_style_hair_target(target))
		preview_body.update_body()
	var/mutable_appearance/look = custom_sprite_preview_appearance(preview_body, render_overlays())
	if(hair_swapped)
		custom_style_apply_hair_context(preview_body, workspace.hair_context, update = FALSE, target = target)
	if(markings_swapped)
		custom_style_apply_base_markings(preview_body, body_zone, workspace.markings_context, emissives_allowed())
		preview_body.update_body()
	return look

/// All four views' data URLs of the preview body wearing a drawing, for import and restore previews.
/datum/custom_sprite_editor/proc/render_previews(list/drawing, list/hair, list/markings)
	return custom_sprite_render_views(capture_preview(drawing, hair, markings), custom_sprite_preview_width(preview_body), CALLBACK(src, PROC_REF(publish_icon)))
```

`show_candidate()` keeps calling `render_previews()`, so import and restore previews still show all four views. Its `preview_hash = null` plus `refresh_preview(push = FALSE)` restores the draft as before.

In `sample_guide()`, replace `var/icon/guide = guide_icons[direction]` with:

```dm
		if(stale_guides[direction])
			render_guide(direction)
		var/icon/guide = guide_icons[direction]
```

In `ui_act()`, add this as the first case of the `switch(action)`:

```dm
		if("setView")
			var/direction = params["dir"]
			if(!(direction in GLOB.custom_style_directions) || direction == visible_direction)
				return FALSE
			visible_direction = direction
			render_view(direction)
			return TRUE
```

In `ui_data()`, add `"visibleView" = visible_direction` to the big `list(...)` literal.

At the end of `ui_close()`, add:

```dm
	// The window opens on the Front view again.
	visible_direction = "2"
```

- [ ] **Step 4: DM implementation: `markings_editor.dm`**

Replace the markings `refresh_preview()` and `render_region_previews()`:

```dm
/datum/custom_sprite_editor/markings/refresh_preview(push = TRUE)
	preview_timer = null
	if(closing || !resources_ready)
		return
	var/list/results = region_results()
	update_restorable()
	var/new_hash = md5(json_encode(results))
	if(preview_hash == new_hash)
		return
	adopt_preview(capture_region_previews(results), new_hash, push)

/// Puts exactly what saving would write on the preview body and captures its look. A region too colorful to save shows its saved paint.
/datum/custom_sprite_editor/markings/proc/capture_region_previews(list/results)
	var/list/shown = results.Copy()
	for(var/zone, entry_untyped in results)
		var/list/entry = entry_untyped
		if(entry["error"])
			entry = entry.Copy()
			entry["drawing"] = saved_drawings[zone]
			shown[zone] = entry
	custom_sprite_apply_region_results(preview_body, shown, emissives_allowed())
	return custom_sprite_preview_appearance(preview_body, render_overlays())

/// All four views' data URLs of the preview body wearing these results, for import and restore previews.
/datum/custom_sprite_editor/markings/proc/render_region_previews(list/results)
	return custom_sprite_render_views(capture_region_previews(results), custom_sprite_preview_width(preview_body), CALLBACK(src, PROC_REF(publish_icon)))
```

`show_region_candidate()` keeps calling `render_region_previews()`.

- [ ] **Step 5: tgui: failing test, then the effect**

Create `tgui/packages/tgui/interfaces/common/CustomSpriteEditor/CustomSpriteEditor.views.test.tsx`:

```tsx
// THIS IS AN APHELION UI FILE
import { expect, it } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import { createStore, Provider } from 'jotai';
import { store as backendStore, gameDataAtom } from 'tgui/events/store';
import {
  fixture,
  send,
  setupEditorTests,
} from '../../../__mocks__/customSpriteEditor';
import { CustomSpriteEditor } from './index';

setupEditorTests();

it('asks the server to draw a view only when the window shows a different one', () => {
  backendStore.set(gameDataAtom, { ...fixture(), visibleView: '2' });
  render(
    <Provider store={createStore()}>
      <CustomSpriteEditor target="hair" />
    </Provider>,
  );
  expect(send).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText('Back'));
  expect(send).toHaveBeenLastCalledWith('setView', { dir: '1' });
  send.mockClear();
  fireEvent.click(screen.getByText('Back'));
  expect(send).not.toHaveBeenCalled();
});
```

Run: `cd tgui && bun test packages/tgui/interfaces/common/CustomSpriteEditor/CustomSpriteEditor.views.test.tsx`
Expected: FAIL. No `setView` is sent yet, and `visibleView` isn't in the type.

In `types.ts`, add `visibleView?: string;` to `CustomSpriteEditorData`.

In `index.tsx`, add `visibleView,` to the `data` destructuring. After the guide-loading `useEffect`, add:

```tsx
  useEffect(() => {
    // The server draws guides and previews only for the view the window says it shows.
    if (visibleView !== undefined && visibleView !== String(direction)) {
      act('setView', { dir: String(direction) });
    }
  }, [direction, visibleView]);
```

The shared fixture has no `visibleView`, so existing tests that count `act` calls are unaffected.

Run the focused tgui set from Task 4 Step 5, plus `tgui:tsc`, biome and `tgui:lint`. Expected: all green.

- [ ] **Step 6: DreamChecker and the Tasks 4-5 checkpoint run**

Run DreamChecker into `t5-dreamchecker.log`. Expected: 0 diagnostics.

Run `dm-compile.sh t5 all` and `dm-launch.sh t5`. Expected: `clean_run.lk: Success`, with `canvas_wire` and `editor_visible_view` passing by name and every updated test still passing.

- [ ] **Step 7: Ledger**

Append `Task 4: complete (...)` and `Task 5: complete (...)`, both citing run t5 and the tgui results.

---

### Task 6: Salon refresh triggers

**Files:**
- Modify: `modular_aphelion/modules/custom_sprites/code/salon.dm`:
  - `watch_uniform()` (its signal handler)
  - `on_recipient_changed()`, new `on_uniform_adjusted()`
  - `on_recipient_overlay_changed()`, `schedule_preview_refresh()`
- Modify: `modular_aphelion/modules/custom_sprites/code/mirror.dm`: `custom_sprite_worn_overlays()`, `/datum/custom_sprite_mirror/proc/schedule_refresh()`
- Test: `code/modules/unit_tests/~nova/custom_sprites/salon.dm`

**Interfaces:**
- Produces: `custom_sprite_worn_overlays(source)`, which now leaves out `HANDS_LAYER`. Salon guides, salon previews and mirror pictures all use it.

- [ ] **Step 1: DM test**

Append to `code/modules/unit_tests/~nova/custom_sprites/salon.dm`:

```dm
/// Held items stay out of salon pictures, so picking one up redraws nothing, while worn changes still redraw and relock at once.
/datum/unit_test/custom_sprite_salon/held_items/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	if(session.dress_timer)
		deltimer(session.dress_timer)
		session.dress_timer = null
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	TEST_ASSERT(recipient.put_in_hands(crowbar), "The fixture must be able to hold the crowbar.")
	TEST_ASSERT(!session.dress_timer, "Picking up an item must not redraw the salon guides.")
	var/held = recipient.overlays_standing[HANDS_LAYER]
	var/list/held_overlays = islist(held) ? held : list(held)
	TEST_ASSERT(length(held_overlays - null), "The fixture's crowbar must be drawn in hand.")
	for(var/overlay in custom_sprite_worn_overlays(recipient))
		TEST_ASSERT(!(overlay in held_overlays), "Held items must stay out of salon guides and mirrors.")
	canvas.static_dirty = FALSE
	var/obj/item/clothing/gloves/color/black/gloves = allocate(/obj/item/clothing/gloves/color/black)
	TEST_ASSERT(recipient.equip_to_slot_if_possible(gloves, ITEM_SLOT_GLOVES), "The fixture must be able to wear gloves.")
	TEST_ASSERT(session.dress_timer, "Putting gloves on must redraw the salon guides.")
	TEST_ASSERT(canvas.lock_reasons?[BODY_ZONE_PRECISE_L_HAND], "Gloves must lock the hands at once.")
	TEST_ASSERT(canvas.static_dirty, "A lock change must send the new mask with the next full update.")
	deltimer(session.dress_timer)
	session.dress_timer = null
```

- [ ] **Step 2: Implement**

In `salon.dm`:
- In `watch_uniform()`, register `PROC_REF(on_uniform_adjusted)` instead of `PROC_REF(on_recipient_changed)` for `COMSIG_CLOTHING_UNDER_ADJUSTED`.
- Replace `on_recipient_changed()`, and add `on_uniform_adjusted()` after it:

```dm
/datum/custom_sprite_salon/proc/on_recipient_changed(datum/source)
	SIGNAL_HANDLER
	var/mob/living/carbon/human/recipient = recipient_ref?.resolve()
	if(recipient)
		watch_uniform(recipient)
	// Clothing can cover or uncover tattoo regions, and a self-stylist's mirror can come or go.
	// Redraws follow the worn-overlay signals, which leave held items out.
	editor?.sync_locked_views()

/// Rolling a jumpsuit up or down changes what it covers and how it looks, without taking it off.
/datum/custom_sprite_salon/proc/on_uniform_adjusted(datum/source)
	SIGNAL_HANDLER
	editor?.sync_locked_views()
	schedule_preview_refresh()
	mirror?.schedule_refresh()
```

- In `on_recipient_overlay_changed()`, add these lines as its first statements after `SIGNAL_HANDLER`:

```dm
	// Held items are left out of salon guides and mirrors, so picking things up redraws nothing.
	if(layer == HANDS_LAYER)
		return
```

- In `schedule_preview_refresh()`, change `0.1 SECONDS` to `1 SECONDS`. Change its doc line to `/// Groups a second of changes into one refresh, without postponing it while changes continue.`

In `mirror.dm`:
- `/datum/custom_sprite_mirror/proc/schedule_refresh()`: `0.1 SECONDS` becomes `1 SECONDS`.
- Replace `custom_sprite_worn_overlays()` with:

```dm
/// This body's worn clothing overlays, in layer order. Held items are left out.
/proc/custom_sprite_worn_overlays(mob/living/carbon/human/source)
	. = list()
	for(var/layer in GLOB.worn_overlay_layers)
		if(layer == HANDS_LAYER)
			continue
		var/overlays = source?.overlays_standing?[layer]
		if(overlays)
			. += overlays
```

Don't edit `GLOB.worn_overlay_layers`: the worn_emissives module owns it.

- [ ] **Step 3: DreamChecker and the Task 6 checkpoint run**

Run DreamChecker into `t6-dreamchecker.log`. Expected: 0 diagnostics.

Run `dm-compile.sh t6 all` and `dm-launch.sh t6`. Expected: `clean_run.lk: Success`. `held_items`, `self_styling`, `self_tattoo`, `clothing_refresh`, `covered_start` and `mirror_refresh` must all pass.

- [ ] **Step 4: Ledger**

Append `Task 6: complete (...)`, citing run t6.

---

### Task 7: Docs, benchmark and final checks

**Files:**
- Modify: `modular_aphelion/modules/custom_sprites/module.md`
- Output: `.superpowers/sdd/2026-09-24-custom-sprites-performance/bench/after/`, plus the ledger

- [ ] **Step 1: Update `module.md`**

Edit the prose to match the new behavior, re-wrapping to the file's existing width.

(a) "Rendering and caching": after "Server previews wait for a 0.6-second pause and skip unchanged drawings.", add:

> Guides and previews are drawn only for the view the window shows. The window tells the server when it shows another view, and until then each view keeps its last image. Import and restore previews and the recipient's mirror still draw all four views.

(b) Same section: after "Only the opened drawing is sent to its editor.", add:

> The canvas travels as a palette of its pixel values and one index string per view: one character per pixel, or two once a canvas holds more than 64 values. A stroke re-encodes only its own view.

(c) Replace "Idle windows don't resend drawings. Hairstyle and native-marking choices are static UI data, and the sorted hairstyle lists are shared." with:

> Idle windows don't resend drawings. Hairstyle and native-marking choices, guides, the paintable mask and the region map are static UI data, and the sorted hairstyle lists are shared. A rebuild or a lock change sends them in one full update. Picking a palette color or a region doesn't update the window, which already shows it. Refreshes never bring the window forward; only opening it does.

(d) Replace "Related changes share one refresh and one UI update." (salon guides) with:

> Changes within a second share one refresh and one UI update. Held items are left out of salon guides and mirror pictures, so picking things up or dropping them redraws nothing. Equipment changes still relock regions and views at once.

(e) In the paragraph starting "Color scans collect distinct pixels", add: "Encoding and decoding collect runs in lists and join them once."

(f) In "Previous saved styles", after "It only appears while the draft differs from that style, so it disappears once it has been restored and returns if you undo.", add:

> The offer is worked out with the preview after a pause and after saving, not on every window update.

(g) In "Custom haircuts and tattoos":
- "Dressing or undressing rebuilds them shortly after." becomes "Dressing or undressing rebuilds them within a second."
- "Guides and mirrors add the recipient's worn appearances using the same layer set as worn-emissive rendering." gains ", except held items".

(h) In "Tests and maintenance", add these new tests:
- DM: `codec.dm` round trips, `regions.dm` mask locks, `workspace.dm` canvas wire format, `markings_editor.dm` static data, and `editor.dm` visible view, refresh focus and quiet selection. Also `salon.dm` held items.
- tgui: `canvas.test.ts` covers the compact canvas; `CustomSpriteEditor.views.test.tsx` covers view reporting.

(i) Module table row for `code/editor.dm`: add "Guides and previews are drawn per view (`render_view()`, the `setView` action). Guides, the mask and the region map are static data, sent when `static_dirty`." Row for `code/workspace.dm`: add "the window's compact canvas (`canvas_ui_data()`)".

- [ ] **Step 2: After-benchmark**

Run: `bash .superpowers/sdd/2026-09-24-custom-sprites-performance/bench/bench.sh after`
Expected: every `CSBENCH <scenario> done` line, and no `ERROR`.

Run: `python .superpowers/sdd/2026-09-24-custom-sprites-performance/bench/compare.py .superpowers/sdd/2026-09-24-custom-sprites-performance/bench/baseline/results.json .superpowers/sdd/2026-09-24-custom-sprites-performance/bench/after/results.json > .superpowers/sdd/2026-09-24-custom-sprites-performance/bench/compare-after.txt`

Record the key medians in the ledger, before → after. Expected direction, not a pass/fail gate; state any line that got worse and why:
- `markings/stroke/4_refresh_preview` ~209 ms → roughly 60-80 ms
- `hair/stroke/4_refresh_preview` ~60 ms → ~25-35 ms
- `taur/stroke/4_refresh_preview`
- `*/stroke/3_encode` and `ack_message_bytes`: ~93-196K → ~10-25K
- `codec/validate_32`/`_64`
- `sidecar/load_slot_all_targets` ~110 ms → ~35-45 ms
- `salon/refresh_clothes`
- the `*/open/new_editor` lines

- [ ] **Step 3: Full checks**

Run: `bash .superpowers/sdd/2026-09-24-custom-sprites-performance/final-checks.sh`
Expected: `Found 0 diagnostics`, `tgui:build ok`, and a clean last run.

Run: `cd tgui && bun run tgui:test` (full suite). Expected: all pass; the last count was 380 before the new files.
Run: `cd tgui && bun run tgui:tsc`, and `bun run tgui:lint` from the repo root. Expected: clean.

If any DM code changed after run t6, run the suite again: `dm-compile.sh final all`, then `dm-launch.sh final`.

Check `git status --porcelain`. It must show only intended files; no `.dmi` changes except any the game regenerated under `icons/map_icons/**`, which stay.

- [ ] **Step 4: Final review**

Save `git diff 29fd12cefa6d > .superpowers/sdd/2026-09-24-custom-sprites-performance/review-29fd12c..worktree.diff`. Include untracked new files by listing them in the reviewer prompt.

Use superpowers:requesting-code-review to dispatch one fresh reviewer with read-only instructions. Give it the plan, the spec, this plan's Review Focus verbatim, the ledger's `Ruling:` lines and the diff. Record its verdict in the ledger. Fix anything Critical or Important, re-verify it, and record it.

- [ ] **Step 5: Report**

Report to Pol (the dispatching session relays it). Include:
- What changed, per task.
- The before/after benchmark table from `compare-after.txt`, with the headline lines above.
- Exactly which checks ran and passed: DM run labels with PASS counts, DreamChecker, the tgui counts, tsc, lint and build.
- Anything skipped or ruled differently, with the ledger's `Ruling:` lines.
- That nothing was committed.
