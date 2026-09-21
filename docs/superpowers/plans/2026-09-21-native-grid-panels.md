# Native grid inventory panels

**Goal:** Correct item fitting, then replace the pilot's oversized storage chrome with compact, themed native panels and direct manipulation.

**Design:** Keep the 7x3 backpack grid: 21 tiny items matches a normal backpack. Use 24px cells, a thin grid, solid frame and draggable title bar. Double-click a nested container to open another independently positioned, closable panel. Keep its original storage owner and capacity rules. Show item name, category, description and controls in a themed native tooltip. Q/E and the wheel rotate an active item drag through four quarter turns; remove the rotate button. Existing HUD preference changes retheme every open panel without resetting its position.

**Architecture:** A per-mob session owns the open-panel relationships, focus and mouse gesture. Real storage datums retain viewer registration, contents, restrictions and lifecycle. The grid interface uses geometric placements for the pilot and ordinary slots for other nested containers. Only proxy screen objects appear in the panels. Small core hooks admit multiple session views, claim rotation input before normal bindings, and propagate HUD style changes.

**Constraints:** Current branch, uncommitted changes. No conversion of ordinary backpacks. No new browser UI. Native tests and client captures must be distinguished from full gameplay acceptance.

- [x] Reproduce generated-icon size-cache collision and add centering/fit regression coverage.
- [x] Replace the incorrect cache with the existing icon dimension helper; verify native upright/rotated appearances.
- [x] Add session membership and per-viewer proxy hooks to storage and HUD theme updates.
- [x] Add compact theme chrome, native tooltip and movable panel layout.
- [x] Implement container double-click and directional drag rotation with input capture and cleanup.
- [x] Add regression coverage for multiple panels, closure/access, style swaps, rotation and item-display lifecycle.
- [x] Compile, run focused storage tests, capture native panels and document the remaining gameplay verification.

Validation: BYOND 516.1687 compiled with zero errors and two existing warnings.
All 12 focused behavior tests and a connected-client lifecycle fixture passed,
with no runtimes and a clean-run marker. Native captures show the original HUD
anchor, separate panels, compact tooltip and live Midnight/Plasmafire styling.
Both double-click event orders and delayed single pickup pass regression tests.
Physical input under latency, two connected viewers and current performance
measurements remain outside this verification.
