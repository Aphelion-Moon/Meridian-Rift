# TGUI base themes and lobby title screens

**Module ID:** `lobbyscreen`

This system combines player-selected TGUI base themes with an administrator-managed lobby title screen. It shares the theme and artwork components between ordinary TGUI windows, the lobby, and the title-screen preview.

## Setting ownership

| Setting                                                            | Applies to                                                             | Saved in                                                 |
| ------------------------------------------------------------------ | ---------------------------------------------------------------------- | -------------------------------------------------------- |
| Base theme selected with the gear menu                             | One player's TGUI windows and lobby                                    | Account preference `meridian_theme`                      |
| Title image, screen effect, scanlines, bezel and optional wordmark | Everyone's lobby; appearance is stored separately for each title image | `data/title_screen_settings.json`                        |
| Automatic title rotation                                           | The server                                                             | `data/title_screen_settings.json`                        |
| Development showcase theme override                                | One open TGUI window                                                   | Temporary frontend state; cleared when the window closes |

The title-screen manager itself uses the viewing administrator's base theme. Selecting Wastelander in its gear menu does not select Wastelander for other players. Everyone receives the same title image and per-image settings, but theme-dependent colors and the lobby menu follow each player's preference. A bezel choice is independent of the base theme, including the separately named Aphelion theme and Aphelion bezel.

## Defaults

| Setting                             | Default                                             |
| ----------------------------------- | --------------------------------------------------- |
| Account base theme                  | Standard (`meridian`)                               |
| Title image                         | Meridian Rift (default), the normal built-in master |
| Screen                              | Convex (`convex`)                                   |
| Scanlines                           | Version 2 (`scanlines-classic`)                     |
| Bezel                               | Dark Brown (`rusty-dark`)                           |
| Rotate title screens each round     | Off                                                 |
| Extra wordmark on configured images | Off                                                 |

Saved administrator settings take precedence over these defaults. Images without their own appearance record inherit the current per-screen defaults. The normal built-in master already contains the wordmark; its rendering does not depend on the optional wordmark toggle for configured images.

The startup terminal can initially show a configured loading splash or the transparent loading placeholder. The selected title takes over when the normal title-selection path runs; changing the title defaults does not replace the loading sequence.

## TGUI base themes

Use the gear in a TGUI title bar or the lobby to select an account-wide base theme. The server saves valid selections and refreshes that player's open windows and lobby. No administrator permission is required.

The account preference is stored as the top-level `meridian_theme` key in `data/player_saves/<first letter of ckey>/<ckey>/preferences.json`. It uses `PREFERENCE_PLAYER`, so one selection applies across character slots. The gear menu renders this preference directly.

| Display name | Stored ID               |
| ------------ | ----------------------- |
| Standard     | `meridian`              |
| Classic NT   | `meridian_classic`      |
| Wastelander  | `meridian_pipboy`       |
| Vector       | `meridian_vector`       |
| Foundry      | `meridian_foundry`      |
| Diagnostic   | `meridian_diagnostic`   |
| Highline     | `meridian_highline`     |
| Synapse      | `meridian_synapse`      |
| Synapse XXXO | `meridian_synapse_xxxo` |
| Cyberpunk    | `meridian_cyberpunk`    |
| Augmentation | `meridian_augmentation` |
| Afterlight   | `meridian_afterlight`   |
| Relay        | `meridian_relay`        |
| Bastion      | `meridian_bastion`      |
| Aphelion     | `meridian_aphelion`     |

Wastelander retains the `meridian_pipboy` ID for saved-preference compatibility. Classic NT uses the original Nanotrasen component styling without the Meridian console layer.

Ordinary TGUI windows resolve their appearance in this order:

1. A temporary development override for that window.
2. An explicitly requested specialty theme, such as paper or syndicate.
3. The saved account base theme.
4. An ordinary requested/device base theme.
5. Standard.

The lobby uses the account base theme. Specialty interfaces retain their authored appearance; their gear still updates the account preference used by ordinary windows. Legacy base IDs are accepted by the resolver, but the preference picker sends canonical IDs from the table above.

In a development build, open the Kitchen Sink with F12 or the title-bar bug button. Its skin controls preview a window-local override. **Inherit** clears that override, and closing the window discards it. The component examples and loader study use the same production theme components.

## Title-screen picker

Administrators with Fun permission (`R_FUN`) can open **Title Screen: Manage** in the Fun category, or use the lobby's title-management control. Both routes open the same manager. Permission is checked again when handling changes and after a confirmation dialog returns.

1. Select a title image from the list. The two built-in Meridian Rift entries use different wordmark presentations; configured images appear alongside them.
2. Adjust the screen effect, scanlines and bezel in the local preview. Configured images can also display the themed wordmark over the picture.
3. Choose **Apply for everyone** and confirm to make the selection live and save its appearance.
4. Choose **Revert** to discard the draft and return to the currently live screen and settings.

Selecting another image loads that image's saved appearance into the draft. Reopening a closed manager also starts from live state. An untouched open manager follows external changes; an edited draft remains local. If another administrator changes the same appearance or the live screen changes during confirmation, the manager requires the draft to be reviewed again rather than applying stale state.

| Control   | Choices                                                                                               |
| --------- | ----------------------------------------------------------------------------------------------------- |
| Screen    | Flat (`flat`), Vignette (`edge`), Convex (`convex`)                                                   |
| Scanlines | None (`none`), Version 1 (`scanlines-light`), Version 2 (`scanlines-classic`)                         |
| Bezel     | Rusty (`rusty`), Dark Brown (`rusty-dark`), Aphelion (`aphelion`), Classic (`classic`), None (`none`) |

**Rotate title screens each round** is independent of the draft: toggling it saves immediately, without Apply. When enabled, unattended title changes choose from the configured image pool and use the chosen image's own appearance. Turning rotation off pins the managed screen currently showing. With rotation off and no explicit selection, the normal built-in Meridian Rift master is used.

The existing **Title Screen: Change** verb remains available for direct uploads. Uploaded images are unmanaged: they have no persistent per-image record in the picker. Select a managed image in the picker to resume editing its presentation. **Title Screen: Set Notice** updates the lobby notice, and **Fix Lobby Screen** refreshes the lobby for the administrator using it.

## Configured images and persistence

The subsystem discovers images from `<config.directory>/title_screens/images/` during initialization. Add a BYOND-loadable image there and restart the server to include it in the picker. Configured filenames are the stable keys used for selection and per-image appearance.

The discovery code excludes the reserved `exclude`, `blank.png` and `startup_splash` names from the normal image pool. A filename beginning with `startup_splash+` selects the loading splash instead. Keep ordinary image filenames free of `+`; that separator is used by the splash naming convention.

`data/title_screen_settings.json` currently uses schema version `"3"`:

| Field                   | Meaning                                                                                                  |
| ----------------------- | -------------------------------------------------------------------------------------------------------- |
| `_version`              | Persistence schema version                                                                               |
| `selected`              | Pinned configured filename; `null` means the normal master, `__default_alt__` means the alternate master |
| `rotate`                | Whether automatic rotation is enabled                                                                    |
| `screens`               | Appearance records keyed by configured filename or a built-in master key                                 |
| `screens[key].variant`  | Screen effect ID                                                                                         |
| `screens[key].bezel`    | Bezel ID                                                                                                 |
| `screens[key].texture`  | Scanline ID                                                                                              |
| `screens[key].wordmark` | Whether to add the themed wordmark over a configured image                                               |

The normal master's appearance record uses `__default__`; the alternate uses `__default_alt__`. These record keys are distinct from the normal master's `null` selection value.

Records for missing images are retained, allowing a temporarily removed file to recover its appearance when restored under the same name. An unavailable pinned selection is cleared at initialization. Renaming an image creates a different key.

The loader converts version 1's shared settings into per-image records and version 2's boolean bezels into `TITLE_BEZEL_CLASSIC` or None. The retired `convex-bezel` effect is split into Convex plus `TITLE_BEZEL_CLASSIC`. Historical `original` / `navarobl` texture values normalize to `scanlines-light` / `scanlines-classic` when loaded. These migrations preserve explicit historical settings rather than applying the new defaults wholesale. Loading a missing or unsupported-version settings file leaves the compiled defaults in place.

`data/progress_cache.json` is separate: it stores startup timing information for the loading terminal, not title selection or player themes. The active lobby is rendered by TGUI; the old `lobby_html.txt` element-editing instructions do not configure this implementation.

## Implementation map

### Backend

| File                                                                                                                      | Responsibility                                                                                                       |
| ------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| [code/\_title_screen_defines.dm](code/_title_screen_defines.dm)                                                           | Title defaults, valid bezel IDs, master keys, persistence versions and manager permission                            |
| [code/title_screen_subsystem.dm](code/title_screen_subsystem.dm)                                                          | `SStitle`: discovery, selection, per-image validation, persistence/migration, startup progress and asset publication |
| [code/title_screen_manager.dm](code/title_screen_manager.dm)                                                              | Per-admin draft, preview data, confirmation, conflict checks and manager entrypoint                                  |
| [code/lobby_menu_title_controls.dm](code/lobby_menu_title_controls.dm)                                                    | Modular lobby asset delivery, initial title payload, manager permission flag and theme/manager messages              |
| [code/title_screen_controls.dm](code/title_screen_controls.dm)                                                            | Upload, notice and refresh verbs                                                                                     |
| [code/new_player.dm](code/new_player.dm) and [code/title_screen_pref_middleware.dm](code/title_screen_pref_middleware.dm) | Lobby visibility and character-name updates                                                                          |
| [Meridian preference implementation](../../../modular_aphelion/modules/meridian_ui/code/preferences.dm)                   | Account preference, exact ID validation, saving and same-player refreshes                                            |
| [Meridian TGUI transport](../../../modular_aphelion/modules/meridian_ui/code/tgui.dm)                                     | Config augmentation, config-only updates and `setMeridianTheme` message handling                                     |

Changing a base theme sends `setMeridianTheme` with `{ theme }`. The frontend updates optimistically; the server validates the canonical ID and refreshes the authoritative selection. Config-only updates avoid invoking an interface's `ui_data()` just to repaint its theme.

Title image publication carries the image URL and appearance together. Asset generations and complete published snapshots prevent a late asset operation or newly opened lobby from pairing one image with another image's settings. Appearance-only changes reuse the image asset.

### Frontend and styles

| File or directory                                                                                                                                                                                                     | Responsibility                                                                                       |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| [meridian-theme.ts](../../../tgui/packages/tgui/constants/meridian-theme.ts)                                                                                                                                          | Canonical theme catalog, palette metadata, aliases and resolution                                    |
| [Layout.tsx](../../../tgui/packages/tgui/layouts/Layout.tsx), [store.ts](../../../tgui/packages/tgui/events/store.ts) and [useRootThemeClasses.ts](../../../tgui/packages/tgui/hooks/useRootThemeClasses.ts)          | Shared theme state, precedence and owned root-class cleanup                                          |
| [MeridianThemePicker.tsx](../../../tgui/packages/tgui/layouts/MeridianThemePicker.tsx)                                                                                                                                | Shared gear menu and keyboard navigation                                                             |
| [MeridianTitleBarUtilities.tsx](../../../tgui/packages/tgui/layouts/MeridianTitleBarUtilities.tsx)                                                                                                                    | Ordinary-window picker integration and development control                                           |
| [TitleScreenManager.tsx](../../../tgui/packages/tgui/interfaces/TitleScreenManager.tsx)                                                                                                                               | Administrative title list, draft controls and preview                                                |
| [TitleArtwork.tsx](../../../tgui/packages/tgui/interfaces/common/TitleArtwork.tsx)                                                                                                                                    | Shared screen effects, wordmark presentation, bezel, scanlines and legacy frontend fallbacks         |
| [AphelionLobbyMenu.tsx](../../../tgui/packages/tgui-lobby/AphelionLobbyMenu.tsx), [menuTheme.ts](../../../tgui/packages/tgui-lobby/menuTheme.ts) and [themeFocus.ts](../../../tgui/packages/tgui-lobby/themeFocus.ts) | Themed lobby composition, menu profiles and focus exclusions                                         |
| [meridianos/](../../../tgui/packages/tgui/styles/meridianos/)                                                                                                                                                   | Shared theme tokens, components, loaders, decoration, accessibility rules and stylesheet entrypoints |
| [lobby meridianos/](../../../tgui/packages/tgui-lobby/styles/meridianos/)                                                                                                                                                            | Lobby layout profiles, artwork integration and decorative scanline layer                             |

`meridianos/_shared.scss` contains the common font/token/theme imports. `_index.scss` assembles ordinary TGUI styling; the lobby's `styles/meridianos/_meridian.scss` assembles its styling. `_preferences.scss` and `_titlebar.scss` load the upstream sheets before adding module-specific rules. Keep their cascade positions when moving imports.

Theme selectors are scoped, and the root-class hook only removes classes it owns. Preserve specialty themes, unrelated root modifiers, reduced-motion/forced-colors behavior, and pointer-transparent decorative layers when extending the system.

## Maintenance and verification

- To change per-image defaults, keep `TITLE_DEFAULT_*` in the DM defines and `DEFAULT_LOBBY_TITLE_*` in `TitleArtwork.tsx` aligned. Rotation's initial value lives on `SStitle`; the built-in master uses a null initial selection. Do not rewrite saved administrator choices when changing defaults.
- To add a base theme, update the frontend catalog, the backend preference's allowed IDs, the scoped theme styles and the lobby heading/layout mapping together. Retain old stored IDs or provide an explicit migration when renaming choices.
- To add a title appearance choice, update backend validation and manager options, frontend types/resolution and CSS together. Persistence migrations must preserve the meaning of existing records.
- Keep shared styling in the existing module files and use narrow registration/render/serialization hooks in core. Avoid copying complete upstream components or procedures to customize one value.

From `tgui/`, run the relevant frontend checks after implementation changes:

```sh
bun run tgui:tsc
bun test packages/tgui/constants/theme.test.ts packages/tgui/layouts packages/tgui/interfaces/common packages/tgui/interfaces/TitleScreenManager.test.tsx packages/tgui-lobby
bun run tgui:build
```

Backend coverage lives in [title_screen_settings.dm](../../../code/modules/unit_tests/~nova/title_screen_settings.dm) and [meridian_preferences.dm](../../../code/modules/unit_tests/~nova/meridian_preferences.dm). Use the repository's [DM build/test workflow](../../../tools/build/README.md) when changing backend behavior. The title tests isolate their settings file and publication state from the server's saved title configuration.

For visual changes, also check the live lobby and manager in BYOND: theme switching, both built-in masters, configured artwork, each bezel/scanline combination, narrow windows, keyboard focus, and a player joining while the title changes. Compilation and DOM tests alone do not verify WebView2 rendering.
