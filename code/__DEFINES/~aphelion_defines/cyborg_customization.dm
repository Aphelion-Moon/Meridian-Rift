/// Versioned, bounded cyborg-layout storage contract shared by preferences and renderers.
#define CYBORG_LAYOUT_SCHEMA_VERSION 1
#define CYBORG_LAYOUT_MAX_PRESETS 10
#define CYBORG_LAYOUT_MAX_PRESET_NAME_LENGTH 24
/// Saved model defaults per character slot, which keeps a slot's decoded tree small however compact its text is.
#define CYBORG_LAYOUT_MAX_MODEL_DEFAULTS 30
/// One character slot's save text: its active layout, presets and model defaults together. A hundred of these fit
/// the account limit below.
#define CYBORG_LAYOUT_MAX_SLOT_BYTES (32 * 1024)
/// The account's whole cyborg_customization.json, a backstop the slot limit keeps it under. Bigger files are neither
/// written nor read.
#define CYBORG_LAYOUT_MAX_SIDECAR_BYTES (4 * 1024 * 1024)
/// Preview identifiers include model type paths and skin names from the server catalog.
#define CYBORG_PREVIEW_MAX_IDENTIFIER_LENGTH 256
#define CYBORG_LAYOUT_MIN_PIXEL_OFFSET -128
#define CYBORG_LAYOUT_MAX_PIXEL_OFFSET 128
#define CYBORG_LAYOUT_MIN_ROTATION -180
#define CYBORG_LAYOUT_MAX_ROTATION 180
#define CYBORG_LAYOUT_MIN_SCALE 0.25
#define CYBORG_LAYOUT_MAX_SCALE 2
#define CYBORG_LAYOUT_MIN_SPRITE_SIZE 1
#define CYBORG_LAYOUT_MAX_SPRITE_SIZE 16
#define CYBORG_LAYOUT_MIN_PRIORITY 1
#define CYBORG_LAYOUT_MAX_PRIORITY 10
