/// Version of the layout tree's shape. A slot saved by a newer one is kept as it is and never edited
#define CYBORG_LAYOUT_SCHEMA_VERSION 1
/// The most presets one character slot can save
#define CYBORG_LAYOUT_MAX_PRESETS 10
/// The longest preset name, in characters
#define CYBORG_LAYOUT_MAX_PRESET_NAME_LENGTH 24
/// Saved model defaults per character slot, which keeps a slot's decoded tree small however compact its text is
#define CYBORG_LAYOUT_MAX_MODEL_DEFAULTS 30
/// One character slot's save text - its active layout, presets and model defaults together. Any single layout fits
#define CYBORG_LAYOUT_MAX_SLOT_BYTES (32 * 1024)
/// The account's whole cyborg_customization.json, shared by all its characters. A character that would pass it isn't saved, and a bigger file is neither written nor read
#define CYBORG_LAYOUT_MAX_SIDECAR_BYTES (1024 * 1024)
/// The shortest time between two writes of one account's cyborg layouts. Saves asked for sooner wait, and write the latest state
#define CYBORG_LAYOUT_SAVE_SPACING (2 SECONDS)
/// The longest preview identifier the editor takes - they hold model type paths and skin names from the server catalog
#define CYBORG_PREVIEW_MAX_IDENTIFIER_LENGTH 256
/// The lowest pixel offset a part can have on either axis
#define CYBORG_LAYOUT_MIN_PIXEL_OFFSET -128
/// The highest pixel offset a part can have on either axis
#define CYBORG_LAYOUT_MAX_PIXEL_OFFSET 128
/// The smallest sprite size a part can pick
#define CYBORG_LAYOUT_MIN_SPRITE_SIZE 1
/// The largest sprite size a part can pick
#define CYBORG_LAYOUT_MAX_SPRITE_SIZE 16
