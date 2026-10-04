https://github.com/AphelionDevelopment/Meridian-Rift/pull/

## Personal Cache - customizable survival box (in-fiction: "Bluespace Cache")

Module ID: PERSONAL_CACHE

Code identifiers (module ID, type paths, file names) are unchanged and still say "personal_cache"/"cache_pouch" for stability. In-fiction/player-facing text (item names, descriptions, chat messages) is reflavored as bluespace technology: the box displays as a "bluespace cache" and each pouch subtype displays as a "\_\_\_ bluespace matrix".

### Description:

Adds a "Bluespace Cache" box (replaces the default survival box for jobs using the base outfit) and a new "Cache" tab in the Loadout menu.
Players pick from the respective categories to populate the box's contents.
This box then replaces their emergency survival kit.

The Bluespace Cache can be attuned to its owner with a multitool. While attuned and not carried by its owner, it emits a GPS locator signal, including when a containing backpack is dropped or stolen. Tapping an unowned cache attunes it instantly; the owner tapping their own cache wipes the attunement instantly. Anyone else must hold the cache and use a multitool to open the TGUI routing puzzle. Attunement controls ownership and tracking; it does not prevent access to survival supplies.

Owners can Ctrl-Shift-click their cache in hand to practice without changing attunement or causing a lockout. The real and practice games use the same rules:

- Plan on a 6-by-6 grid before the first pulse starts a 75-second trace. Begin on the top row, then alternate the selected cell's column and row; each cell can be used once.
- Upload both four-symbol signatures within eight pulses. Signatures must be contiguous, can overlap, and may complete in either order. Completed signatures remain uploaded.
- A one-use Stabilize action adds 15 seconds while reducing buffer capacity by one slot. It preserves route and signature progress.
- Exhausting the buffer, reaching a dead end, or running out of time ends the attempt. A failed or abandoned real attempt after the first pulse causes a 30-second lockout; cancelling during planning is free.

Generation derives the overlapping signatures from a legal six-cell route, guaranteeing a solution. `/datum/cache_lock_puzzle` owns move validation and matching; `/datum/cache_lock_session` owns TGUI, the trace timer, and cleanup. Only one session can own a cache at a time. Every action validates user identity, current ownership, in-hand access, deadline, revision, and cell legality on the server. Dropping the cache, changing its owner, closing the UI, or deleting the cache invalidates the session.

`examine()` names the current owner (or says it's unattuned), explains tracking and attunement, and shows the Ctrl-Shift-click practice hint to the owner. Items that no matrix accepts are rejected at the cache root.

Every Bluespace Cache is seeded with three standing bluespace matrices (`standing_pouches` on `/obj/item/storage/box/personal_cache`) before anything else is added to it:

- A "survival bluespace matrix" (`cache_pouch/survival`) that accepts air tanks, masks, and a broad sweep of medical supplies - medical stacks, hyposprays/medipens, syringes, pill bottles (e.g. potassium iodide), pills and patches (both `/reagent_containers/applicator` subtypes), health analyzers, inhalers, medigel, blood packs, IV chem packs and chem bottles. Capped at `WEIGHT_CLASS_SMALL` on purpose, which is what keeps medkits out - this is a survival box, not a medbay. The box's baked-in default tank/mask/medipen are sorted into this matrix on creation, and "Cache" tab tank/mask picks replace the matching default there instead of sitting loose in the box.
- A "ration bluespace matrix" (`cache_pouch/rations`) that accepts food, condiments, drinking glasses and booze bottles (`/cup/glass`), vending-machine cans (`/cup/soda_cans`, which hang off `/cup` directly rather than off `/cup/glass`), and actual ration packs (`/storage/box/ration`, `/storage/box/colonial_rations`). Raised to `WEIGHT_CLASS_NORMAL` since those ration packs are boxes. "Cache" tab ration picks go here.
- A "general bluespace matrix" (`cache_pouch/general`) that holds small items unrestricted by type - the catch-all for anything the pickier matrices won't take. Its `desc` builds its own slot count from `atom_storage.max_slots` so the number can't drift. Deliberately has no `set_holdable()` call: a null `can_hold` *is* the catch-all behaviour. "Cache" tab general picks go here.

Each matrix's `desc` spells out what it auto-sorts and each sets a hand-written `can_hold_description`, so both examine passes read like prose instead of dumping a raw typepath list at the player.

Every matrix (and the cache itself) is `FIRE_PROOF` with `foldable_result = null` - the base `/obj/item/storage/box` is flammable cardboard, and a fire being able to delete someone's entire organized kit is not the intent.

Which standing matrix (if any) each `CACHE_SLOT_*` routes to is a single data-driven map - `slot_to_pouch` on `/obj/item/storage/box/personal_cache`, read through the overridable `get_pouch_for_slot()` proc (base survival boxes return null from this, i.e. no matrix, picks fall to the box root). All placement of a Cache pick - default preference or matrix preference alike - goes through one shared proc, `/datum/loadout_item/cache/proc/place_in_cache()` in `loadout_cache.dm`, which also handles evicting whatever a tank/mask pick replaces (via its own `slot_to_replaced_type` map) and deletes the item if it can't be placed (no box, or the box has `cache_locked` set for that slot) rather than leaving it orphaned. Adding a new Cache slot that should live in its own matrix means: add the matrix type in `cache_pouches.dm` with a `sort_priority`, add it to `standing_pouches` if every cache should get one for free, then add one entry each to `slot_to_pouch`, `slot_limits` and `slot_labels`. The tab's blurb text builds itself from the last two, so there's no string to hand-edit.

The box's baked-in oxygen candle (added to `/obj/item/storage/box/survival/PopulateContents()` by a core NOVA EDIT) is deleted right after `PopulateContents()` runs - the Bluespace Cache never carries one. Everything else survival's `PopulateContents()` might add (the premium flare/radio, the radioactive-nebula potassium iodide bottle, the escape hook) gets swept into a matrix the same way manually-inserted items do - see `sort_into_matrix()` below - rather than sitting loose in the box root eating into its slot budget.

Players can alternatively set their loadout override preference to "Place all in cache" (`LOADOUT_OVERRIDE_CACHE_POUCH`), which packs their non-Cache loadout selections into a "loadout bluespace matrix" (`cache_pouches.dm`, 21 slots, up to WEIGHT_CLASS_NORMAL per item - sized to fit a full loadout) slotted into their Bluespace Cache instead of their backpack. "Cache" tab picks are excluded from this matrix entirely and always go to the appropriate standing matrix above, regardless of override preference.

The loadout matrix restricts reinsertion by identity: its spawned items receive `TRAIT_LOADOUT_POUCH_ITEM` with that matrix's reference string as the trait source. `can_insert()` checks that exact source, so another player's tagged loadout items are rejected too. The bespoke marker stores only a string and does not retain the matrix. For jobs with an ordinary survival box, the loadout matrix is delivered separately; nesting its NORMAL-capacity storage in those SMALL-capacity boxes would prevent reinsertion.

Cache-category selections are spawned once after the outfit is equipped, with their exact instances retained through customization and `place_in_cache()`. This applies to backpack, suitcase, and cache-matrix delivery preferences and avoids mistaking a stock survival tank for a selected item of the same type.

Loadout picks from the "Erotic" category are packed into a restricted "love bluespace matrix" (holds only `GLOB.erp_items`) which is nested inside the Bluespace Cache, rather than being equipped loose to a pocket.

Every bluespace matrix inside a Bluespace Cache (`/obj/item/storage/box/cache_pouch` and all its subtypes) is fused in place once inserted - none of them can be removed from the box (`/datum/storage/box/personal_cache/attempt_remove`).

Anything that lands directly in the cache's own root - manually dropped in by a player, or left over from `PopulateContents()` - is auto-sorted by `/obj/item/storage/box/personal_cache/proc/sort_into_matrix()`. It collects every matrix actually inside the box, sorts them by `sort_priority` (a var on `/obj/item/storage/box/cache_pouch`, using the `CACHE_SORT_*` bands), and re-homes the item into the first one that accepts it, returning that matrix so the caller can report where it went. Matrices are never auto-sorted into each other.

Priority order matters for correctness, not just taste. The loadout and love matrices are optional (spawned only by the relevant loadout-override / Erotic-category paths) so they're not in `standing_pouches` at all, and both overlap the broad matrices: plenty of `GLOB.erp_items` gear is technically a `/obj/item/clothing/mask` or an `/obj/item/reagent_containers/applicator/pill`, which the survival matrix would otherwise claim first. Ranking them at `CACHE_SORT_IDENTITY`/`CACHE_SORT_RESTRICTED` ahead of `CACHE_SORT_SURVIVAL` fixes that, and the catch-all sits at `CACHE_SORT_CATCHALL` so it always goes last. Adding a new matrix is now a `sort_priority` value and nothing else - there is no ordering list to keep in sync.

Both `PopulateContents()` (a one-time sweep of whatever's loose after survival's own populate step) and `/datum/storage/box/personal_cache/attempt_insert()` (every later player-driven insertion - drag-drop, click-to-insert, mass pickup) call into this same proc, so there's one place that decides "what goes where." `attempt_insert()` also balloon-alerts the destination ("filed: survival bluespace matrix") so auto-sorting doesn't just read as the box eating things; the spawn-time sweep passes no user and stays silent.

The cache root is a hallway, not a shelf. `/datum/storage/box/personal_cache/can_insert()` refuses anything that `find_matrix_for()` can't place, so nothing ever comes to rest in the root - the spare slot exists to give sorting somewhere to breathe, not for loose junk to squat in. The one exception is a cache with no matrices at all (an admin-spawned oddity), which falls back to behaving like an ordinary box rather than refusing everything and bricking itself.

With `allow_quick_gather = TRUE` the cache picks up like a bag: click a pile on the floor and everything sortable is swept straight into the matrices, one second per pass, with the usual gather-mode action button for switching between collecting everything / same type / one at a time. Anything no matrix wants is left on the floor rather than stuffed into the root. Mass pickup runs with `messages = FALSE`, so the per-item "filed:" balloon stays quiet and you just get the standard "picked up" at the end.

With `allow_quick_empty = TRUE`, dragging onto a tile empties the matrices after a five-second delay. Source/destination reachability, locks, and matrix membership are rechecked after the delay. Machinery receives the dump signal for each matrix's storage, so disposal and processing handlers see the items instead of the fused matrices. Transfers into other storage likewise move only matrix contents.

Both the cache root and the matrices set `allow_big_nesting = TRUE`. This is load-bearing, not decorative: `can_insert()`'s nesting gate is a `>=` comparison against the holder's `w_class`, so without it *no* storage item can ever enter a same-sized container - which meant pill bottles (the survival matrix's advertised contents, and the radioactive-nebula potassium iodide bottle the box ships with) silently bounced off every time. The cache root pairs it with a short `cant_hold` list (`/obj/item/storage/box/personal_cache`, `/obj/item/storage/medkit`) so it can't nest inside itself and doesn't swallow medkits; backpacks and duffels need no exclusion since they're `WEIGHT_CLASS_BULKY` and already fail the size gate.

### TG Proc/File Changes:

- `code/modules/jobs/job_types/_job.dm`: `/datum/outfit/job/var/box`

### Modular Overrides:

- `modular_nova/master_files/code/game/objects/items/storage/boxes/job_boxes.dm`: `/obj/item/storage/box/survival/var/cache_locked`, `/obj/item/storage/box/survival/proc/get_pouch_for_slot` (base stub, returns null; overridden on `personal_cache`)
- `modular_nova/modules/loadouts/loadout_ui/loadout_outfit_helpers.dm`: `/mob/living/carbon/human/proc/equip_outfit_and_loadout`
- `modular_nova/master_files/code/modules/client/preferences/loadout_override_preference.dm`: `/datum/preference/choiced/loadout_override_preference/init_possible_values()`

### Module Files:

- `modular_nova/modules/personal_cache/code/personal_cache_box.dm`: cache ownership, session entry points, nested GPS tracking, matrix routing, species survival supplies, and bulk storage operations.
- `modular_aphelion/modules/personal_cache/code/cache_lock_puzzle.dm`: routing puzzle generation, validation, signature matching, and recovery budget.
- `modular_aphelion/modules/personal_cache/code/cache_lock_session.dm`: TGUI session authorization, trace deadline, and cleanup.
- `modular_aphelion/modules/personal_cache/code/cache_tests.dm`: focused regressions integrated into the existing DM unit harness.
- `tgui/packages/tgui/interfaces/PersonalCacheLock.tsx`: routing grid, signatures, buffer, trace, and recovery controls.
- `modular_nova/modules/personal_cache/code/loadout_cache.dm`: the "Cache" loadout category, its items, and the shared `place_in_cache()` placement/eviction logic used by every override preference.
- `modular_nova/modules/personal_cache/code/cache_pouches.dm`: restricted-storage bluespace matrices (`survival`/`rations`/`general`/`loadout`/`erp`) that can nest inside a survival box, their `sort_priority` values, and the `/datum/element/loadout_pouch_item` marker element used to identity-tag loadout matrix contents.

`wardrobe_removal()` is overridden because the core version (`/obj/item/storage/box/survival/wardrobe_removal()`) looks for the mask and tank with `locate(...) in src`, which only searches direct contents. By the time `SSwardrobe` fires that callback the cache has already sorted both into the survival matrix, so the core version found nothing, left the useless oxygen gear in place, and dumped the plasmaman/vox replacement tank loose in the cache root. The override searches `get_all_contents()` instead and runs the replacement through `sort_into_matrix()`. It deliberately does not call `..()` - the parent's lookups would still no-op and re-running it would spawn a second tank.

### Cross-module dependencies:

The ration matrix's holdable list names two types owned by other modules - `/obj/item/storage/box/ration` (`modular_nova/modules/emergency_rations/`) and `/obj/item/storage/box/colonial_rations` (`modular_nova/modules/food_replicator/`). Both are in `tgstation.dme`, so this compiles today, but removing either module means dropping the matching line from `set_holdable()` in `cache_pouches.dm` or the build breaks on an unknown typepath.

### Defines:

- `code/__DEFINES/~nova_defines/customization/personal_cache.dm`: CACHE_SLOT_TANK, CACHE_SLOT_MASK, CACHE_SLOT_RATION, CACHE_SLOT_GENERAL; CACHE_SORT_IDENTITY, CACHE_SORT_RESTRICTED, CACHE_SORT_SURVIVAL, CACHE_SORT_RATIONS, CACHE_SORT_CATCHALL (matrix sort-priority bands)
- `code/__DEFINES/~nova_defines/loadouts.dm`: LOADOUT_OVERRIDE_CACHE_POUCH (new, added to a pre-existing but previously-unused define block)
- `code/__DEFINES/~nova_defines/traits.dm`: TRAIT_LOADOUT_POUCH_ITEM (new)

### Credits:

Moonridden
