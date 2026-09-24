/// Most colors one drawing's palette may hold.
#define CUSTOM_SPRITE_MAX_COLORS 63
/// Most colors in an account's Custom palette.
#define CUSTOM_SPRITE_MAX_CUSTOM_COLORS 16
/// Palette index characters. The first one is transparent, so palette index N is character N + 1.
#define CUSTOM_SPRITE_INDEX_ALPHABET "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"
/// Width of wide drawings, which extend equally past both sides of the body's 32-pixel canvas.
#define CUSTOM_SPRITE_TAUR_WIDTH 64
/// Marking zone for the taur lower body.
#define CUSTOM_MARKING_ZONE_TAUR "taur"
/// Size limit of an account's drawing sidecar.
#define CUSTOM_SPRITE_MAX_SIDECAR_BYTES (16 * 1024 * 1024)
/// Size limit of an imported style file.
#define CUSTOM_STYLE_MAX_BYTES 16384
/// Size limit of an imported whole-body style file, which carries up to one drawing per region.
#define CUSTOM_STYLE_MAX_BODY_BYTES 163840
