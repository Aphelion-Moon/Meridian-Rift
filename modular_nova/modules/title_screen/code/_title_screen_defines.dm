#ifndef MERIDIAN_TITLE_SCREEN_DEFINES
#define MERIDIAN_TITLE_SCREEN_DEFINES

#define DEFAULT_TITLE_MAP_LOADTIME (150 SECONDS)

#define DEFAULT_TITLE_SCREEN_IMAGE 'modular_nova/modules/title_screen/icons/meridian_rift_title_mask.png'
#define DEFAULT_TITLE_LOADING_SCREEN 'modular_nova/modules/title_screen/icons/loading_screen.png'

#define TITLE_PROGRESS_CACHE_FILE "data/progress_cache.json"
#define TITLE_PROGRESS_CACHE_VERSION "2"
/// Cap on how many boot terminal lines we keep/send - matches how many the client ever displayed.
#define MAX_STARTUP_MESSAGES 27

/// Base name for the lobby's background image asset. The title image changes over time
#define LOBBY_TITLE_ASSET_PREFIX "lobby_title_screen"
/// Asset name for the neutral Meridian Rift wordmark. Unlike the title screen this
/// never changes, so it registers once under a fixed name.
#define LOBBY_TITLE_MARK_ASSET_NAME "lobby_title_mark.png"

/// Server-wide, admin-chosen title screen presentation. Survives restarts.
#define TITLE_SETTINGS_FILE "data/title_screen_settings.json"
/**
 * 3: the per-screen bezel is a choice instead of a boolean. Version 2's
 * enabled bezel becomes Classic; disabled remains None.
 * 2: presentation moved from four server-wide values to a record per screen,
 * so one picture can wear the bezel while another stays flat. Version 1 files
 * are migrated on load by fanning the old globals out across every screen.
 */
#define TITLE_SETTINGS_VERSION "3"
#define TITLE_SETTINGS_VERSION_BOOLEAN_BEZEL "2"
#define TITLE_SETTINGS_VERSION_LEGACY "1"

/// Key used for the neutral Meridian Rift master, which has no config file name.
#define TITLE_DEFAULT_SCREEN_KEY "__default__"
/**
 * The same master wearing the alternate wordmark ramp. It is a separate entry
 * in the screen list rather than a checkbox on the first one, so picking it is
 * the same gesture as picking any other screen.
 */
#define TITLE_DEFAULT_ALT_SCREEN_KEY "__default_alt__"

/// How the lobby should render the current title screen.
/// Defensive fallback for unmanaged/operator-provided artwork; the manager does not expose it.
#define TITLE_TREATMENT_NONE "none"
/// The image is a neutral alpha master that TGUI tints with the active theme.
#define TITLE_TREATMENT_MASK "mask"
/// The image renders as-is with the themed wordmark composited over it.
#define TITLE_TREATMENT_OVERLAY "overlay"
/// The image sits inside the CRT glass with no wordmark over it.
#define TITLE_TREATMENT_SCREEN "screen"

/// Per-screen presentation defaults, applied to any screen with no record yet.
#define TITLE_DEFAULT_VARIANT "convex"
#define TITLE_DEFAULT_TEXTURE "scanlines-classic"
/// The monitor rim, independent of the screen effect since v2.
#define TITLE_BEZEL_NONE "none"
#define TITLE_BEZEL_CLASSIC "classic"
#define TITLE_BEZEL_RUSTY "rusty"
#define TITLE_BEZEL_RUSTY_DARK "rusty-dark"
#define TITLE_BEZEL_APHELION "aphelion"
#define TITLE_DEFAULT_BEZEL TITLE_BEZEL_RUSTY_DARK

/// Rank that may change the title screen, matching ADMIN_VERB(admin_change_title_screen).
#define TITLE_SCREEN_ADMIN_RIGHTS R_FUN

#endif // MERIDIAN_TITLE_SCREEN_DEFINES
