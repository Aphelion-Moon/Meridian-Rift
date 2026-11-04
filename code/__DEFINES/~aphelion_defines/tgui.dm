// APHELION MODULE - BUG_REPORTING - BYOND_POST_MESSAGE
// tgui messages, posted whole by every page that can (BYOND_POST_MESSAGE in code/modules/tgui/external.dm)
/// The biggest message an honest page sends is about 72 KB (a full bug report in three-byte letters, or one stroke over a whole 96x96 canvas), so 128 KB leaves it room
#define TGUI_MAX_PAYLOAD_BYTES (128 * 1024)
