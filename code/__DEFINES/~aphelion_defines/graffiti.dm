/// Most layers one graffiti piece holds.
#define GRAFFITI_MAX_LAYERS 4
/// Longest layer name, in characters.
#define GRAFFITI_MAX_LAYER_NAME 20
/// Longest piece name, in characters.
#define GRAFFITI_MAX_NAME 32
/// Longest piece description, in characters.
#define GRAFFITI_MAX_DESCRIPTION 200
/// Width of a piece that covers one tile.
#define GRAFFITI_WIDTH 32
/// Width of a piece that covers two tiles side by side.
#define GRAFFITI_WIDE_WIDTH 64
/// Height of every piece.
#define GRAFFITI_HEIGHT 32
/// Most colours one piece's palette may hold: as many as one grid character can index.
#define GRAFFITI_MAX_COLORS 63
/// The most alpha placed graffiti is drawn with, 80%, so the surface shows through: a colour this opaque or more is
/// stored opaque, and opaque paint is drawn at it.
#define GRAFFITI_ALPHA_CEILING 204
/// Most pieces an account's library keeps, besides its Unfinished slot.
#define GRAFFITI_LIBRARY_CAP 50
/// Most pieces stacked on one tile. A new one buries the oldest.
#define GRAFFITI_STACK_CAP 5
/// Spraycan charges a finished piece costs, halved for taggers.
#define GRAFFITI_COST 5
/// How many ms of composites may build up for a burst.
#define GRAFFITI_COMPOSITE_SHARE_BURST 100
/// Width of the column strip one paint job step reveals, in pixels.
#define GRAFFITI_REVEAL_STRIP 4
/// Rounds in a row a placement may miss its surface: the last of them drops it.
#define GRAFFITI_MISS_LIMIT 20
/// Size limit of one exported or imported piece.
#define GRAFFITI_PIECE_MAX_BYTES 32768
/// A player's library write waits this many times as long as the account's last write took, and at least a second, so
/// one account's writes take at most a twentieth of the server's time: 50 adversarial pieces take 139 ms to write on
/// average and 209 ms at most (measured), 14-21% of the time at one write a second.
#define GRAFFITI_LIBRARY_WRITE_PACE 20
/// Size limit of a map's graffiti file.
#define GRAFFITI_MAP_MAX_BYTES (16 * 1024 * 1024)
/// Where each map's graffiti file lives.
#define GRAFFITI_MAP_DIRECTORY "data/graffiti/maps/"
/// Where each map's sprite sheet files live, in a directory per map.
#define GRAFFITI_SHEET_DIRECTORY "data/graffiti/sheets/"
/// Where each account's library file lives.
#define GRAFFITI_LIBRARY_DIRECTORY "data/graffiti/library/"
/// Most unique arts one map file keeps: 2,000 dense art records of 3,670 bytes take 7.3 MB, as measured, and a sparse
/// one takes 680 bytes.
#define GRAFFITI_MAP_UNIQUE_CAP 2000
/// Most placements one map file keeps: 4,000 placements packed as JSON strings take about 1.2 MB (measured on a full
/// map), and their decals at 2,261 bytes each 9 MB at worst. With the arts (at most about 5.4 MB under
/// GRAFFITI_MAP_ART_BYTES) and the GRAFFITI_ICON_CACHE caches (1.5 MB) that is about 17 MB at worst, besides the
/// placement indexes (not measured), since sheet files keep every other icon at 0 bytes of server memory; a load adds
/// GRAFFITI_DECODE_BUDGET while it runs.
#define GRAFFITI_MAP_PLACEMENT_CAP 4000
/// Most bytes of art one map keeps, counting each unique art's `pal`, `grid` and `glow` text: about 1,500 dense
/// one-tile arts, or 400 translucent ones of 1,000 colours at 12-14 KB a tile, while typical art meets
/// GRAFFITI_MAP_UNIQUE_CAP first. The owner's ruling (2026-10-20) halved it from 10 MiB, which takes the worst case at
/// the caps from about 22.5 to 17 MB; 10 MiB of art and 4,000 placements wrote about 13.5 MB, so 5 MiB writes about
/// 8 MB. Both new figures are worked out from the measured ones at 10 MiB.
#define GRAFFITI_MAP_ART_BYTES (5 * 1024 * 1024)
/// Most unique arts shown in one round: everything within the map caps. Ranking still orders evictions and loading,
/// and SSgraffiti's display_budget, which starts at this, lets tests lower it.
#define GRAFFITI_DISPLAY_BUDGET GRAFFITI_MAP_UNIQUE_CAP
/// Most placements one account keeps on one map: a tenth of GRAFFITI_MAP_PLACEMENT_CAP.
#define GRAFFITI_CKEY_PLACEMENT_CAP 400
/// The `format` every piece file carries. A file with any other is refused.
#define GRAFFITI_FORMAT "aphelion-graffiti"
/// The piece file version this server writes and accepts.
#define GRAFFITI_FORMAT_VERSION 1
/// The map file version this server writes: anchors record their `surface`, and placements carry no name or description.
#define GRAFFITI_MAP_VERSION 2
/// Anchor kind of a placement on a fixed station tile.
#define GRAFFITI_ANCHOR_STATION "station"
/// Anchor kind of a placement in reserved space, such as a condo.
#define GRAFFITI_ANCHOR_RESERVED "reserved"
/// graffiti_surface_kind() of a wall. Anchors keep the kind as their `surface`, and decals as their `kind`.
#define GRAFFITI_KIND_WALL "wall"
/// graffiti_surface_kind() of a floor with ground.
#define GRAFFITI_KIND_FLOOR "floor"
/// graffiti_surface_kind() of a tile under a full-tile window fastened down, whose graffiti is on the glass.
#define GRAFFITI_KIND_WINDOW "window"
/// Placements per page of the admin panel.
#define GRAFFITI_ADMIN_PAGE 24
/// graffiti_art_glow_kind() of an art with no glowing paint.
#define GRAFFITI_GLOW_NONE 0
/// graffiti_art_glow_kind() of an art whose paint all glows.
#define GRAFFITI_GLOW_ALL 1
/// graffiti_art_glow_kind() of an art with both glowing and unlit paint.
#define GRAFFITI_GLOW_MIXED 2
/// A placement's ckey, in its SSgraffiti.placement_info entry.
#define GRAFFITI_INFO_CKEY 1
/// A placement's art hash, in its SSgraffiti.placement_info entry.
#define GRAFFITI_INFO_ART 2
/// When a placement was placed, in its SSgraffiti.placement_info entry: ten-digit unix seconds in text.
#define GRAFFITI_INFO_AT 3
/// A placement's id, in its SSgraffiti.placement_info entry.
#define GRAFFITI_INFO_PID 4
/// A placement's painter's character name, in its SSgraffiti.placement_info entry.
#define GRAFFITI_INFO_WHO 5
/// Whether a placement lasts this round only, in its SSgraffiti.placement_info entry.
#define GRAFFITI_INFO_ROUND_ONLY 6
