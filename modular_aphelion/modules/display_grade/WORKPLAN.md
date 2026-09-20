# Configurable game-wide color grading

## Summary

Add an account-wide **Display grade: Off / Reference / Custom** preference, defaulting to **Off**.

The Reference preset targets the [approved comparison preview](see attached): **plum shadows, blue-green/sage midtones, cream highlights, and subdued warm accents**, applied consistently across the world, HUD, and browser interfaces.

Custom mode exposes the colors and grading parameters. The preview establishes the artistic direction; native rendering fidelity and performance still require verification.

## Preferences and editor

Add the setting under Game Preferences → Display, with a **Configure** button opening a dedicated editor. Reuse existing TGUI sliders, numeric inputs, and color-picker components.

| Control | Range | Reference starting value |
|---|---|---|
| Overall strength | 0–100% | 100% |
| Saturation | 0–150% | 72% |
| Contrast | 50–150%; 100% is neutral | 100% |
| Brightness | −20 to +20%; 0 is neutral | 0 |
| Shadow color / strength | Hex color / 0–100% | `#2D2639` / 100% |
| Midtone color / strength | Hex color / 0–100% | `#718A83` / 40% |
| Highlight color / strength | Hex color / 0–100% | `#D6C998` / 100% |

These are proposed starting parameters, not values extracted from the generated image.

- Provide live preview across the player’s world and open interfaces, plus a small comparison panel containing grayscale, colored objects, text, and warning indicators.
- Editing Reference creates a Custom draft. The built-in preset remains available, and switching modes preserves the saved custom settings.
- **Apply** saves the complete draft and activates Custom. **Cancel**, closing the editor, or disconnecting discards unapplied changes and restores the saved selection.
- **Reset to Reference** resets the draft. **Before/After** temporarily bypasses the entire grade without changing saved settings.
- Keep the editor’s controls and raw color swatches ungraded so colors can be selected accurately and extreme settings cannot obscure Apply/Cancel. Its comparison panel remains graded.
- Store one custom profile per account in v1. Presentation changes never rewrite sprite colors, character customization, or existing theme preferences.

## Rendering approach

### Shared grading model

Replace the earlier single-matrix assumption with a bounded, three-band composite. One affine RGB matrix cannot independently assign arbitrary shadow, midtone, and highlight colors; native implementation will combine color matrices, alpha masks, and render layers. These primitives are supported by [BYOND’s filter system](https://www.byond.com/docs/ref/info.html#/{notes}/filters).

Use the same defined operation in both renderers:

1. Apply saturation, then contrast around middle gray, then brightness; clamp the result to normalized RGB.
2. Calculate luma from that adjusted image and derive overlapping tonal weights.
3. Blend the adjusted image toward each selected color according to that band’s tint strength.
4. Combine the weighted results, then blend with the original image using overall strength.

```text
Y = 0.2126R + 0.7152G + 0.0722B

shadow_weight    = max(1 − 2Y, 0)
highlight_weight = max(2Y − 1, 0)
midtone_weight   = 1 − shadow_weight − highlight_weight

band_result = lerp(adjusted_RGB, band_color, band_strength)
graded_RGB  = sum(band_weight × band_result)
output_RGB  = lerp(original_RGB, graded_RGB, overall_strength)
```

Perform the color operations in normalized sRGB. Preserve original alpha exactly; do not introduce blur, grain, scanlines, or spatial changes.

### Native world and HUD

- Integrate at the displayed endpoint of the existing master rendering plate, after world/HUD composition and existing gameplay effects.
- Use shared source textures and a fixed number of masked branches. Composite weighted color contributions in an opaque intermediate, then restore source alpha once, avoiding repeated alpha multiplication.
- Grade each displayed map once. Lower-floor masters feeding another master remain ungraded, preventing repeated grading through multiz.
- Refresh attachments on HUD reconstruction, perspective changes, active-floor changes, secondary map creation, and preference updates.
- Preserve mouse targeting, existing filter ordering, and accessibility/debug effects. Give every owned filter and render target a distinct name.
- Off and zero overall strength remove the grade’s filters and intermediate rendering resources.

### Browser interfaces

- Extend the shared TGUI window bootstrap and lifecycle, covering ordinary interfaces, chat, stat panels, lobby, speech, and escape menus.
- Implement the same equations using an SVG filter graph with color matrices, tonal masks, and compositing. Explicitly set `color-interpolation-filters="sRGB"` and account for premultiplied alpha. [W3C filter specification](https://www.w3.org/TR/filter-effects-1/)
- Apply once at the document composition root, covering backgrounds, images, text, and portal-mounted tooltips.
- Supply settings during initialization and refresh them on readiness, reload, and pooled-window reuse.
- Extend the common legacy-browser wrapper and visible raw `browse()` pages with the same bootstrap. Track their window IDs for live updates and release registrations on close.

## Ownership, interfaces, and update lifecycle

Keep definitions, grading calculations, preference handling, and lifecycle helpers in an Aphelion module, using narrow, marked hooks in shared code.

- Add a saved `display_grade_mode` preference and structured `display_grade_custom` settings containing the controls above.
- Maintain a separate temporary preview override owned by the client and editor session. Do not place draft values into the normal preference cache before Apply.
- Add shared `DisplayGradeSettings` frontend typing and a `display/grade` browser update carrying the server-validated effective settings and an update revision.
- Validate known modes, finite numeric ranges, and RGB hex colors on the server. Missing settings initialize to Off with Reference values available for customization.
- Coalesce preview updates to at most one every 100 ms, always sending the final drag value. Apply and Cancel invalidate queued draft updates so stale messages cannot restore them.
- Recompute coefficients only when settings change. Use no per-tick server processing, per-sprite recoloring, pixel readback, or recurring broadcasts.

All game-controlled rendering surfaces are included, except the deliberately neutral editor controls. Windows title bars, native BYOND dialogs, and external applications remain outside the effect.

## Verification and delivery

Implement in this order: **renderer proof → preferences/editor → full interface coverage → native acceptance testing**.

The first deliverable must demonstrate the three tonal controls on matching BYOND/browser swatches and an actual game scene. If native compositing cannot preserve alpha, input behavior, or the performance budget, report that limitation before expanding the implementation; do not silently replace the agreed controls with a simpler effect.

Required checks:

- **Grading:** independent tonal colors and strengths, neutral settings, zero-strength identity, continuous grayscale transitions, saturated colors, transparency, and matching native/browser output.
- **Preferences:** defaults, persistence, reconnects, player isolation, Apply/Cancel, reset, temporary bypass, invalid inputs, and late preview messages.
- **Lifecycle:** multiz, cameras, ghosting/body changes, HUD rebuilds, secondary maps, lighting, emissives, existing tints, window reuse, tooltips, scrolling, and transparent overlays.
- **Visual acceptance:** real DreamSeeker before/after captures showing the world and several interfaces. Confirm the blue-green/plum/cream relationship and distinguishable red/amber/green warnings. Target 4.5:1 ordinary-text contrast and 3:1 essential-control contrast for the Reference preset, documenting existing failures separately. [Text guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [Control guidance](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)
- **Performance:** compare Off, Reference, and Custom using three warmed-up 60-second runs at 1080p and 1440p with zero, one, and four interfaces. Include integrated graphics before claiming low-end suitability.
- **Acceptance budget:** no more than 5% regression in median or p95 frame time, no new recurring UI stalls, and no accumulating resources after repeated toggles or editor sessions.
- **Build verification:** focused DM/frontend tests, TypeScript checks, TGUI production build, and DreamMaker compilation.

Deliver the implementation with the exact preset parameters, native comparison captures, and measured performance results.
