/// How much of a pixel a role's run covers, out of 255 (dirt_role_runs()). Haze is film at half.
#define DIRT_MASK_SOLID 255
#define DIRT_MASK_HALF 128
/// How many of a wag frame's pixels one piece of a mask job carries from the still tail (/datum/dirt_tail_carry). The
/// first piece also works out the frame's coordinates. A piece takes up to 16.8 ms on the widest tails shipped, about
/// 130 us a pixel.
#define DIRT_CARRY_PIXELS 128

/**
 * One mark on a carrier, at a level: a variant of a zone's mess, or a general deposit (a variant of a cause's dirt in a
 * material). More shots on the zone raise a mess splat's level. Past the top level, another splat starts.
 */
/datum/dirt_splat
	/// A mess splat's DIRT_ZONE_* define, or null for a general deposit.
	var/zone
	/// 1 to DIRT_MESS_MAX_LEVEL for mess. For a general deposit, 1 to its cause's top level.
	var/level
	/// 0 to DIRT_VARIANTS - 1.
	var/variant
	/// When it first landed, from SSdirt.next_serial(). Where a surface's mess and general deposits merge, they merge
	/// in this order (cmp_dirt_splats_landed()).
	var/serial
	/// When it last landed or was raised, from SSdirt.next_serial(). Past a cap, the splat with the lowest goes first.
	var/last_serial
	/// A general deposit's DIRT_CAUSE_* define, or null for mess, whose cause is "aimed_<zone>".
	var/cause
	/// What it's made of: a DIRT_MATERIAL_* define, or "slime#RRGGBB" for slime (dirt_material()).
	var/material = DIRT_MATERIAL_MESS
	/// The limbs a general deposit covers, DIRT_LIMB_BIT() of each. Its masks keep to them (dirt_pixels_from_drawn()).
	/// 0 for mess. On a general deposit, 0 means every limb.
	var/limbs = 0

/**
 * Arguments:
 * - zone: A DIRT_ZONE_* define for mess, or null.
 * - level: Its level.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - serial: From SSdirt.next_serial(), as it lands.
 * - cause: A general deposit's DIRT_CAUSE_* define, or null for mess.
 * - material: What it's made of, as /datum/dirt_splat/var/material.
 * - limbs: The limbs a general deposit covers, DIRT_LIMB_BIT() of each.
 */
/datum/dirt_splat/New(zone, level, variant, serial, cause = null, material = DIRT_MATERIAL_MESS, limbs = 0)
	. = ..()
	src.zone = zone
	src.level = level
	src.variant = variant
	src.serial = serial
	last_serial = serial
	// set only where they differ from mess's, so a mess splat stores no extra vars
	if(cause)
		src.cause = cause
	if(material != DIRT_MATERIAL_MESS)
		src.material = material
	if(limbs)
		src.limbs = limbs

/**
 * Returns each splat's material in order (/datum/dirt_splat/var/material), as dirt_merge() takes them, or null when
 * every one is mess.
 *
 * Arguments:
 * - splats: The splats.
 */
/proc/dirt_splat_materials(list/splats)
	RETURN_TYPE(/list)
	for(var/datum/dirt_splat/splat as anything in splats)
		if(splat.material == DIRT_MATERIAL_MESS)
			continue
		var/list/materials = list()
		for(var/datum/dirt_splat/each_splat as anything in splats)
			materials += each_splat.material
		return materials
	return null

/**
 * Returns whether some splats hold a general deposit. A general deposit draws on a body's dirtier side, and on a bare
 * body it draws its painted designs.
 *
 * Arguments:
 * - splats: The splats, or null.
 */
/proc/dirt_holds_deposits(list/splats)
	for(var/datum/dirt_splat/splat as anything in splats)
		if(splat.cause)
			return TRUE
	return FALSE

/**
 * What a surface's masks are made from: the body they're drawn on and the splats on it. Requests with the same
 * mask_key() share their masks, so bodies drawn from the same sprites with the same splats draw the same icons. A
 * request is made once and never changed: it keeps copies of the splats, so a splat that levels up or lands while its
 * masks wait in the queue changes neither the key nor what's drawn under it.
 */
/datum/dirt_mask_request
	/// What it's drawn on: DIRT_MASKS_BODY, DIRT_MASKS_PART, DIRT_MASKS_TAUR, DIRT_MASKS_SHAPE or DIRT_MASKS_HAIR, or
	/// DIRT_MASKS_WET for sweat's multiplier (/datum/dirt_mask_request/wet).
	var/kind
	/// The body's sprites, as dirt_zone_sources() returns them: its template's. On a taur, the rider's.
	var/list/zone_sources
	/// The key of the template its zone sources build (dirt_template_key()), or null without zone sources. It's worked
	/// out once, for the masks' key and for finding the template.
	var/template_key
	/// DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH, or DIRT_SURFACE_FUR for a drawn part, DIRT_SURFACE_HAIR for the hair.
	/// On skin, a taur body's dirt is drawn per layer, on the taur body's own images. On cloth it's drawn over the
	/// whole canvas, inset on a taur suit.
	var/surface_kind
	/// Copies of the surface's /datum/dirt_splat as they were when it was made, oldest first. They merge in this order.
	var/list/splats
	/// The parts the splats reach, each a /datum/dirt_part_source, lowest first. They drop the mess's level below the
	/// top one, which keeps its glaze, and it leaves out the rounded ones' pixels; in each direction a part drawn under
	/// the surface (/datum/dirt_part_source/proc/under()) has its own mess drawn in these masks, and one drawn
	/// over it on itself.
	var/list/parts
	/// The layer of the surface the masks are drawn on, which the parts are drawn under or over.
	var/surface_layer
	/// For a part's masks, the part they're drawn on: their mess keeps to its pixels.
	var/datum/dirt_part_source/part_source
	/// For a part's masks, the directions it draws its share in, where it shows over what it lies on;
	/// null for all four.
	var/list/facings
	/// For a taur body's, a drawn part's or the hair's dirt, the shape it's drawn on.
	var/datum/dirt_shape_source/shape_source
	/// For skin, the sprites worn over it, from dirt_cover_sprites(): its mess fades out beside them.
	var/list/cover
	/// For cloth on underclothes, the sprites its mess is kept to, each list(icon, icon state)...
	var/list/clip
	/// ...less the pixels of these, drawn over them.
	var/list/cut
	/// The body's dirtier side, 1 or -1, which general deposits draw on.
	var/side = 1
	/// Whether the body is bare, so general deposits on its skin draw their painted designs. Only ever TRUE where they're
	/// rasterised on skin.
	var/painted = FALSE
	/// What general deposits are rasterised on, where that isn't surface_kind: DIRT_SURFACE_SKIN for underwear, which
	/// takes the skin's general dirt and takes mess as cloth. Null when they're rasterised on surface_kind.
	var/deposit_surface
	/// For skin holding general deposits, the parts drawn over it in some direction, lowest first (dirt_parts_over()).
	/// Each draws the deposits on its own pixels there (/datum/dirt_mask_job/proc/deposit_part_runs()). Null if none.
	var/list/deposit_parts
	/// For blood below a taur's waist, what it's drawn from (dirt_taur_blood_data()): on skin, the taur body's share,
	/// and on cloth, a taur-fitted garment's. Null for other masks.
	var/list/blood
	/// For a taur body's own dirt, the row of the rider's surface that each canvas row shows at the rider's height
	/// (dirt_height_rows()). The rider stretches and the taur body stays put. Null at a height that stretches nothing.
	var/list/rows

/**
 * Arguments:
 * - kind: DIRT_MASKS_BODY, DIRT_MASKS_PART, DIRT_MASKS_TAUR, DIRT_MASKS_SHAPE or DIRT_MASKS_HAIR.
 * - zone_sources: The body's sprites, as dirt_zone_sources() returns them. A part's masks need them only for the vulva
 *   on skin, which takes the ring of the body round it.
 * - surface_kind: DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH, or DIRT_SURFACE_FUR for a drawn part. For a part, what it
 *   lies on.
 * - splats: The surface's /datum/dirt_splat, oldest first. Copied: the request never reads them again.
 * - parts: The parts the splats reach, lowest first, from dirt_surface_parts(), or null.
 * - part_source: For a part's masks, the part.
 * - shape_source: For a taur body's, a drawn part's or the hair's dirt, the shape.
 * - cover: The sprites worn over skin, from dirt_cover_sprites(), or null.
 * - clip: The sprites cloth's mess is kept to, each list(icon, icon state), or null for the whole canvas.
 * - cut: The sprites drawn over `clip`'s, in the same form, or null.
 * - surface_layer: The surface's layer: a garment's, DIRT_UNDERCLOTHES_LAYER or DIRT_SKIN_LAYER.
 * - facings: For a part's masks, the directions it draws its share in, or null for all four.
 * - side: The body's dirtier side, 1 or -1.
 * - painted: Whether the body is bare. Kept only where general deposits are rasterised on skin, the one surface
 *   painted designs draw on.
 * - deposit_surface: What general deposits are rasterised on: DIRT_SURFACE_SKIN for underwear, or null to use
 *   surface_kind.
 * - deposit_parts: For skin holding general deposits, the parts drawn over it in some direction (dirt_parts_over()),
 *   or null.
 * - blood: For blood below a taur's waist, from dirt_taur_blood_data(), or null.
 * - rows: For a taur body's own dirt, the rows its rider shows at its height (dirt_height_rows()), or null.
 */
/datum/dirt_mask_request/New(kind, list/zone_sources, surface_kind, list/splats, list/parts, datum/dirt_part_source/part_source, datum/dirt_shape_source/shape_source, list/cover, list/clip, list/cut, surface_layer, list/facings, side = 1, painted = FALSE, deposit_surface = null, list/deposit_parts = null, list/blood = null, list/rows = null)
	. = ..()
	src.kind = kind
	src.zone_sources = zone_sources
	if(zone_sources)
		template_key = dirt_template_key(zone_sources)
	src.surface_kind = surface_kind
	src.splats = list()
	for(var/datum/dirt_splat/splat as anything in splats)
		src.splats += new /datum/dirt_splat(splat.zone, splat.level, splat.variant, splat.serial, splat.cause, splat.material, splat.limbs)
	if(side != 1)
		src.side = side
	if(deposit_surface && deposit_surface != surface_kind)
		src.deposit_surface = deposit_surface
	if(painted && (src.deposit_surface || surface_kind) == DIRT_SURFACE_SKIN)
		src.painted = TRUE
	src.parts = parts || list()
	src.surface_layer = surface_layer
	src.part_source = part_source
	src.facings = facings
	src.shape_source = shape_source
	src.cover = cover
	src.clip = clip
	src.cut = cut
	if(length(deposit_parts))
		src.deposit_parts = deposit_parts
	if(blood)
		src.blood = blood
	if(rows)
		src.rows = rows

/**
 * Returns the masks' key: an MD5 of what they're drawn on and each splat's zone, level and variant, in order. A general
 * deposit gives its cause, material, level, variant and limbs, so two materials never share masks. Where general
 * deposits draw, the key adds the body's side, whether it's bare and what the deposits are rasterised on. It adds the
 * sprites that fade or keep the masks, and the parts that shape them, each with where it draws against the surface in
 * each direction. For masks drawn on a part or a shape, it adds that part or shape and the directions it draws in. It
 * adds the parts that take the surface's general deposits too. Serials stay out of it, so splats that landed apart
 * draw alike. A part's splats count at the level they draw at. A taur body's count at their own level, because the
 * rider's mess that its pools keep clear of is drawn at that level. A taur body's key adds the rows its rider shows at
 * a height that stretches the rider.
 */
/datum/dirt_mask_request/proc/mask_key()
	var/list/key_parts = list(kind, template_key || "", surface_kind)
	var/general = FALSE
	for(var/datum/dirt_splat/splat as anything in splats)
		if(splat.cause)
			key_parts += "[splat.cause]:[splat.material]:[splat.level]:[splat.variant]:[splat.limbs]"
			general = TRUE
			continue
		key_parts += "[splat.zone]:[kind == DIRT_MASKS_PART ? min(splat.level, DIRT_PART_MAX_LEVEL) : splat.level]:[splat.variant]"
	// only when there are any, so mess's masks keep their keys
	if(general)
		key_parts += "side:[side]|painted:[painted][deposit_surface ? "|on:[deposit_surface]" : ""]"
	// only when there are any, so masks without them keep their keys
	if(length(cover))
		key_parts += "cover:[dirt_sprites_key(cover)]"
	if(length(clip))
		key_parts += "clip:[dirt_sprites_key(clip)]|cut:[dirt_sprites_key(cut)]"
	if(length(parts))
		key_parts += "parts:[dirt_parts_key(parts, surface_layer)]"
	if(part_source)
		key_parts += "part:[part_source.part_key()]"
	// a taur body's goes under "taur:", its shape's kind
	if(shape_source)
		key_parts += "[shape_source.kind]:[shape_source.shape_key()]"
	if(facings)
		key_parts += "facing:[jointext(facings, ",")]"
	// only when there are any, so masks without them keep their keys
	if(deposit_parts)
		key_parts += "deposit parts:[dirt_parts_key(deposit_parts, surface_layer)]"
	if(blood)
		key_parts += "blood:[dirt_taur_blood_key(blood)]"
	// only when the rider stretches, so an Average rider's masks keep their keys
	if(rows)
		key_parts += "rows:[jointext(rows, ",")]"
	return md5(jointext(key_parts, "|"))

/// Returns every part the request reads: the parts its splats reach, or the part its masks are drawn on.
/datum/dirt_mask_request/proc/read_parts()
	RETURN_TYPE(/list)
	return part_source ? list(part_source) : parts

/**
 * Returns the sprites a request reads besides its template, each list(icon, icon state, what for, shift). What for is
 * "cover", "clip" or "cut". Shift is where a cover sprite's wrapper has the body's tile (dirt_cover_sprites()), or
 * null.
 */
/datum/dirt_mask_request/proc/read_sprites()
	RETURN_TYPE(/list)
	. = list()
	for(var/purpose, purpose_sprites in list("cover" = cover, "clip" = clip, "cut" = cut))
		for(var/list/sprite as anything in purpose_sprites)
			. += list(list(sprite[1], sprite[2], purpose, length(sprite) > 2 ? sprite[3] : null))

/**
 * A surface's masks: its mess baked into four-direction RGBA icons (dirt_baked_icon()), registered in the resource
 * cache, each drawn as it is (dirt_mess_baked_image()).
 */
/datum/dirt_masks
	/// The request's mask_key().
	var/key
	/// For skin: alist(limb zone = baked icon), each limb's clipped to the pixels its image shows.
	var/alist/baked_by_limb = alist()
	/// For skin: alist(limb zone = an MD5 of what its baked icon draws, dirt_runs_key()), so only a limb whose pixels
	/// changed caches new images.
	var/alist/limb_keys = alist()
	/// For skin: alist(a part's /datum/dirt_part_source/proc/placed_key() against the skin = baked icon). Each icon
	/// holds the skin's general deposits on a part drawn over the skin that they reach. They lie on the part's own
	/// pixels, in the directions it draws over the skin (/datum/dirt_mask_job/proc/deposit_part_runs()). They're drawn
	/// under the part's own mess in its container (dirt_container_over()). Null if there are none.
	var/alist/baked_by_part
	/// For skin: alist(the same key = an MD5 of what its baked icon draws, dirt_runs_key()), for the part's render key.
	/// Null if there are none.
	var/alist/part_keys
	/// For cloth: the baked icon on the whole canvas, which the garment's own pixels clip. For a part, the same, already
	/// kept to the part's pixels. Null when it draws nothing.
	var/baked
	/// For a taur body's or a drawn part's dirt: alist(EXTERNAL_* layer = baked icon), each on its canvas, kept to the
	/// pixels that layer shows (dirt_taur_owners()). A taur suit draws its own from `baked`, over the whole canvas. So
	/// does the hair, kept to its pixels less its darkest strands (dirt_hair_dirt()). Hair with pieces drawn over hats
	/// draws from here instead, under DIRT_CARRIER_HAIR and DIRT_HAIR_OUTER.
	var/alist/baked_by_layer = alist()
	/// For cloth holding sweat, its wet pixels, which a garment's multiplier is made from (dirt_wet_drawn()). Null
	/// without sweat. For sweat's multiplier itself (DIRT_MASKS_WET) it's null too, and `baked` is the multiplier.
	var/alist/wet

/**
 * Arguments:
 * - key: The request's mask_key().
 */
/datum/dirt_masks/New(key)
	. = ..()
	src.key = key

/**
 * Makes a request's masks a piece at a time (next_piece()). While it waits, SSdirt.mask_jobs holds it under its key,
 * so a body asking meanwhile waits for it (wait()) rather than queueing it again.
 */
/datum/dirt_mask_job
	parent_type = /datum/dirt_job
	/// What it makes.
	var/datum/dirt_mask_request/request
	/// The request's mask_key().
	var/key
	/// Where its template comes from, from SSdirt.template_for(): the template, the job building it, or FALSE. Null for
	/// a part's masks that need none.
	var/template_source
	/// The template, once its turn comes.
	var/datum/dirt_template/template
	/// Whether its first piece has found its template and set it up.
	var/started = FALSE
	/// The request's read_parts().
	var/list/parts
	/// The next part to read.
	var/next_part = 1
	/// alist(direction = alist(/datum/dirt_part_source = its pixels there, from dirt_part_own())).
	var/alist/part_owns = alist()
	/// Each splat's rasters in the request's order, each alist(direction = /datum/dirt_pixels/proc/drawn() of it). For
	/// a part, alist(direction = /datum/dirt_pixels).
	var/list/splat_rasters
	/// The request's splats' materials, from dirt_splat_materials(), which every merge takes. Null when all are mess.
	var/list/splat_materials
	/// The next splat to rasterise.
	var/next_splat = 1
	/// alist(direction = /datum/dirt_pixels): each direction's splats merged. For a wag, they're merged on its still
	/// sprite.
	var/alist/merged = alist()
	/// What it made.
	var/datum/dirt_masks/masks
	/// Weak references to the bodies that drew without the masks while this waited -> DIRT_REDRAW_* flags.
	var/list/waiters
	/// The request's read_sprites(), read one a piece.
	var/list/sprites
	/// The next sprite to read.
	var/next_sprite = 1
	/// What the sprites read cover:
	/// alist("cover", "clip" or "cut" = alist(direction = list of TRUE or null per pixel)).
	var/alist/sprite_pixels = alist()
	/// For a taur body's or a drawn part's dirt: alist(direction = what each pixel of its canvas shows, from
	/// dirt_taur_owners()). For a wag, it's the still sprite's, which every frame's dirt is carried from. A taur body's
	/// own dirt reads its rider here at Average height, whatever the rider's own height is. So that dirt is made as if
	/// the rider were Average height. Blood below the waist reads the rider at its height (dirt_blood_carriers()).
	var/alist/taur_owners = alist()
	/// For a taur body's own dirt at a height that stretches its rider (/datum/dirt_mask_request/var/rows): taur_owners
	/// with the rider stretched. The merge is carried onto the pixels the rider uncovers (dirt_taur_height_fill()), and
	/// each layer shows the pixels these give it (layers_shown()). Null otherwise.
	var/alist/height_owners
	/// The sprite directions its parts or shape are read from, each list(sheet, state, direction, width, height), from
	/// wanted_reads().
	var/list/wanted_sprites
	/// The next of them to look for in SSdirt.sprite_reads.
	var/next_read = 1
	/// For sweat's multiplier: alist(direction = dirt_wet_factors()), for each direction made so far.
	var/alist/wet_factors
	/// For skin: alist(part's placed_key() = runs) of the parts that take its general deposits. limb_runs() fills it,
	/// and limb_masks() reads it.
	var/alist/part_runs
	/// The masks that the drawing which queued this job draws until this job's are made, or null. limb_masks() takes
	/// their icon for each limb and part whose runs are the same. Dropped at the end of limb_masks(), or with the job.
	var/datum/dirt_masks/previous
	/// alist(field key = /datum/dirt_canvas_field), the fields of the deposit being made. For a taur body's, a drawn
	/// part's or the hair's dirt, they're its canvas fields, and its douses and taur coats in each direction. For
	/// a body's, they're its plunge, blast or douse in each direction (/datum/dirt_canvas_field/body). Each is made
	/// once (field_for()), and they're dropped once the deposit is made in every direction.
	var/alist/canvas_fields
	/// alist(field key without its facing = /datum/dirt_canvas_field/var/samples): the noise of the deposit being made.
	/// Its fields share one table in every direction (field_for()), and it's dropped with them. The fields are all of
	/// one type, which the cause and the request pick. Each noise term samples a point and seed given by its position
	/// and the deposit's random draws, whichever way the field faces. The position is a pixel's index, or the one
	/// coordinate the term takes, and the canvas or template surface is the same size every way. So a value that one
	/// direction kept is what sampling it again returns.
	var/alist/field_samples
	/// alist(level = its features, from dirt_cause_features()) of the general deposit being made on a body's template.
	/// The first direction to ask makes them, and the others get them unbound (dirt_level_features()). They're dropped
	/// with the deposit's fields. It holds one deposit's levels and their last binding, while it's drawn.
	var/alist/deposit_features
	/// alist(seed = alist(scale = alist(sample_y = alist(sample_x = value)))): the noise deposit_features have sampled
	/// in the deposit's levels and directions (/datum/dirt_feature/proc/noise()), each value under its exact arguments.
	/// It's handed out and dropped with the features. It holds one deposit's noise, while it's drawn.
	var/alist/deposit_samples
	/// The draft's noise lattice that the general deposit being made has sampled in its directions so far
	/// (dirt_drafted()). The job holds it while none of the deposit's fields does. A field takes it at its first band
	/// and gives it back once done, and a direction drawn whole goes on from it. It's dropped once the deposit is made
	/// in every direction, so it holds one deposit's points, DIRT_LATTICE_POINTS at most. Each direction and band reads
	/// the points the others hashed, which are what hashing them again gives.
	var/alist/lattice
	/// How many points `lattice` holds.
	var/lattice_points = 0
	/// For a wag (/datum/dirt_wag_source): the frame being made, from 1. Past the last, its icons are put together.
	var/frame = 0
	/// For a wag, the frame being made's match in each direction (frame_owners()): alist(direction = 0 if it draws the
	/// still sprite's pixels there, or an earlier frame that draws the same pixels, or null).
	var/alist/frame_from
	/// For a wag: alist(direction = alist(MD5 of the pixels a frame shows = that frame, 0 for the still sprite)).
	var/alist/frame_keys
	/// For a wag: alist(EXTERNAL_* layer key = its animated icon so far), for each layer with dirt (bake_frame()).
	var/alist/frame_icons
	/// For a wag: alist(state = its sprite, with every frame). Each is loaded in a piece of its own before its frames
	/// are read (dirt_frame_owners()).
	var/alist/frame_sheets
	/// For a wag: alist(direction = what each pixel of its canvas shows at the frame being made, frame_owners()). For a
	/// kept wag (sprite_frames_kept), it's an empty list where an earlier frame shows the same.
	var/alist/frame_shown
	/// For a wag: alist(direction = the dirt of the frame being made, carried from the still's, carry_frame()). A
	/// direction is null while its dirt is being carried.
	var/alist/frame_merged
	/// For a wag: alist(direction = dirt_tail_coordinates() of its still sprite), each made at its first carry.
	var/alist/still_coordinates
	/// For a wag: the carry being made, a piece at a time (carry_frame()), or null.
	var/datum/dirt_tail_carry/frame_carry
	/// For a wag: alist(direction = list(its still sprite's pixels packed (dirt_wag_pack()), then each frame's entry)).
	/// A frame's entry is 0 if it shows the still's pixels, or the number of an earlier frame showing the same, or else
	/// its pixels packed with its carry. It's the same whatever the dirt. It comes from SSdirt.wag_sprites if that
	/// holds the wag's sprites. Otherwise it's noted as each frame is read and carried, and finished() keeps it there.
	var/alist/sprite_frames
	/// For a wag: whether sprite_frames came from SSdirt.wag_sprites, so the job reads no sprite and carries by them.
	var/sprite_frames_kept = FALSE
	/// For blood below a taur's waist: alist(direction = dirt_blood_carriers() there), each read with its owners.
	var/alist/blood_carriers

/**
 * Arguments:
 * - request: What it makes.
 * - key: The request's mask_key().
 */
/datum/dirt_mask_job/New(datum/dirt_mask_request/request, key)
	. = ..()
	src.request = request
	src.key = key

/// Returns the most pieces the job can take. A body's or a part's masks take a piece for each sprite direction of its
/// parts or shape that it reads, then a piece for each part read, and four rasters for each splat. A plunge, a blast or
/// a douse takes a band a piece instead, as a canvas field on the tile does (dirt_field_pieces()). Then come a piece
/// that finds only cached splats left, four merges, a piece for each sprite read, and the icons. A taur body's or a
/// drawn part's masks take their reads, then four canvas reads and up to three pieces for each splat in each direction.
/// For mess those are the rider's mess on cloth and on skin, then the pools. Then come a piece that finds only cached
/// splats left, four merges and the icons. The hair's masks take the same. At a height that stretches a taur body's
/// rider, its masks read the canvas again with the rider stretched, in four more pieces. A wag takes a piece for each
/// state of its sprite loaded, and its still sprite's dirt takes the same pieces as above, once. Then each frame takes
/// four reads, four carries and a bake, and its icons come last. A carry takes a piece for each DIRT_CARRY_PIXELS of
/// its canvas at most. Each deposit's canvas fields, douses or taur coats take a band a piece
/// (dirt_field_pieces()). Sweat's multiplier takes a piece for each direction, and one for the icon.
/datum/dirt_mask_job/most_pieces()
	if(request.kind == DIRT_MASKS_WET)
		return length(dirt_mask_directions()) + 1
	var/reads = length(wanted_sprites || wanted_reads())
	if(request.kind == DIRT_MASKS_TAUR || request.kind == DIRT_MASKS_SHAPE || request.kind == DIRT_MASKS_HAIR)
		var/datum/dirt_wag_source/wag = request.shape_source
		var/frames = istype(wag) ? wag.frames + 1 : 1
		var/loads = istype(wag) ? length(wag.state_frames) : 0
		var/carries = 0
		if(istype(wag))
			var/list/size = dirt_canvases()[wag.canvas]
			carries = 4 * ceil(size[1] * size[2] / DIRT_CARRY_PIXELS) * wag.frames
		// blood below a taur's waist takes a piece a direction, for every stain at once
		return reads + loads + (12 * length(request.splats) + 10) * frames + dirt_field_pieces(request.shape_source.canvas) * length(request.splats) + carries + (request.blood ? 4 : 0) + (request.rows ? 4 : 0)
	var/fields = 0
	for(var/datum/dirt_splat/splat as anything in request.splats)
		if(dirt_coverage_cause(splat.cause))
			fields++
	return reads + 4 * length(request.splats) + dirt_field_pieces(DIRT_CANVAS_TILE) * fields + 6 + length(request.cover) + length(request.clip) + length(request.cut) + length(request.read_parts())

/// A wag's job (/datum/dirt_wag_source) bakes its frames if it has more than one. A one-frame wag's job is about as
/// quick as a still tail's.
/datum/dirt_mask_job/bakes_frames()
	var/datum/dirt_wag_source/wag = request.shape_source
	return istype(wag) && wag.frames > 1

/**
 * Returns the sprite directions the request's parts or shape are read from, each list(sheet, state, direction, width,
 * height). That's every state of each in every direction, including the parts taking its general deposits. A wag's
 * are its still sprite's, which its frames are compared with. It has none if SSdirt.wag_sprites holds its sprites
 * (sprite_frames_kept). Blood below a taur's waist draws nothing facing north (dirt_blood_continuation()), so its shape
 * isn't read that way.
 */
/datum/dirt_mask_job/proc/wanted_reads()
	RETURN_TYPE(/list)
	. = list()
	var/datum/dirt_shape_source/shape = request.shape_source
	// a wag's frames are read as each is made (dirt_frame_owners()), never kept in SSdirt.sprite_reads
	var/datum/dirt_wag_source/wag = shape
	if(istype(wag))
		if(sprite_frames_kept)
			return
		shape = wag.still
	if(shape)
		var/list/size = dirt_canvases()[shape.canvas]
		for(var/direction in dirt_mask_directions())
			if(request.blood && direction == NORTH)
				continue
			for(var/layer_key, states in shape.layer_states)
				var/sheet = shape.sheet_of(layer_key)
				for(var/state in states)
					. += list(list(sheet, state, direction, size[1], size[2]))
		return
	var/list/sources = request.read_parts()
	if(request.deposit_parts)
		sources = sources | request.deposit_parts
	for(var/datum/dirt_part_source/source as anything in sources)
		for(var/direction in dirt_mask_directions())
			for(var/state in source.states)
				. += list(list(source.icon, state, direction, ICON_SIZE_X, ICON_SIZE_Y))

/**
 * Reads the next sprite direction of the job's parts or shape that SSdirt.sprite_reads doesn't hold, so
 * the pieces after find them all read: a horse taur draws six states and a part up to three, each read whole in four
 * directions.
 *
 * Returns whether it read one.
 */
/datum/dirt_mask_job/proc/read_wanted_sprite()
	for(var/turn in next_read to length(wanted_sprites))
		var/list/wanted = wanted_sprites[next_read++]
		if(!SSdirt.sprite_reads.fetch(dirt_sprite_read_key(wanted[1], wanted[2], wanted[3], wanted[4], wanted[5])))
			dirt_sprite_pixels(wanted[1], wanted[2], wanted[3], wanted[4], wanted[5])
			return TRUE
	return FALSE

/**
 * Returns the template it's drawn on once that's built, or null.
 */
/datum/dirt_mask_job/proc/held_template()
	RETURN_TYPE(/datum/dirt_template)
	if(template)
		return template
	if(istype(template_source, /datum/dirt_template_job))
		var/datum/dirt_template_job/template_job = template_source
		return template_job.built()
	return istype(template_source, /datum/dirt_template) ? template_source : null

/**
 * Notes a body that drew without the masks while this waits, to draw it again once they're made. A body being deleted
 * isn't drawn again.
 *
 * Arguments:
 * - body: The body.
 * - redraw_flags: DIRT_REDRAW_* flags, what to draw again.
 */
/datum/dirt_mask_job/proc/wait(mob/living/carbon/human/body, redraw_flags)
	var/datum/weakref/body_ref = WEAKREF(body)
	if(!body_ref || !redraw_flags)
		return
	LAZYINITLIST(waiters)
	waiters[body_ref] |= redraw_flags

/**
 * Makes the next piece of the masks: one sprite direction of its parts or shape read, one part's pixels read, one
 * splat rasterised in one direction (on a part, in every direction), one direction's splats merged, one sprite worn
 * over or under them read, or the icons. A taur body's, a drawn part's or the hair's dirt goes by next_taur_piece(),
 * and sweat's multiplier goes by next_wet_piece().
 *
 * Returns:
 * - TRUE: The masks are made, or can't be (failed).
 * - FALSE: Pieces are left.
 */
/datum/dirt_mask_job/next_piece()
	if(request.kind == DIRT_MASKS_WET)
		return next_wet_piece()
	if(!started)
		if(istype(template_source, /datum/dirt_template_job))
			var/datum/dirt_template_job/template_job = template_source
			template = template_job.built()
		else if(template_source)
			template = template_source
		// a part's, a drawn part's and the hair's masks need no template
		if(!template && (request.zone_sources || (request.kind != DIRT_MASKS_PART && request.kind != DIRT_MASKS_SHAPE && request.kind != DIRT_MASKS_HAIR)))
			failed = TRUE
			return TRUE
		started = TRUE
		splat_rasters = new /list(length(request.splats))
		splat_materials = dirt_splat_materials(request.splats)
		if(request.blood)
			// each stain's continuation merges as a splat's raster would, in its own material
			splat_materials = list()
			for(var/list/stain as anything in request.blood[1])
				splat_rasters += list(alist())
				splat_materials += stain[2]
		sprites = request.read_sprites()
		parts = request.read_parts()
		var/datum/dirt_wag_source/wag = request.shape_source
		if(istype(wag))
			sprite_frames = SSdirt.wag_sprites.fetch(wag.sprite_key())
			sprite_frames_kept = !!sprite_frames
			sprite_frames ||= alist()
		wanted_sprites = wanted_reads()
		for(var/direction in dirt_mask_directions())
			part_owns[direction] = alist()
	if(read_wanted_sprite())
		return FALSE
	if(request.kind == DIRT_MASKS_TAUR || request.kind == DIRT_MASKS_SHAPE || request.kind == DIRT_MASKS_HAIR)
		return next_taur_piece()
	if(next_part <= length(parts))
		read_part(parts[next_part++])
		return FALSE
	if(request.kind == DIRT_MASKS_PART)
		if(next_splat <= length(request.splats))
			rasterise_part(next_splat++)
			return FALSE
		for(var/direction in dirt_mask_directions())
			var/list/fields = list()
			for(var/alist/fields_by_direction as anything in splat_rasters)
				fields += fields_by_direction[direction]
			merged[direction] = length(fields) ? dirt_merge(fields, splat_materials) : new /datum/dirt_pixels
		masks = canvas_masks()
		return TRUE
	if(next_splat <= length(request.splats))
		rasterise_next()
		return FALSE
	for(var/direction in dirt_mask_directions())
		if(!merged[direction])
			merge(direction)
			return FALSE
	if(next_sprite <= length(sprites))
		read_sprite(sprites[next_sprite++])
		return FALSE
	masks = request.surface_kind == DIRT_SURFACE_SKIN ? limb_masks() : canvas_masks()
	return TRUE

/**
 * Makes the next piece of a taur body's, a drawn part's or the hair's dirt, once its states are read
 * (read_wanted_sprite()). A piece is what one direction of its canvas shows (dirt_taur_owners()), one splat in one
 * direction (rasterise_taur()), one direction of blood below a taur's waist (rasterise_blood()), one direction's splats
 * merged (the hair's by hair_merge()), or the icons (taur_masks()). A taur body's own dirt reads its rider at Average
 * height, then again at its own if that height stretches the rider. Each direction's merge is then carried onto the
 * pixels the stretched rider uncovers (dirt_taur_height_fill()). Blood below the waist reads the rider at its height
 * (dirt_blood_carriers()). A wag (/datum/dirt_wag_source) loads its sprite a state a piece, then goes a frame at a
 * time. Each frame is read as it's made (frame_owners()), and its dirt is carried from the still sprite's
 * (carry_frame()) and baked into its layers' animated icons (bake_frame()). Then the job puts those together
 * (frame_masks()). The still's dirt is made once, before the first frame is carried, as the still's own masks make it.
 * Its rasters are the still's, in SSdirt.rasters. A one-frame wag ends once its frame is read if it shows the still
 * sprite's pixels in every direction. Its masks and its wag are then noted as showing the still's
 * (/datum/dirt_masks/var/shows_still). A wag whose sprites SSdirt.wag_sprites holds (sprite_frames_kept) loads and
 * reads nothing, because each frame's pixels and carry come from there.
 *
 * Returns:
 * - TRUE: The masks are made.
 * - FALSE: Pieces are left.
 */
/datum/dirt_mask_job/proc/next_taur_piece()
	var/datum/dirt_wag_source/wag = istype(request.shape_source, /datum/dirt_wag_source) ? request.shape_source : null
	if(wag)
		if(!frame)
			if(!sprite_frames_kept)
				frame_sheets ||= alist()
				for(var/state in wag.state_frames)
					if(!frame_sheets[state])
						var/icon/sprite = icon(wag.icon, state)
						// loaded in this piece, not at its first read
						sprite.GetPixel(1, 1)
						frame_sheets[state] = sprite
						return FALSE
			next_frame()
		else if(frame > wag.frames)
			masks = frame_masks()
			return TRUE
		for(var/direction in dirt_mask_directions())
			if(!frame_shown[direction])
				frame_shown[direction] = frame_owners(direction)
				// a kept wag's are unpacked, all four in this piece
				if(!sprite_frames_kept)
					return FALSE
		if(wag.frames == 1 && frame_shows_still())
			wag.shows_still = TRUE
			masks = new(key)
			masks.shows_still = TRUE
			return TRUE
	// a wag's dirt is its still sprite's, made once, and frame_owners() read its owners with the first frame's
	for(var/direction in dirt_mask_directions())
		if(!taur_owners[direction])
			if(request.blood)
				// as the game draws them, for the blood alone
				blood_carriers ||= alist()
				blood_carriers[direction] = dirt_blood_carriers(request.shape_source, template ? template.surfaces[direction] : null, direction, request.blood)
				var/list/carriers = blood_carriers[direction]
				taur_owners[direction] = carriers[1]
				return FALSE
			taur_owners[direction] = dirt_taur_owners(wag ? wag.still : request.shape_source, template ? template.surfaces[direction] : null, direction)
			return FALSE
	if(request.rows)
		height_owners ||= alist()
		for(var/direction in dirt_mask_directions())
			if(!height_owners[direction])
				height_owners[direction] = dirt_taur_owners(request.shape_source, template ? template.surfaces[direction] : null, direction, rows = request.rows)
				return FALSE
	if(next_splat <= length(request.splats))
		rasterise_taur()
		return FALSE
	if(request.blood && rasterise_blood())
		return FALSE
	var/list/size = dirt_canvases()[request.shape_source.canvas]
	for(var/direction in dirt_mask_directions())
		if(merged[direction])
			continue
		if(request.kind == DIRT_MASKS_HAIR)
			hair_merge(direction)
			return FALSE
		var/list/drawn_rasters = list()
		for(var/alist/pools as anything in splat_rasters)
			drawn_rasters += pools[direction]
		merged[direction] = length(drawn_rasters) ? dirt_merge(drawn_rasters, splat_materials, size[1], size[2]) : new /datum/dirt_pixels(size[1], size[2])
		if(height_owners)
			dirt_taur_height_fill(merged[direction], taur_owners[direction], height_owners[direction])
		return FALSE
	if(!wag)
		masks = taur_masks()
		return TRUE
	for(var/direction in shape_faces())
		if(!frame_merged[direction])
			frame_merged[direction] = carry_frame(direction)
			return FALSE
	bake_frame()
	next_frame()
	return FALSE

/**
 * Starts a wag's next frame (/datum/dirt_wag_source), which is read and carried afresh. Past the last frame, only the
 * icons are left (frame_masks()).
 */
/datum/dirt_mask_job/proc/next_frame()
	frame++
	frame_shown = alist()
	frame_merged = alist()
	frame_from = alist()

/**
 * Returns the dirt of a wag's frame being made in one direction, carried from its still sprite's along the tail and
 * across it (/datum/dirt_tail_carry). So the dirt swings with the tail and draws as it does when the tail is still.
 * Where the frame shows the still sprite's pixels (frame_from), it's the still's dirt as it is. Each piece carries
 * DIRT_CARRY_PIXELS of the frame's pixels, and the first also works out the frame's coordinates (and the still's, at
 * its first carry). Returns null until the last piece, which notes the frame's pixels and carry in sprite_frames. A
 * kept wag's dirt is carried whole from sprite_frames (dirt_wag_carried()).
 *
 * Arguments:
 * - direction: The direction.
 */
/datum/dirt_mask_job/proc/carry_frame(direction)
	RETURN_TYPE(/datum/dirt_pixels)
	var/earlier = frame_from[direction]
	if(!isnull(earlier) && !earlier)
		return merged[direction]
	var/list/noted = sprite_frames[direction]
	if(sprite_frames_kept)
		return dirt_wag_carried(noted[frame + 1], merged[direction])
	var/datum/dirt_wag_source/wag = request.shape_source
	if(!frame_carry)
		still_coordinates ||= alist()
		still_coordinates[direction] ||= dirt_tail_coordinates(taur_owners[direction], wag.canvas, direction)
		frame_carry = new(frame_shown[direction], still_coordinates[direction], merged[direction], wag.canvas, direction)
	if(!frame_carry.carry_pixels(DIRT_CARRY_PIXELS))
		return null
	noted[frame + 1] = dirt_wag_pack(frame_shown[direction], wag.stack, frame_carry.sources)
	. = frame_carry.carried
	frame_carry = null

/**
 * Returns what each pixel of a wag's canvas shows in one direction at the frame being made (dirt_frame_owners()). It
 * notes in frame_from whether the still sprite or an earlier frame shows the same there, comparing an MD5 of each. If
 * one does, the frame takes the still's dirt as it is (carry_frame()), or that frame's bake (bake_frame()). The match
 * is noted in sprite_frames too, and the still's pixels are noted there with the first frame. A kept wag's pixels are
 * unpacked from sprite_frames, read from no sprite, and empty where an earlier frame shows the same.
 *
 * Arguments:
 * - direction: The direction.
 */
/datum/dirt_mask_job/proc/frame_owners(direction)
	RETURN_TYPE(/list)
	var/datum/dirt_wag_source/wag = request.shape_source
	var/list/noted = sprite_frames[direction]
	if(sprite_frames_kept)
		var/list/size = dirt_canvases()[wag.canvas]
		var/count = size[1] * size[2]
		taur_owners[direction] ||= dirt_wag_owners(noted[1], wag.still.stack, count, FALSE)
		var/held = noted[frame + 1]
		if(istext(held))
			frame_from[direction] = null
			return dirt_wag_owners(held, wag.stack, count, TRUE)
		frame_from[direction] = held
		// the still sprite's pixels, or none for an earlier frame, whose bake is taken whole (bake_frame())
		return held ? list() : taur_owners[direction]
	frame_keys ||= alist()
	var/alist/seen = frame_keys[direction]
	if(!seen)
		// the still sprite's pixels as its own masks read them, which every frame's dirt is carried from
		var/list/still_owners = dirt_taur_owners(wag.still, null, direction)
		taur_owners[direction] = still_owners
		seen = alist()
		seen[md5(jointext(still_owners, ","))] = 0
		frame_keys[direction] = seen
		noted = list(dirt_wag_pack(still_owners, wag.still.stack))
		sprite_frames[direction] = noted
	frame_sheets ||= alist()
	var/list/owners = dirt_frame_owners(wag, direction, frame, frame_sheets)
	var/owners_key = md5(jointext(owners, ","))
	frame_from[direction] = seen[owners_key]
	if(isnull(seen[owners_key]))
		seen[owners_key] = frame
	// a new frame's pixels are noted with its carry (carry_frame())
	noted += list(frame_from[direction])
	return owners

/// Returns whether a wag's frame being made shows the still sprite's pixels in every direction (frame_from).
/datum/dirt_mask_job/proc/frame_shows_still()
	for(var/direction in dirt_mask_directions())
		var/earlier = frame_from[direction]
		if(isnull(earlier) || earlier)
			return FALSE
	return TRUE

/**
 * Returns the directions where a wag's frame being made is carried and baked anew. That's all four but those whose
 * pixels an earlier frame showed, which take that frame's bake (bake_frame()).
 */
/datum/dirt_mask_job/proc/shape_faces()
	RETURN_TYPE(/list)
	. = list()
	for(var/direction in dirt_mask_directions())
		if(!frame_from[direction])
			. += direction

/**
 * Bakes the frame being made into each layer of the wag that has the frame, in every direction, at the layer's own
 * delay for it (/datum/dirt_wag_source/var/layer_frames). Each direction gets the runs of the carried dirt on the
 * pixels the layer shows at the frame, an earlier frame's bake where it shows the same pixels, or a blank. A layer's
 * animated icon (frame_icons) starts at its first frame with dirt, with blanks for the frames before it. Nothing is
 * registered here, because only frame_masks() registers what's shown.
 */
/datum/dirt_mask_job/proc/bake_frame()
	var/datum/dirt_wag_source/wag = request.shape_source
	var/icon/blank = dirt_canvas_blank(wag.canvas)
	frame_icons ||= alist()
	for(var/layer_key, entry in wag.layer_frames)
		var/list/frame_entry = entry
		var/list/delays = frame_entry[1]
		if(frame > length(delays))
			continue
		var/alist/runs = alist()
		for(var/direction in shape_faces())
			var/list/owners = frame_shown[direction]
			var/datum/dirt_pixels/pixel_map = frame_merged[direction]
			var/list/roles = pixel_map.roles
			var/list/indexes = list()
			for(var/index in 1 to length(owners))
				if(owners[index] == layer_key && roles[index])
					indexes += index
			dirt_role_runs(pixel_map, indexes, direction, runs)
		var/alist/drawn = dirt_baked_frames(runs, blank)
		var/icon/animated = frame_icons[layer_key]
		if(!animated)
			if(!drawn)
				continue
			animated = icon(blank)
			frame_icons[layer_key] = animated
			for(var/earlier in 1 to frame - 1)
				for(var/direction in dirt_mask_directions())
					animated.Insert(blank, icon_state = "", dir = direction, frame = earlier, delay = delays[earlier])
		for(var/direction in dirt_mask_directions())
			var/earlier = frame_from[direction]
			var/icon/shown = earlier ? icon(animated, "", direction, earlier) : (drawn?[direction] || blank)
			animated.Insert(shown, icon_state = "", dir = direction, frame = frame, delay = delays[frame])

/**
 * Returns a wag's masks once every frame is baked: each layer's animated icon with dirt, registered in the resource
 * cache. An icon built at run time can't hold the rewind flag. So a layer that rewinds gets its frames again in reverse
 * after the last, at their delays, and its dirt keeps step with the state it's drawn over. A layer without dirt in any
 * frame draws none.
 */
/datum/dirt_mask_job/proc/frame_masks()
	RETURN_TYPE(/datum/dirt_masks)
	var/datum/dirt_wag_source/wag = request.shape_source
	var/datum/dirt_masks/made = new(key)
	for(var/layer_key, built in frame_icons)
		var/icon/animated = built
		var/list/frame_entry = wag.layer_frames[layer_key]
		var/list/delays = frame_entry[1]
		var/count = length(delays)
		if(frame_entry[2])
			for(var/earlier in count - 1 to 2 step -1)
				for(var/direction in dirt_mask_directions())
					animated.Insert(icon(animated, "", direction, earlier), icon_state = "", dir = direction, frame = 2 * count - earlier, delay = delays[earlier])
		made.baked_by_layer[layer_key] = bulge_register_icon(animated)
	return made

/**
 * Returns the field a general deposit is drawn from. Each field is made once and drawn a band a piece. On the job's
 * shape, it's the canvas field, drawn facing one way (dirt_shape_field_facing()) and made once for every direction it
 * serves. For a douse, it's a field on the shape's pixels in one direction (/datum/dirt_canvas_field/douse). For a
 * taur body's contact coat, on its fur or a taur suit's cloth, it's a field in one direction
 * (/datum/dirt_canvas_field/taur_coat). On a body's template, it's a plunge, a blast or a douse in one direction
 * (/datum/dirt_canvas_field/body). The deposit's fields in every direction share one table of its noise
 * (field_samples). A body's fields also share the deposit's features (deposit_features).
 *
 * Arguments:
 * - splat: The deposit.
 * - material: Its /datum/dirt_material.
 * - facing: The direction the field is drawn facing. For a douse, a coat or a body, it's the direction being drawn.
 * - surface_kind: What it's drawn as: DIRT_SURFACE_FUR, DIRT_SURFACE_CLOTH (a taur suit's field) or DIRT_SURFACE_HAIR.
 *   On a body, DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH.
 */
/datum/dirt_mask_job/proc/field_for(datum/dirt_splat/splat, datum/dirt_material/material, facing, surface_kind = DIRT_SURFACE_FUR)
	RETURN_TYPE(/datum/dirt_canvas_field)
	var/samples_key = "[splat.cause]:[material.shape_class(splat.cause)]:[splat.level]:[splat.variant]"
	var/field_key = "[samples_key]:[facing]"
	canvas_fields ||= alist()
	var/datum/dirt_canvas_field/field = canvas_fields[field_key]
	if(!field)
		var/coat_cause = request.shape_source?.kind == DIRT_SHAPE_TAUR ? dirt_taur_coat_cause(splat.cause) : null
		if(!request.shape_source)
			field = new /datum/dirt_canvas_field/body(splat.cause, material, splat.level, splat.variant, request.side, surface_kind, template.surfaces[facing], request.painted, (deposit_features ||= alist()))
		else if(splat.cause == DIRT_CAUSE_DOUSE)
			field = new /datum/dirt_canvas_field/douse(dirt_shape_mask(taur_owners[facing]), material, splat.level, splat.variant, request.shape_source.canvas, facing, surface_kind)
		else if(coat_cause)
			field = new /datum/dirt_canvas_field/taur_coat(request.shape_source, coat_cause, material, splat.level, splat.variant, facing)
		else
			field = new(splat.cause, material, splat.level, splat.variant, request.shape_source.canvas, facing, surface_kind, request.side)
		canvas_fields[field_key] = field
		field_samples ||= alist()
		field.samples = (field_samples[samples_key] ||= field.samples)
	return field

/**
 * Makes the next piece of sweat's multiplier on a garment (/datum/dirt_mask_request/wet), which needs no template. A
 * piece is one direction's factors, or the icon (dirt_wet_icon()), stored as `baked`. The factors come from the
 * garment's sprite near the masks' wet pixels (dirt_garment_pixels(), dirt_wet_factors()), with none under the sprites
 * drawn over it that stay dry. The first piece makes the garment's sprite and each sprite kept dry (wet_sprites),
 * which every direction reads.
 *
 * Returns:
 * - TRUE: The multiplier is made.
 * - FALSE: Pieces are left.
 */
/datum/dirt_mask_job/proc/next_wet_piece()
	var/datum/dirt_mask_request/wet/wet_request = request
	if(!wet_factors)
		wet_factors = alist()
		wet_sprites = list(icon(wet_request.sheet, wet_request.state))
		for(var/list/sprite as anything in wet_request.kept_dry)
			wet_sprites += icon(sprite[1], sprite[2])
	var/list/directions = dirt_mask_directions()
	for(var/position in 1 to length(directions))
		var/direction = directions[position]
		if(wet_factors[direction])
			continue
		var/alist/wet = dirt_wet_alphas(wet_request.wet, position)
		var/alist/garment = dirt_garment_pixels(wet_request.sheet, wet_request.state, wet_request.colour, direction, wet, wet_request.shift_x, wet_request.shift_y, wet_sprites[1])
		var/alist/factors = dirt_wet_factors(garment, wet, ICON_SIZE_X, ICON_SIZE_Y)
		// each sprite kept dry is read where it's drawn on the garment's sprite
		for(var/dry_position in 1 to length(wet_request.kept_dry))
			var/list/sprite = wet_request.kept_dry[dry_position]
			for(var/index in dirt_garment_pixels(sprite[1], sprite[2], null, direction, factors, wet_request.shift_x - sprite[3], wet_request.shift_y - sprite[4], wet_sprites[dry_position + 1]))
				factors -= index
		wet_factors[direction] = factors
		return FALSE
	wet_sprites = null
	masks = new(key)
	masks.baked = dirt_wet_icon(wet_factors)
	return TRUE

/**
 * Makes the next splat on a taur body or a drawn part in the next direction it lacks. First it takes the directions
 * already made on this shape (and rider) from SSdirt.rasters, which cost no piece. A general deposit lands by the
 * shape's own rules (rasterise_shape_deposit()). Mess makes pools, which keep clear of the rider's mess: the splat at
 * its own level on the rider's cloth and skin. That rider's mess comes from SSdirt.rasters too, as the rider's own
 * masks may have made it. Each one made here is a piece of its own. The pools are made with the rider at Average
 * height (taur_owners), so every height shares their rasters. What's made goes in SSdirt.rasters.
 */
/datum/dirt_mask_job/proc/rasterise_taur()
	var/static/list/rider_surfaces = list(DIRT_SURFACE_CLOTH, DIRT_SURFACE_SKIN)
	for(var/turn in next_splat to length(request.splats))
		var/datum/dirt_splat/splat = request.splats[next_splat]
		splat_rasters[next_splat] ||= alist()
		var/alist/pools = splat_rasters[next_splat]
		if(splat.cause)
			if(rasterise_shape_deposit(splat, pools))
				return
			drop_deposit()
			next_splat++
			continue
		var/raster_key = "taur|[request.shape_source.shape_key()]|[template.key]|[splat.level]:[splat.variant]"
		for(var/direction in dirt_mask_directions())
			if(pools[direction])
				continue
			var/cached = SSdirt.rasters.fetch_direction(raster_key, direction)
			if(cached)
				pools[direction] = cached
				continue
			var/list/rider_mess = list()
			for(var/surface_kind in rider_surfaces)
				var/rider_key = "[template.key]|[surface_kind]|[splat.zone]:[splat.level]:[splat.variant]"
				var/rider_cached = SSdirt.rasters.fetch_direction(rider_key, direction)
				if(!rider_cached)
					var/datum/dirt_pixels/rider_drawn = dirt_rasterise("[DIRT_CAUSE_AIMED_PREFIX][splat.zone]", null, splat.level, splat.variant, request.side, surface_kind, template.surfaces[direction])
					SSdirt.rasters.store_direction(rider_key, direction, rider_drawn.drawn())
					return
				rider_mess += list(rider_cached)
			var/datum/dirt_pixels/drawn = dirt_taur_pools(taur_owners[direction], rider_mess, splat.level, splat.variant, direction)
			pools[direction] = SSdirt.rasters.store_direction(raster_key, direction, drawn.drawn())
			return
		next_splat++

/**
 * Makes one direction of a general deposit on a taur body or a drawn part (dirt_shape_deposit()), or on the hair as
 * hair (dirt_shape_rasterise()), unless every direction is made. Directions already made on this shape (and rider)
 * come from SSdirt.rasters. They're kept there under the cause, the material's shape class, the level, the variant and
 * the body's side, so materials alike share them. A taur body's are made as an Average rider shows its canvas
 * (taur_owners), so every height shares them. What's made goes in SSdirt.rasters. A deposit under its cause's first
 * hair level (dirt_hair_levels()) makes none on the hair. A deposit that the shape takes from the canvas field
 * (dirt_shape_field_facing()) is drawn from that field a band a piece (field_for()), once for every direction it
 * serves. The hair's is then kept to its crown (dirt_hair_crown()). Every shape's but a taur body's is clipped to its
 * pixels. A taur body's and a taur suit's are kept whole, as dirt_shape_deposit() draws them. A douse on any shape,
 * and a taur body's contact coat (dirt_taur_coat_cause()), on its fur or a taur suit's cloth, are drawn a band a piece
 * in each direction (field_for() too). A wag's rasters are its still sprite's, under the still's keys, which its own
 * masks' job keeps. Its frames carry them (carry_frame()).
 *
 * Arguments:
 * - splat: The deposit.
 * - rasters: alist(direction = /datum/dirt_pixels/proc/drawn()), its rasters so far, added to.
 *
 * Returns whether it made a direction or a band of its field. Either is a piece.
 */
/datum/dirt_mask_job/proc/rasterise_shape_deposit(datum/dirt_splat/splat, alist/rasters)
	var/datum/dirt_shape_source/shape = request.shape_source
	var/datum/dirt_wag_source/wag = shape
	if(istype(wag))
		shape = wag.still
	var/on_hair = shape.kind == DIRT_SHAPE_HAIR
	if(on_hair && splat.level < (dirt_hair_levels()[splat.cause] || INFINITY))
		return FALSE
	var/datum/dirt_material/material = dirt_material(splat.material)
	// a taur suit's is cloth, the hair's its own, the rest a drawn part's own coat
	var/surface_kind = on_hair ? DIRT_SURFACE_HAIR : (request.surface_kind == DIRT_SURFACE_CLOTH ? DIRT_SURFACE_CLOTH : DIRT_SURFACE_FUR)
	var/raster_rest = "[template?.key]|[surface_kind]|[splat.cause]:[material.shape_class(splat.cause)]:[splat.level]:[splat.variant]:[request.side]"
	for(var/direction in dirt_mask_directions())
		if(rasters[direction])
			continue
		var/raster_key = "shape|[shape.shape_key()]|[raster_rest]"
		var/cached = SSdirt.rasters.fetch_direction(raster_key, direction)
		if(cached)
			rasters[direction] = cached
			continue
		var/datum/dirt_pixels/drawn
		var/facing = dirt_shape_field_facing(shape.kind, splat.cause, direction)
		if(facing)
			var/datum/dirt_canvas_field/field = field_for(splat, material, facing, surface_kind)
			if(!field.done)
				dirt_canvas_field_band(field, src)
				return TRUE
			drawn = field.merged
			if(on_hair)
				dirt_drafted(GLOBAL_PROC_REF(dirt_hair_crown), list(field), null, src)
			if(shape.kind != DIRT_SHAPE_TAUR)
				drawn = dirt_clip_to_shape(drawn.copy(), dirt_shape_mask(taur_owners[direction]))
		else if(splat.cause == DIRT_CAUSE_DOUSE)
			// along this direction's own top edges, as dirt_shape_deposit() draws it, kept once its last band is drawn
			var/datum/dirt_canvas_field/douse/douse = field_for(splat, material, direction, on_hair ? DIRT_SURFACE_HAIR : DIRT_SURFACE_FUR)
			if(!douse.done && !dirt_canvas_field_band(douse, src))
				return TRUE
			drawn = douse.merged
		else if(shape.kind == DIRT_SHAPE_TAUR && dirt_taur_coat_cause(splat.cause))
			// a taur body's contact coat, as dirt_shape_deposit() draws it, kept once its last band is drawn
			var/datum/dirt_canvas_field/taur_coat/coat = field_for(splat, material, direction, surface_kind)
			if(!coat.done && !dirt_canvas_field_band(coat, src))
				return TRUE
			drawn = coat.merged
		else
			drawn = on_hair ? dirt_shape_rasterise(dirt_shape_mask(taur_owners[direction]), splat.cause, material, splat.level, splat.variant, shape.canvas, direction, DIRT_SURFACE_HAIR, request.side) : dirt_shape_deposit(shape, taur_owners[direction], splat.cause, material, splat.level, splat.variant, direction, surface_kind, request.side)
		rasters[direction] = SSdirt.rasters.store_direction(raster_key, direction, drawn.drawn())
		return TRUE
	return FALSE

/**
 * Makes blood below a taur's waist in the next direction it isn't made in yet (dirt_blood_rasterise()). It makes every
 * stain's at once, each in its own splat_rasters entry, on the taur body's own pixels or the taur-fitted garment's
 * cloth.
 *
 * Returns whether it made a direction, which is a piece.
 */
/datum/dirt_mask_job/proc/rasterise_blood()
	var/alist/first = splat_rasters[1]
	for(var/direction in dirt_mask_directions())
		if(first[direction])
			continue
		var/list/stains = dirt_blood_rasterise(request.blood, blood_carriers[direction], request.shape_source, direction, request.surface_kind == DIRT_SURFACE_CLOTH, template?.key)
		for(var/position in 1 to length(stains))
			var/alist/rasters = splat_rasters[position]
			rasters[direction] = stains[position]
		return TRUE
	return FALSE

/**
 * Returns a taur body's, a drawn part's or the hair's dirt as masks on its canvas. On skin or fur, each layer's mask
 * keeps to the pixels it shows. On cloth, the mask is the whole canvas, which a taur suit's own pixels clip. The hair's
 * is the whole canvas too, as its merge already keeps to its pixels (hair_merge()). A hairstyle with pieces drawn over
 * hats is the exception: each of its layers keeps to the pixels it shows.
 */
/datum/dirt_mask_job/proc/taur_masks()
	RETURN_TYPE(/datum/dirt_masks)
	var/datum/dirt_masks/made = new(key)
	var/datum/dirt_shape_source/shape = request.shape_source
	var/icon/blank = dirt_canvas_blank(shape.canvas)
	if(request.surface_kind == DIRT_SURFACE_CLOTH || (request.kind == DIRT_MASKS_HAIR && length(shape.stack) == 1))
		made.baked = dirt_baked_icon(dirt_shown_runs(merged), blank)
		return made
	var/alist/shown_by_layer = layers_shown()
	// in the stack's order, where the rider has no entry
	for(var/layer_key in shape.stack)
		var/alist/shown = shown_by_layer[layer_key]
		for(var/direction in dirt_mask_directions())
			if(length(shown?[direction]))
				made.baked_by_layer[layer_key] = dirt_baked_icon(dirt_shown_runs(merged, shown), blank)
				break
	return made

/**
 * Returns, for each layer of the stack but the rider, the pixels of a taur body's, a drawn part's or the hair's merge
 * that the layer shows: alist(layer key = alist(direction = indexes in row-major order)), with every direction listed.
 * In each direction one walk over the merge's drawn span (/datum/dirt_pixels/proc/drawn_span()) hands each drawn pixel
 * to the layer that shows it (height_owners at a height that stretches a taur's rider, else taur_owners). A pixel the
 * rider shows goes to no layer. The walk goes in row-major order, as dirt_role_runs() needs the pixels.
 */
/datum/dirt_mask_job/proc/layers_shown()
	RETURN_TYPE(/alist)
	var/alist/shown_by_layer = alist()
	for(var/layer_key in request.shape_source.stack)
		if(layer_key == DIRT_TAUR_RIDER)
			continue
		var/alist/shown = alist()
		for(var/direction in dirt_mask_directions())
			shown[direction] = list()
		shown_by_layer[layer_key] = shown
	for(var/direction in dirt_mask_directions())
		var/list/owners = height_owners?[direction] || taur_owners[direction]
		var/datum/dirt_pixels/pixel_map = merged[direction]
		var/list/roles = pixel_map.roles
		// layer key -> its indexes in this direction
		var/alist/layer_indexes = alist()
		for(var/layer_key, entry in shown_by_layer)
			var/alist/shown = entry
			layer_indexes[layer_key] = shown[direction]
		var/list/span = pixel_map.drawn_span()
		for(var/index in span[1] to span[2])
			if(!roles[index])
				continue
			var/layer_key = owners[index]
			if(!layer_key)
				continue
			var/list/indexes = layer_indexes[layer_key]
			if(indexes)
				indexes += index
	return shown_by_layer

/**
 * Reads the pixels a part takes its share on in every direction (dirt_part_own()).
 *
 * Arguments:
 * - source: The part.
 */
/datum/dirt_mask_job/proc/read_part(datum/dirt_part_source/source)
	for(var/direction in dirt_mask_directions())
		var/alist/owns = part_owns[direction]
		owns[source] = dirt_part_own(source, direction, template, parts, request.surface_kind)

/**
 * Rasterises one splat's field on a part's masks' part, in every direction.
 *
 * Arguments:
 * - position: The splat's place in the request.
 */
/datum/dirt_mask_job/proc/rasterise_part(position)
	var/datum/dirt_splat/splat = request.splats[position]
	var/datum/dirt_part_source/source = request.part_source
	var/alist/fields = alist()
	for(var/direction in dirt_mask_directions())
		if(request.facings && !(direction in request.facings))
			fields[direction] = new /datum/dirt_pixels
			continue
		var/alist/owns = part_owns[direction]
		fields[direction] = dirt_part_field(source.kind, owns[source], splat.zone, splat.level, splat.variant, direction)
	splat_rasters[position] = fields

/**
 * Adds a sprite's pixels in every direction to what its kind covers. A sprite with a shift is read where its wrapper
 * puts it over the body's tile, whatever its size (dirt_sprite_zone_pixels()).
 *
 * Arguments:
 * - sprite: list(icon, icon state, "cover", "clip" or "cut", shift or null), from the request's read_sprites().
 */
/datum/dirt_mask_job/proc/read_sprite(list/sprite)
	sprite_pixels[sprite[3]] ||= alist()
	var/alist/by_direction = sprite_pixels[sprite[3]]
	var/list/shift = sprite[4]
	for(var/direction in dirt_mask_directions())
		by_direction[direction] ||= new /list(ICON_SIZE_X * ICON_SIZE_Y)
		var/list/covered = by_direction[direction]
		for(var/index in shift ? dirt_sprite_zone_pixels(sprite[1], sprite[2], "tile", dirt_index_range(ICON_SIZE_X * ICON_SIZE_Y), direction, shift) : dirt_sprite_pixels(sprite[1], sprite[2], direction))
			covered[index] = TRUE

/**
 * Rasterises the next splat in the next direction it lacks (dirt_rasterise()). First it takes the directions already
 * rasterised on this template from SSdirt.rasters, which cost no piece. Each direction rasterised goes in
 * SSdirt.rasters. Mess goes there at its level in that direction (dirt_part_body_level()), under its zone, level and
 * variant. A general deposit goes under the surface it's rasterised on (the request's deposit_surface), its cause, its
 * material's shape class, level and variant, the body's side and whether it wears a painted design
 * (dirt_painted_design()). So materials alike share it and take their colours in the bake. On a bare body, one that
 * wears a design goes under its material instead, as each material's design differs. It's kept whole there, on every
 * limb, so every carrier holding it shares it, and each carrier keeps to its own limbs as it merges (merge()). A
 * plunge, a blast or a douse is drawn a band a piece (field_for()) and kept once its last band is drawn, as
 * dirt_rasterise() draws it whole. Each direction of a general deposit goes on from the lattice its other directions
 * sampled (/datum/dirt_mask_job/var/lattice), the features its first direction made (deposit_features) and the noise
 * they sampled (deposit_samples). A plunge's, a blast's or a douse's directions go on from their noise (field_samples).
 *
 * A deposit without a design on a bare body shares a dressed body's rasters, because it draws the same. Bareness
 * (painted) is read for the design alone. dirt_finish_deposit() reads it, finds no design and leaves the deposit
 * unpainted. dirt_rasterise_deposit() reads it for walking and kneeling, which have a design. dirt_rasterise() and the
 * body field (/datum/dirt_canvas_field/body/var/painted) only pass it on. Whether it's on skin
 * (dirt_rasterise_level()'s on_skin, the whole-body coat's set_material()) depends on the surface, which is in the key.
 */
/datum/dirt_mask_job/proc/rasterise_next()
	var/list/sources = request.parts
	var/deposit_surface = request.deposit_surface || request.surface_kind
	for(var/turn in next_splat to length(request.splats))
		var/datum/dirt_splat/splat = request.splats[next_splat]
		splat_rasters[next_splat] ||= alist()
		var/alist/rasters = splat_rasters[next_splat]
		var/datum/dirt_material/material = splat.cause && dirt_material(splat.material)
		for(var/direction in dirt_mask_directions())
			if(rasters[direction])
				continue
			var/level = splat.level
			var/raster_key
			if(splat.cause)
				var/designed = !!(request.painted && dirt_painted_design(splat.cause, material))
				raster_key = "[template.key]|[deposit_surface]|[splat.cause]:[designed ? material.id : material.shape_class(splat.cause)]:[level]:[splat.variant]:[request.side]:[designed]"
			else
				level = dirt_part_body_level(splat, sources, part_owns[direction])
				raster_key = "[template.key]|[request.surface_kind]|[splat.zone]:[level]:[splat.variant]"
			var/cached = SSdirt.rasters.fetch_direction(raster_key, direction)
			if(cached)
				rasters[direction] = cached
				continue
			var/datum/dirt_pixels/drawn
			if(dirt_coverage_cause(splat.cause))
				var/datum/dirt_canvas_field/body/field = field_for(splat, material, direction, deposit_surface)
				if(!dirt_canvas_field_band(field, src))
					return
				drawn = field.merged
#ifdef DIRT_DRAFT_EXACT
			else if(splat.cause)
				// drafting here, as dirt_rasterise() drafts it, on the lattice its other directions sampled
				drawn = dirt_drafted(GLOBAL_PROC_REF(dirt_rasterise), list(splat.cause, material, level, splat.variant, request.side, deposit_surface, template.surfaces[direction], request.painted, (deposit_features ||= alist()), (deposit_samples ||= alist())), null, src)
#endif
			else
				drawn = dirt_rasterise(splat.cause || "[DIRT_CAUSE_AIMED_PREFIX][splat.zone]", material, level, splat.variant, request.side, splat.cause ? deposit_surface : request.surface_kind, template.surfaces[direction], request.painted)
			rasters[direction] = SSdirt.rasters.store_direction(raster_key, direction, drawn.drawn())
			return
		drop_deposit()
		next_splat++

/**
 * Drops what the job holds for a deposit it has made in every direction: its fields with their samples, its features
 * with their noise, and its lattice. The deposit's rasters stay in SSdirt.rasters.
 */
/datum/dirt_mask_job/proc/drop_deposit()
	canvas_fields = null
	field_samples = null
	deposit_features = null
	deposit_samples = null
	lattice = null
	lattice_points = 0

/**
 * Merges one direction's splats into one mask, the thickest winning each pixel, with the parts drawn under and over the
 * surface (dirt_merge_with_parts()). Each splat's packed raster is read as it merges, a general deposit's on its limbs
 * alone. Mess's limbs are 0, so it's read whole.
 *
 * Arguments:
 * - direction: The direction.
 */
/datum/dirt_mask_job/proc/merge(direction)
	var/datum/dirt_surface/surface = template.surfaces[direction]
	var/list/drawn_rasters = list()
	var/list/limbs = list()
	for(var/position in 1 to length(splat_rasters))
		var/alist/rasters = splat_rasters[position]
		var/datum/dirt_splat/splat = request.splats[position]
		drawn_rasters += rasters[direction]
		limbs += splat.limbs
	if(!length(drawn_rasters))
		merged[direction] = new /datum/dirt_pixels(surface.width, surface.height)
	else if(length(parts))
		var/list/split = dirt_split_parts(parts, request.surface_layer, direction)
		merged[direction] = dirt_merge_with_parts(drawn_rasters, request.splats, split[1], split[2], part_owns[direction], direction, splat_materials, surface)
	else
		merged[direction] = dirt_merge(drawn_rasters, splat_materials, surface.width, surface.height, limbs, surface)

/**
 * Returns the masks for skin: each limb's baked from its runs (limb_runs()), and each part's that takes its general
 * deposits from its own runs (part_runs). A limb or part whose runs key matches the one in `previous` takes that icon
 * rather than a new bake, because equal runs bake the same icon (dirt_baked_icon()).
 */
/datum/dirt_mask_job/proc/limb_masks()
	RETURN_TYPE(/datum/dirt_masks)
	var/datum/dirt_masks/made = new(key)
	for(var/zone, runs in limb_runs())
		var/runs_key = dirt_runs_key(runs)
		made.baked_by_limb[zone] = previous?.limb_keys[zone] == runs_key ? previous.baked_by_limb[zone] : dirt_baked_icon(runs, null)
		made.limb_keys[zone] = runs_key
	for(var/part_key, runs in part_runs)
		var/runs_key = dirt_runs_key(runs)
		var/icon/baked = previous?.part_keys?[part_key] == runs_key ? previous.baked_by_part[part_key] : dirt_baked_icon(runs, null)
		if(!baked)
			continue
		if(!made.baked_by_part)
			made.baked_by_part = alist()
			made.part_keys = alist()
		made.baked_by_part[part_key] = baked
		made.part_keys[part_key] = runs_key
	previous = null
	return made

/**
 * Returns skin's runs, once its pieces are made: alist(limb zone = dirt_shown_runs()), for each limb they draw on, each
 * clipped to the pixels its image shows, so nothing floats in the margin past the body, and each limb's overlay draws
 * only on its own limb. The chest's also takes the pixels past the body of the parts drawn under the skin there (a butt
 * in profile), which carry their share in the skin's mess, so they're drawn with the chest. The parts taking its
 * general deposits get theirs in part_runs, faded as the limbs' runs are (deposit_part_runs()).
 */
/datum/dirt_mask_job/proc/limb_runs()
	RETURN_TYPE(/alist)
	. = alist()
	var/alist/fades
	var/alist/covered = sprite_pixels["cover"]
	if(covered)
		fades = alist()
		for(var/direction in dirt_mask_directions())
			fades[direction] = dirt_cover_fades(merged[direction], covered[direction])
	for(var/zone, shown in template.silhouettes)
		if(zone == BODY_ZONE_CHEST && length(parts))
			shown = parts_past_body(shown)
		var/alist/runs = dirt_shown_runs(merged, shown, fades)
		if(length(runs))
			.[zone] = runs
	if(request.deposit_parts)
		part_runs = deposit_part_runs(fades)

/**
 * Returns the runs of skin's general deposits on each part taking them (/datum/dirt_mask_request/var/deposit_parts)
 * that they reach: alist(its placed_key() against the skin = dirt_shown_runs()). A part takes them on its own pixels
 * in each direction it draws over the skin, where their raster lies on the body's template, as far past the body as
 * that reaches. That's how the reference generator composites the body's dirt over the parts drawn on it. Mess stays
 * off them, because a part takes its share of mess on itself. It takes no share of general deposits, and draws them
 * at their own level.
 *
 * Arguments:
 * - fades: alist(direction = dirt_cover_fades()), as the limbs' runs fade beside what's worn, or null.
 */
/datum/dirt_mask_job/proc/deposit_part_runs(alist/fades)
	RETURN_TYPE(/alist)
	. = alist()
	for(var/datum/dirt_part_source/source as anything in request.deposit_parts)
		var/alist/shown = alist()
		var/any_shown = FALSE
		for(var/direction in dirt_mask_directions())
			var/list/indexes = list()
			shown[direction] = indexes
			var/datum/dirt_pixels/pixel_map = merged[direction]
			// null only on a merge of mess alone, or of nothing
			var/list/materials = pixel_map.materials
			if(!materials || source.under(direction, request.surface_layer))
				continue
			var/list/roles = pixel_map.roles
			for(var/index in source.pixels(direction))
				if(roles[index] && materials[index] != DIRT_MATERIAL_MESS)
					indexes += index
			if(length(indexes))
				any_shown = TRUE
		if(any_shown)
			.[source.placed_key(request.surface_layer)] = dirt_shown_runs(merged, shown, fades)

/**
 * Returns the chest's pixels in each direction with the pixels past the body of the parts drawn under the skin there
 * added: alist(direction = indexes in row-major order).
 *
 * Arguments:
 * - chest: alist(direction = indexes), the pixels the chest's image shows.
 */
/datum/dirt_mask_job/proc/parts_past_body(alist/chest)
	RETURN_TYPE(/alist)
	var/alist/shown = alist()
	for(var/direction in dirt_mask_directions())
		var/datum/dirt_surface/surface = template.surfaces[direction]
		var/list/flags_of = surface.flags_of
		var/alist/owns = part_owns[direction]
		var/list/added = new /list(ICON_SIZE_X * ICON_SIZE_Y)
		var/extra = FALSE
		for(var/datum/dirt_part_source/source as anything in parts)
			if(!source.under(direction, request.surface_layer))
				continue
			for(var/index in owns[source])
				if(!DIRT_PIXEL_ZONE(flags_of[index]))
					added[index] = TRUE
					extra = TRUE
		if(!extra)
			shown[direction] = chest[direction]
			continue
		for(var/index in chest[direction])
			added[index] = TRUE
		var/list/indexes = list()
		for(var/index in 1 to length(added))
			if(added[index])
				indexes += index
		shown[direction] = indexes
	return shown

/**
 * Returns the masks for cloth or a part. They're baked from its runs on the pixels canvas_shown() gives. They also keep
 * the wet pixels for sweat's multiplier, which take no colour in the bake.
 */
/datum/dirt_mask_job/proc/canvas_masks()
	RETURN_TYPE(/datum/dirt_masks)
	var/datum/dirt_masks/made = new(key)
	var/alist/shown = canvas_shown()
	made.baked = dirt_baked_icon(dirt_shown_runs(merged, shown), null)
	if(dirt_holds_wet(splat_materials))
		made.wet = dirt_wet_drawn(merged, shown)
	return made

/**
 * Returns the pixels cloth's or a part's masks draw, once its pieces are made. On underclothes it's only the pixels
 * they show, alist(direction = indexes in row-major order). It's null for the whole canvas, which the garment's own
 * pixels clip.
 */
/datum/dirt_mask_job/proc/canvas_shown()
	RETURN_TYPE(/alist)
	if(!length(request.clip))
		return null
	var/alist/shown = alist()
	var/alist/kept = sprite_pixels["clip"]
	var/alist/cut_off = sprite_pixels["cut"]
	for(var/direction in dirt_mask_directions())
		var/list/kept_pixels = kept[direction]
		var/list/cut_pixels = cut_off?[direction]
		var/list/indexes = list()
		for(var/index in 1 to length(kept_pixels))
			if(kept_pixels[index] && !cut_pixels?[index])
				indexes += index
		shown[direction] = indexes
	return shown

/**
 * Returns how near a mask's pixels lie to what's worn over them, where they fade out: alist(index = 1 beside it, or 2
 * one pixel further), for the pixels drawn that it leaves bare. Steps are up, down and across.
 *
 * Arguments:
 * - pixel_map: The mask.
 * - covered: Which pixels are worn over, a list of TRUE or null per pixel.
 */
/proc/dirt_cover_fades(datum/dirt_pixels/pixel_map, list/covered)
	RETURN_TYPE(/alist)
	var/alist/fades = alist()
	var/list/neighbours = dirt_neighbour_table(pixel_map.width, pixel_map.height)
	var/list/roles = pixel_map.roles
	for(var/index in pixel_map.drawn_indexes || dirt_index_range(length(roles)))
		if(!roles[index] || covered[index])
			continue
		var/ring = 0
		for(var/near in neighbours[index])
			if(covered[near])
				ring = 1
				break
		if(!ring)
			for(var/near in neighbours[index])
				for(var/further in neighbours[near])
					if(covered[further])
						ring = 2
						break
				if(ring)
					break
		if(ring)
			fades[index] = ring
	return fades

/**
 * Returns the directions a mask is made in, in the order its pieces go. You should NEVER modify it.
 */
/proc/dirt_mask_directions()
	RETURN_TYPE(/list)
	var/static/list/directions = list(SOUTH, NORTH, EAST, WEST)
	return directions

/**
 * Returns a mask's drawn pixels alone, which is all a cached raster keeps, packed as text: "1" if it covers, else "0",
 * then its drawn pixels in row-major order, a run at a time. A run is pixels side by side in one role and thickness.
 * Each run is four base-64 digits ("0" to "o") holding 24 bits (DIRT_PACKED_RUN()): its first pixel's index - 1 in 11,
 * its length - 1 in 6, its role in 3 and its thickness's code in 4 (dirt_thickness_code()). Every run is as long as it
 * goes, up to 64 pixels, so equal masks pack as equal text. 11 bits hold indexes up to 2048, the size of the 64x32 taur
 * canvas, and every canvas fits in that. A bigger mask can't be packed. SSdirt.rasters keeps a splat's four directions
 * joined in one text, held under its key. Only this proc writes the text. DIRT_PACKED_BITS() and the fields after
 * it read it back.
 */
/datum/dirt_pixels/proc/drawn()
	var/static/list/digits
	if(!digits)
		digits = list()
		for(var/value in 0 to 63)
			digits += ascii2text(48 + value)
	var/list/chars = list(covers ? "1" : "0")
	var/list/span = drawn_span()
	var/last = span[2]
	// the run so far
	var/first = 0
	var/run_length = 0
	var/run_role
	var/run_thickness
	var/run_code
	// a step past the last pixel ends the last run
	for(var/index in span[1] to last + 1)
		var/role = index <= last ? roles[index] : null
		if(!role)
			// a blank pixel only ends a run
			if(!run_length)
				continue
		else if(role == run_role && thicknesses[index] == run_thickness && run_length < 64)
			run_length++
			continue
		if(run_length)
			var/bits = DIRT_PACKED_RUN(first, run_length, run_role, run_code)
			chars += digits[floor(bits / 262144) + 1]
			chars += digits[floor(bits / 4096) % 64 + 1]
			chars += digits[floor(bits / 64) % 64 + 1]
			chars += digits[bits % 64 + 1]
		first = index
		run_length = role ? 1 : 0
		run_role = role
		if(role)
			// its pixels share one thickness, so the run takes one code, numbered as thicknesses first come
			run_thickness = thicknesses[index]
			run_code = dirt_thickness_code(run_thickness)
	return jointext(chars, "")

/**
 * Returns the first and the last pixel a walk in row-major order needs to meet every drawn pixel, list(first, last).
 * Where drawn_indexes is kept, they're the lowest and the highest index it lists, or the last comes before the first
 * if it lists none. Where it isn't kept, they span the whole canvas.
 */
/datum/dirt_pixels/proc/drawn_span()
	RETURN_TYPE(/list)
	if(!drawn_indexes)
		return list(1, length(roles))
	if(!length(drawn_indexes))
		return list(1, 0)
	return list(min(drawn_indexes), max(drawn_indexes))

/**
 * Returns the code a thickness packs as in /datum/dirt_pixels/proc/drawn(), from 0: its place among the thicknesses
 * packed so far this round. A mask's thicknesses come from a handful of values, because every thickness a mask is
 * drawn with is a constant. A thickness worked out per pixel would use up the codes.
 *
 * Arguments:
 * - thickness: The thickness.
 *
 * Crashes:
 * - Past 16 thicknesses, which a code can't hold.
 */
/proc/dirt_thickness_code(thickness)
	var/static/alist/codes = alist()
	var/code = codes[thickness]
	if(!isnull(code))
		return code
	var/list/thicknesses = dirt_packed_thicknesses()
	if(length(thicknesses) >= 16)
		CRASH("Dirt masks pack 16 thicknesses at most: [thickness] is the 17th.")
	thicknesses += thickness
	codes[thickness] = length(thicknesses) - 1
	return codes[thickness]

/**
 * Returns the thicknesses packed so far, indexed by their code + 1 (dirt_thickness_code()). You should NEVER modify it.
 */
/proc/dirt_packed_thicknesses()
	RETURN_TYPE(/list)
	var/static/list/thicknesses = list()
	return thicknesses

/**
 * Returns a mask made again from its drawn pixels. Given a general deposit's limbs, it keeps the pixels on them alone.
 * That's because a carrier holds a deposit only on the limbs it showed on as it landed. A pixel off them is skipped.
 * It's never written and never in drawn_indexes, so every merge reads it as a pixel with no role. Limbs 0 or every limb
 * keep every pixel. A merge reads the text itself instead (dirt_merge()).
 *
 * Arguments:
 * - drawn: From /datum/dirt_pixels/proc/drawn().
 * - width: Pixels across.
 * - height: Pixels down.
 * - limbs: The limbs kept, DIRT_LIMB_BIT() of each, or 0 or null for every one.
 * - surface: The surface it's rasterised on, whose pixels name their limbs; read only with limbs.
 */
/proc/dirt_pixels_from_drawn(drawn, width, height, limbs = null, datum/dirt_surface/surface = null)
	RETURN_TYPE(/datum/dirt_pixels)
	var/datum/dirt_pixels/pixel_map = new(width, height)
	var/list/thicknesses = dirt_packed_thicknesses()
	var/list/roles = pixel_map.roles
	var/list/drawn_thicknesses = pixel_map.thicknesses
	var/list/indexes = list()
	pixel_map.covers = text2ascii(drawn, 1) == 49
	pixel_map.drawn_indexes = indexes
	// null while every limb is kept
	var/list/flags_of = (limbs && (limbs & DIRT_LIMBS_ALL) != DIRT_LIMBS_ALL) ? surface.flags_of : null
	for(var/run in 1 to DIRT_PACKED_COUNT(drawn))
		var/bits = DIRT_PACKED_BITS(drawn, run)
		var/role = DIRT_PACKED_ROLE(bits)
		var/thickness = thicknesses[DIRT_PACKED_CODE(bits) + 1]
		for(var/index in DIRT_PACKED_FIRST(bits) to DIRT_PACKED_LAST(bits))
			if(flags_of)
				var/limb = DIRT_PIXEL_LIMB(flags_of[index])
				if(!(limb && (limbs & DIRT_LIMB_BIT(limb))))
					continue
			indexes += index
			roles[index] = role
			drawn_thicknesses[index] = thickness
	return pixel_map

/**
 * Returns the indexes of a mask's drawn pixels, in row-major order.
 *
 * Arguments:
 * - drawn: From /datum/dirt_pixels/proc/drawn().
 */
/proc/dirt_drawn_indexes(drawn)
	RETURN_TYPE(/list)
	. = list()
	for(var/run in 1 to DIRT_PACKED_COUNT(drawn))
		var/bits = DIRT_PACKED_BITS(drawn, run)
		for(var/index in DIRT_PACKED_FIRST(bits) to DIRT_PACKED_LAST(bits))
			. += index

/**
 * Returns the roles runs are drawn in, one to a pixel, in the order they're baked: haze is film at half
 * (dirt_role_runs()). You should NEVER modify it.
 */
/proc/dirt_drawn_roles()
	RETURN_TYPE(/list)
	var/static/list/roles = list(DIRT_ROLE_FILM, DIRT_ROLE_BODY, DIRT_ROLE_CORE, DIRT_ROLE_FLECK, DIRT_ROLE_GLINT)
	return roles

/**
 * Returns a surface's runs, as dirt_role_runs() lays them: alist(material = alist(DIRT_ROLE_* define =
 * alist(direction = runs))), each material as a splat stores it.
 *
 * Arguments:
 * - merged: alist(direction = /datum/dirt_pixels), the surface's mess in each direction.
 * - shown: alist(direction = indexes), the only pixels drawn, or null for the whole canvas. With null, a mask that
 *   keeps its drawn pixels is walked from the first to the last (/datum/dirt_pixels/proc/drawn_span()).
 * - fades: alist(direction = dirt_cover_fades()): pixels drawn fainter beside what's worn over them, or null.
 */
/proc/dirt_shown_runs(alist/merged, alist/shown, alist/fades)
	RETURN_TYPE(/alist)
	// material -> alist(role -> alist(direction -> runs))
	var/alist/runs = alist()
	for(var/direction in dirt_mask_directions())
		var/datum/dirt_pixels/pixel_map = merged[direction]
		var/list/indexes = shown ? shown[direction] : dirt_index_range(length(pixel_map.roles))
		if(!shown && pixel_map.drawn_indexes)
			var/list/span = pixel_map.drawn_span()
			indexes = indexes.Copy(span[1], span[2] + 1)
		dirt_role_runs(pixel_map, indexes, direction, runs, fades?[direction])
	return runs

/**
 * Returns runs baked into one four-direction RGBA icon on a blank state (dirt_baked_frames()), or null when they draw
 * nothing. It's registered in the resource cache the way bulge_register_icon() registers an icon built at run time.
 *
 * Arguments:
 * - runs: From dirt_shown_runs().
 * - blank: A blank of the icon's size, or null for 32x32.
 */
/proc/dirt_baked_icon(alist/runs, icon/blank)
	var/alist/frames = dirt_baked_frames(runs, blank)
	if(!frames)
		return null
	var/icon/baked = icon(blank || bulge_blank_tile())
	for(var/direction in dirt_mask_directions())
		baked.Insert(frames[direction], "", direction)
	return bulge_register_icon(baked)

/**
 * Returns runs drawn on a blank in each direction, alist(direction = icon), unregistered, or null when they draw
 * nothing. Each run is one DrawBox() in its material's tint colour for its role (dirt_material()), at the tint's alpha
 * times the run's level, rounded to 8 bits. A wet material's runs (sweat) take no colour, because the cloth darkens
 * under them in its own colour (dirt_wet_image()).
 *
 * Arguments:
 * - runs: From dirt_shown_runs(), or dirt_role_runs() in some directions.
 * - blank: A blank of the icon's size, or null for 32x32.
 */
/proc/dirt_baked_frames(alist/runs, icon/blank)
	RETURN_TYPE(/alist)
	var/alist/coloured = runs
	for(var/material_key in runs)
		if(dirt_material(material_key).flags & DIRT_MATERIAL_WET)
			// the others go in a list of their own, so the caller's runs keep every material
			coloured = alist()
			for(var/kept_key, kept_runs in runs)
				if(!(dirt_material(kept_key).flags & DIRT_MATERIAL_WET))
					coloured[kept_key] = kept_runs
			break
	if(!length(coloured))
		return null
	blank ||= bulge_blank_tile()
	// the bake composites nothing, as a mask holds one material and one role per pixel
	// a material whose roles could overlap on a pixel would need compositing
	// direction -> its frame, drawn a material at a time
	var/alist/frames = alist()
	for(var/direction in dirt_mask_directions())
		frames[direction] = icon(blank)
	for(var/material_key, by_role in coloured)
		var/alist/roles_runs = by_role
		var/list/tints = dirt_material(material_key).tints
		// role * 256 + level -> rgb() text
		var/alist/colours = alist()
		for(var/direction in dirt_mask_directions())
			var/icon/frame = frames[direction]
			for(var/role in dirt_drawn_roles())
				var/alist/by_direction = roles_runs[role]
				for(var/list/run as anything in by_direction?[direction])
					var/colour_key = role * 256 + run[4]
					var/colour = colours[colour_key]
					if(!colour)
						var/list/tint = tints[role]
						var/list/channels = rgb2num(tint[1])
						var/alpha = tint[2] * run[4] / 255
						colour = rgb(channels[1], channels[2], channels[3], round(alpha * 255, 1))
						colours[colour_key] = colour
					frame.DrawBox(colour, run[2], run[1], run[3], run[1])
	return frames

/**
 * Returns an MD5 of what runs draw, the same for runs that draw the same pixels. It hashes each material's name, then
 * its roles' runs in each direction, in a fixed order, with their levels.
 *
 * Arguments:
 * - runs: From dirt_shown_runs().
 */
/proc/dirt_runs_key(alist/runs)
	var/list/key_parts = list()
	for(var/material_key, by_role in runs)
		var/alist/roles_runs = by_role
		key_parts += "material [material_key]"
		for(var/role in dirt_drawn_roles())
			var/alist/by_direction = roles_runs[role]
			if(!by_direction)
				continue
			key_parts += "role [role]"
			for(var/direction in dirt_mask_directions())
				key_parts += "dir [direction]"
				for(var/list/run as anything in by_direction[direction])
					key_parts += "[run[1]],[run[2]],[run[3]],[run[4]]"
	return md5(jointext(key_parts, ";"))

/**
 * Adds a mask's horizontal runs in one direction to each material's roles, each run list(icon y, first icon x, last
 * icon x, level). A run is one material's pixels in one role, side by side in one row at one level. The level is how
 * much of each pixel it covers out of 255: DIRT_MASK_SOLID, or DIRT_MASK_HALF for haze, which is drawn as film. A
 * pixel beside what's worn over it keeps a share of its level: its fade ring over DIRT_FADE_RINGS + 1. A run goes in
 * its list as it ends, when its role's next run starts or after the last pixel. A list is made as its first run goes
 * in, so equal masks give equal runs.
 *
 * Arguments:
 * - pixel_map: The mask. Its pixels are mess's where it holds no materials.
 * - indexes: The pixels to draw, in row-major order.
 * - direction: The direction it's seen from.
 * - runs: alist(material = alist(DIRT_ROLE_* define = alist(direction = runs))), added to.
 * - fades: dirt_cover_fades() in this direction, or null.
 */
/proc/dirt_role_runs(datum/dirt_pixels/pixel_map, list/indexes, direction, alist/runs, alist/fades)
	var/list/roles = pixel_map.roles
	var/list/materials = pixel_map.materials
	var/width = pixel_map.width
	var/material = DIRT_MATERIAL_MESS
	// role -> its run being drawn, or null
	var/alist/open = alist()
	// role -> the material of its run being drawn, where the mask holds a material per pixel
	var/alist/open_materials = materials && alist()
	// indexed by role: the list its open run goes in as it ends, found as its first run in that material ends
	var/list/open_targets = new /list(DIRT_ROLE_GLINT)
	// the last drawn pixel met, and its run
	var/last_index = 0
	var/last_icon_x
	var/last_role
	var/last_level
	var/last_material
	var/list/last_run
	for(var/index in indexes)
		var/role = roles[index]
		if(!role)
			continue
		if(materials)
			material = materials[index]
		var/level = role == DIRT_ROLE_HAZE ? DIRT_MASK_HALF : DIRT_MASK_SOLID
		var/ring = fades?[index]
		if(ring)
			level = round(level * ring / (DIRT_FADE_RINGS + 1), 1)
		if(role == DIRT_ROLE_HAZE)
			role = DIRT_ROLE_FILM
		// just right of the last pixel met, in its role, level and material, so it grows that pixel's run
		if(index == last_index + 1 && last_icon_x < width && role == last_role && level == last_level && material == last_material)
			last_run[3]++
			last_index = index
			last_icon_x++
			continue
		var/row = floor((index - 1) / width)
		var/icon_x = index - row * width
		var/icon_y = pixel_map.height - row
		var/list/run = open[role]
		if(run)
			var/list/target = open_targets[role]
			if(!target)
				target = dirt_runs_target(runs, materials ? open_materials[role] : material, role, direction)
				open_targets[role] = target
			target += list(run)
		run = list(icon_y, icon_x, icon_x, level)
		open[role] = run
		if(materials && open_materials[role] != material)
			open_materials[role] = material
			open_targets[role] = null
		last_index = index
		last_icon_x = icon_x
		last_role = role
		last_level = level
		last_material = material
		last_run = run
	for(var/role, run in open)
		var/list/target = open_targets[role] || dirt_runs_target(runs, materials ? open_materials[role] : material, role, direction)
		target += list(run)

/**
 * Returns the list that one material's runs in one role and one direction go in. It's made as its first run goes in
 * (dirt_role_runs()).
 *
 * Arguments:
 * - runs: alist(material = alist(DIRT_ROLE_* define = alist(direction = runs))), added to.
 * - material_key: The material.
 * - role: A DIRT_ROLE_* define.
 * - direction: The direction.
 */
/proc/dirt_runs_target(alist/runs, material_key, role, direction)
	RETURN_TYPE(/list)
	var/alist/by_role = (runs[material_key] ||= alist())
	var/alist/by_direction = (by_role[role] ||= alist())
	return (by_direction[direction] ||= list())

#undef DIRT_MASK_SOLID
#undef DIRT_MASK_HALF
#undef DIRT_CARRY_PIXELS
