// Drawn parts as carriers of general dirt: tails, wings, ears, horns and the other mutant parts. The person holds each
// part's splats under its organ slot (/datum/component/dirtiness/var/part_splats), and the organ takes them with it. A
// taur body's are held the same way (taur_overlay.dm). Each part draws its dirt in a container over each of its layers'
// images, in its own image holder. The dirt comes from the part's own sprite read (dirt_shape_source_of()). A tail's is
// drawn by dirt_tail_rasterise() and wings' by dirt_wing_rasterise(). Any other part's comes from the field causes only
// (dirt_shape_rasterise()). Tail spines, held by the tail rather than by an organ of their own, take none. Every mutant
// part's get_overlay() and icon_render_key() draw and key it through dirt_shape_overlay() and dirt_shape_render_key().
// A wagging tail draws its dirt baked on every frame of its wag (/datum/dirt_wag_source). That's its still dirt,
// carried onto each frame along the tail and across it (/datum/dirt_tail_carry). The frames are made at its first wag
// after the dirt changes, and it draws none until then. A one-frame wag that shows the still sprite's pixels draws the
// still dirt. Any one-frame wag does too, while its job finds out whether it shows them.

/// How far over the floor a tail joins the body, in pixels: the hips. dirt_tail_coordinates() measures along the tail
/// from there.
#define DIRT_TAIL_ROOT_UP 13
/// How far behind the tile's middle a taur's tail joins its body in profile, and how far over the floor: its rump.
#define DIRT_TAUR_RUMP_BACK 19
#define DIRT_TAUR_RUMP_UP 10

/datum/bodypart_overlay/mutant
	/// The part as dirt reads it (dirt_shape_source_of()), or null when it can't be.
	var/datum/dirt_shape_source/dirt_shape
	/// What dirt_shape was read for: the accessory, its feature key and base state, the limb's gender and its sheet.
	var/dirt_shape_read_key
	/// What dirt_shape was last read or found under, with the part's own render key, while the part was still
	/// (dirt_shape_render_key()). It's list(the accessory, the limb's gender, a copy of the key without its dirt), or
	/// null. The same three find it again without building dirt_shape_read_key.
	var/list/dirt_shape_own_read
	/// A wagging tail as dirt reads it wagging (dirt_shape_source_of()), or null when it can't be.
	var/datum/dirt_shape_source/dirt_wag_shape
	/// What dirt_wag_shape was read for, as dirt_shape_read_key.
	var/dirt_wag_read_key

/datum/dirt_drawing
	/// For a wagging tail, its wag's masks (/datum/component/dirtiness/proc/ready_wag_masks()), or null. They're made
	/// from this request's splats and dropped as those change.
	var/datum/dirt_drawing/wag
	/// The key of the first request forget() dropped since the drawing last asked for masks, or null. That request's
	/// job is dropped once the next request has another key. /datum/dirt_drawing/proc/current() drops it, and so do
	/// /datum/component/dirtiness/proc/ready_wag_masks() for a wag's masks and
	/// /datum/component/dirtiness/proc/ready_skin_masks() for hidden skin, which skips current(). It's dropped with the
	/// drawing's own job as the drawing is let go (/datum/dirt_drawing/proc/drop_jobs(), drop_wag()).
	var/superseded_key

/datum/dirt_masks
	/// For a wag's masks (/datum/dirt_wag_source): whether its one frame shows the still sprite's pixels in every
	/// direction, so the part draws its still masks while it wags.
	var/shows_still = FALSE

/**
 * Stops drawing the wag's masks (`wag`). Drops their job, and the job of the request before them, if no other body
 * waits for it (/datum/controller/subsystem/dirt/proc/drop_mask_job()). Frames that nothing would draw cost up to a
 * second or more.
 *
 * Arguments:
 * - body: The body drawing them.
 */
/datum/dirt_drawing/proc/drop_wag(mob/living/carbon/human/body)
	if(wag)
		SSdirt.drop_mask_job(wag.key, body)
		SSdirt.drop_mask_job(wag.superseded_key, body)
	wag = null

/**
 * Returns the masks a wagging tail draws, from this, the part's drawing. Where its one frame shows the still sprite's
 * pixels, and while its job finds out whether it does, that's the still masks. Otherwise it's the wag's own once
 * they're made (`wag`), or none.
 *
 * Arguments:
 * - wag_source: The part read wagging, or null when it can't be.
 */
/datum/dirt_drawing/proc/wag_shown(datum/dirt_wag_source/wag_source)
	RETURN_TYPE(/datum/dirt_masks)
	if(!wag_source)
		return null
	var/datum/dirt_masks/made = wag?.masks
	if(wag_source.shows_still || made?.shows_still || (!made && wag_source.frames == 1))
		return masks
	return made

/**
 * Returns the drawn parts that take dirt, each with its subtypes, and the DIRT_SHAPE_* define each takes it as. The
 * defines are for tails, for wings, and DIRT_SHAPE_PART for the rest, which take the field causes only
 * (dirt_shape_takes()). It's made on first use, so a proc static can hold it whatever order statics start in. You
 * should NEVER modify it.
 */
/proc/dirt_shape_kinds()
	RETURN_TYPE(/list)
	var/static/list/kinds
	kinds ||= zebra_typecacheof(list(
		/datum/bodypart_overlay/mutant/antennae = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/cat_ears = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/ears = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/fluff = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/frills = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/head_accessory = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/horns = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/mushroom_cap = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/neck_accessory = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/pod_hair = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/skrell_hair = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/snout = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/spines = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/synth_antenna = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/synth_screen = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/xenodorsal = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/xenohead = DIRT_SHAPE_PART,
		/datum/bodypart_overlay/mutant/wings = DIRT_SHAPE_WINGS,
		/datum/bodypart_overlay/mutant/tail = DIRT_SHAPE_TAIL,
	))
	return kinds

/**
 * Returns the DIRT_SHAPE_* define the part takes dirt as (dirt_shape_kinds()), or null for one that takes none of its
 * own: a genital, a taur body, body hair or markings.
 */
/datum/bodypart_overlay/mutant/proc/dirt_shape_kind()
	return dirt_shape_kinds()[type]

/**
 * Returns whether the part draws its wagging states now. Only a wagging tail does. While it wags, it draws its dirt
 * from its wag (dirt_shape_source_of()), and none while the wag is made. It draws the still sprite's dirt only where a
 * one-frame wag shows its pixels (/datum/dirt_drawing/proc/wag_shown()).
 */
/datum/bodypart_overlay/mutant/proc/dirt_wagging()
	return FALSE

/**
 * Returns the part as dirt reads it: each of its layers' images, as get_images() draws them (dirt_read_shape()).
 * Returns null when it takes no dirt, draws nothing, or sits on no canvas. It's read again when what get_images() reads
 * changes. A tail is read still, and separately wagging, as dirt_wag_frames() makes of it. Each read is kept until the
 * next. A still read can be given the part's own render key. Then the read is found again if the key, accessory and
 * limb's gender are as they were when it was last read or found (dirt_shape_own_read). That works because the key holds
 * the feature key, base state and sheet that the read's key is built from.
 *
 * Arguments:
 * - limb: The limb it's drawn on.
 * - wagged: Whether to read a tail wagging.
 * - own_key: For a still read of a part that isn't wagging, its own render key without its dirt, as icon_render_key()
 *   builds it; or null.
 */
/datum/bodypart_overlay/mutant/proc/dirt_shape_source_of(obj/item/bodypart/limb, wagged = FALSE, list/own_key = null)
	RETURN_TYPE(/datum/dirt_shape_source)
	// dirt_shape_own_read is noted only once a kind and an accessory were found, so the kind isn't looked up again
	if(own_key && !wagged && dirt_shape_own_read && dirt_shape_own_read[1] == sprite_datum && dirt_shape_own_read[2] == limb?.limb_gender && dirt_shape_own_read[3] ~= own_key)
		return dirt_shape
	var/kind = dirt_shape_kind()
	if(!kind || !sprite_datum)
		return null
	var/read_key = "[sprite_datum.type]|[get_feature_key_for_overlay()]|[get_base_icon_state()]|[limb?.limb_gender]|[sprite_datum.get_special_icon(limb?.owner, src)]"
	if(read_key == (wagged ? dirt_wag_read_key : dirt_shape_read_key))
		if(own_key && !wagged)
			dirt_shape_own_read = list(sprite_datum, limb?.limb_gender, own_key.Copy())
		return wagged ? dirt_wag_shape : dirt_shape
	var/datum/dirt_shape_source/read = dirt_read_shape(limb, kind)
	if(!wagged)
		dirt_shape_read_key = read_key
		dirt_shape = read
		// a render key noted before belonged to another read
		dirt_shape_own_read = own_key ? list(sprite_datum, limb?.limb_gender, own_key.Copy()) : null
		return read
	// the wag is told from the still sprite it moves
	var/datum/dirt_shape_source/still = read && dirt_shape_source_of(limb)
	dirt_wag_read_key = read_key
	dirt_wag_shape = still && dirt_wag_frames(read, still)
	return dirt_wag_shape

/**
 * Returns the part as get_images() draws it now, read for dirt: each of its layers' images, their states taken together
 * (a matrixed part's channel images). Its layers go lowest drawn first, on the canvas its sheet and offsets match
 * (dirt_canvas_of()). Returns null when it draws nothing or sits on no canvas (a sheet centred where the reference's
 * canvases aren't). A tail or wings on another canvas than their own take the field causes as any other part does.
 *
 * Arguments:
 * - limb: The limb it's drawn on.
 * - kind: Its DIRT_SHAPE_* define (dirt_shape_kind()).
 */
/datum/bodypart_overlay/mutant/proc/dirt_read_shape(obj/item/bodypart/limb, kind)
	RETURN_TYPE(/datum/dirt_shape_source)
	var/list/read = dirt_read_images(limb)
	var/mutable_appearance/first = read?[3]
	var/canvas = first && dirt_canvas_of(read[1], first.pixel_w, first.pixel_z)
	if(!canvas)
		return null
	var/list/stack = list()
	for(var/layer_key, layer_number in layers)
		// lowest drawn first, because the higher a layer's number, the lower it's drawn
		var/position = length(stack) + 1
		for(var/placed in 1 to length(stack))
			if(layers[stack[placed]] < layer_number)
				position = placed
				break
		stack.Insert(position, layer_key)
	if((kind == DIRT_SHAPE_TAIL && canvas != DIRT_CANVAS_TILE) || (kind == DIRT_SHAPE_WINGS && canvas != DIRT_CANVAS_WINGS))
		kind = DIRT_SHAPE_PART
	return new /datum/dirt_shape_source(read[1], read[2], stack, canvas, kind)

/**
 * Returns the part's images as get_images() draws them now, as dirt reads them. The result is list(the sheet the first
 * one is drawn from, alist(EXTERNAL_* layer key = the states drawn from it at that layer), that first image). Returns
 * null when none draws a sprite. A matrixed part's channel images are its states together. An image from another sheet
 * isn't read.
 *
 * Arguments:
 * - limb: The limb it's drawn on.
 */
/datum/bodypart_overlay/mutant/proc/dirt_read_images(obj/item/bodypart/limb)
	RETURN_TYPE(/list)
	var/sheet
	var/mutable_appearance/first
	var/alist/layer_states = alist()
	for(var/layer_key, layer_number in layers)
		for(var/mutable_appearance/drawn as anything in get_images(limb, layer_key, -layer_number))
			// a MOD suit's texture holder draws no sprite of its own
			if(!drawn.icon || !drawn.icon_state)
				continue
			first ||= drawn
			sheet ||= drawn.icon
			if(drawn.icon != sheet)
				continue
			LAZYADD(layer_states[layer_key], drawn.icon_state)
	return first ? list(sheet, layer_states, first) : null

/**
 * Returns the canvas a sheet drawn at some offsets sits on (dirt_canvases()), or null for none.
 *
 * Arguments:
 * - sheet: The sheet.
 * - pixel_w, pixel_z: Its images' offsets, as center_image() sets them.
 */
/proc/dirt_canvas_of(sheet, pixel_w, pixel_z)
	var/list/size = get_icon_dimensions(sheet)
	for(var/canvas, placed in dirt_canvases())
		var/list/canvas_size = placed
		if(canvas_size[1] == size["width"] && canvas_size[2] == size["height"] && canvas_size[3] == pixel_w && canvas_size[4] == pixel_z)
			return canvas
	return null

/**
 * Returns the organ slot the part's dirt is held under (/datum/component/dirtiness/var/part_splats), or null while it
 * holds none.
 *
 * Arguments:
 * - owner: Its owner.
 * - carrier: Their carrier, or null.
 */
/datum/bodypart_overlay/mutant/proc/dirt_shape_slot(mob/living/carbon/human/owner, datum/component/dirtiness/carrier)
	for(var/organ_slot in carrier?.part_splats)
		// get_organ_slot(), read from the slot list itself, because this runs on every key of a dirty body's parts
		var/obj/item/organ/organ = owner.organs_slot[organ_slot]
		if(organ?.bodypart_overlay == src)
			return organ_slot
	return null

/**
 * Adds a part's dirt to its images at one layer. One container just over them, at their layer and offsets, holds its
 * baked image, kept to the pixels that layer shows (dirt_container_over()). So it joins the layer's own holder and adds
 * no overlay to the mob. Its emissive blocker comes after it (dirt_emissive_blocker()), after the part's own glows and
 * blockers at that layer. A wagging tail's container holds its wag's dirt. It plays in step with the tail's wagging
 * images, because the same redraw draws them (/datum/component/dirtiness/proc/ready_wag_masks()). Every mutant part's
 * get_overlay() calls it. So a part that takes no dirt (dirt_shape_kinds()) leaves at the first check, before anything
 * else is read. A part on a person whose drawn parts hold none leaves after one lookup.
 *
 * Arguments:
 * - images: The part's images at the layer, as get_overlay() returns them, added to.
 * - limb: The limb it's drawn on.
 * - layer_index: The layer's EXTERNAL_* key.
 */
/datum/bodypart_overlay/mutant/proc/dirt_shape_overlay(list/images, obj/item/bodypart/limb, layer_index)
	var/static/list/kinds = dirt_shape_kinds()
	if(!kinds[type])
		return
	var/mob/living/carbon/human/owner = limb?.owner
	if(!length(images) || !istype(owner))
		return
	var/datum/component/dirtiness/carrier = owner.GetComponent(/datum/component/dirtiness)
	if(!length(carrier?.part_splats))
		return
	var/organ_slot = dirt_shape_slot(owner, carrier)
	// icon_render_key() asked for the masks before this draw with the same checks, so read what it found
	var/datum/dirt_shape_source/source = organ_slot && dirt_shape_source_of(limb)
	var/datum/dirt_drawing/drawing = source && carrier.part_drawings?[organ_slot]
	var/datum/dirt_masks/masks = drawing?.masks
	if(drawing && dirt_wagging())
		masks = drawing.wag_shown(dirt_shape_source_of(limb, TRUE))
	var/baked = masks?.baked_by_layer[layer_index]
	var/mutable_appearance/container = baked && dirt_container_over(images, baked)
	if(container)
		images[container] = NONE
		images[dirt_emissive_blocker(baked, limb, container)] = LIMB_OVERLAY_META

/**
 * Adds the key of a part's dirt's masks after DIRT_PRIVATE_KEY, or "pending" while they're made. Its limb's images then
 * follow the masks and stay on its own mob (limb_icons_for()). For a wagging tail, they're its wag's masks
 * (ready_wag_masks()). So the tail is drawn again as a wag starts and stops, and once its frames are made. Asking
 * queues masks not made yet. A still tail asks for no frames. It drops the job of the frames its dirt changed under,
 * unless its next wag would ask for the same. Every mutant part's icon_render_key() calls it, with
 * dirt_shape_overlay()'s first checks. A still part is read through its own render key (dirt_shape_source_of()).
 *
 * Arguments:
 * - key: The part's render key, as icon_render_key() returns it, added to.
 * - limb: The limb it's drawn on.
 */
/datum/bodypart_overlay/mutant/proc/dirt_shape_render_key(list/key, obj/item/bodypart/limb)
	var/static/list/kinds = dirt_shape_kinds()
	if(!kinds[type])
		return
	var/mob/living/carbon/human/owner = limb?.owner
	if(!istype(owner))
		return
	var/datum/component/dirtiness/carrier = owner.GetComponent(/datum/component/dirtiness)
	if(!length(carrier?.part_splats))
		return
	var/organ_slot = dirt_shape_slot(owner, carrier)
	if(!organ_slot)
		return
	var/wagging = dirt_wagging()
	// the key built so far is the part's own, and while the part is still it covers what the still read is drawn from
	var/datum/dirt_shape_source/source = dirt_shape_source_of(limb, FALSE, wagging ? null : key)
	if(!source)
		return
	var/datum/dirt_masks/masks = carrier.ready_shape_masks(organ_slot, source)
	var/datum/dirt_drawing/drawing = carrier.part_drawings?[organ_slot]
	if(wagging)
		masks = carrier.ready_wag_masks(organ_slot, dirt_shape_source_of(limb, TRUE))
	else if(drawing?.wag?.superseded_key && SSdirt.mask_jobs[drawing.wag.superseded_key])
		// frames still being made for dirt that's since changed
		carrier.ready_wag_masks(organ_slot, dirt_shape_source_of(limb, TRUE), ask = FALSE)
	key += "[DIRT_PRIVATE_KEY]dirt=[masks ? masks.key : "pending"]"

/**
 * Returns whether a kind of drawn part takes a general cause's dirt in a material. It never takes dirt in a material
 * that wets cloth. A tail takes the ground's dirt along its underside, and smoke, wear, machine work and kneeling as a
 * sparse film. It takes the field causes too: falls, splashes and full coverage (a plunge, a blast, a douse). Wings
 * take the same, with the ground's dirt and kneeling as two drips at level 3. They take slime from above or lain in on
 * the back too. Any other part takes the field causes only.
 *
 * Arguments:
 * - kind: DIRT_SHAPE_TAIL, DIRT_SHAPE_WINGS or DIRT_SHAPE_PART.
 * - cause: A DIRT_CAUSE_* define.
 * - material: Its /datum/dirt_material.
 */
/proc/dirt_shape_takes(kind, cause, datum/dirt_material/material)
	var/static/list/field_causes = list(DIRT_CAUSE_FALL, DIRT_CAUSE_SPLASH, DIRT_CAUSE_PLUNGE, DIRT_CAUSE_BLAST, DIRT_CAUSE_DOUSE)
	var/static/list/tail_causes = list(DIRT_CAUSE_FALL, DIRT_CAUSE_SPLASH, DIRT_CAUSE_PLUNGE, DIRT_CAUSE_BLAST, DIRT_CAUSE_DOUSE, DIRT_CAUSE_WALK, DIRT_CAUSE_CRAWL, DIRT_CAUSE_DUST, DIRT_CAUSE_KNEEL, DIRT_CAUSE_WEAR, DIRT_CAUSE_MACHINE, DIRT_CAUSE_SMOKE)
	var/static/list/wing_causes = list(DIRT_CAUSE_FALL, DIRT_CAUSE_SPLASH, DIRT_CAUSE_PLUNGE, DIRT_CAUSE_BLAST, DIRT_CAUSE_DOUSE, DIRT_CAUSE_WALK, DIRT_CAUSE_CRAWL, DIRT_CAUSE_DUST, DIRT_CAUSE_KNEEL, DIRT_CAUSE_WEAR, DIRT_CAUSE_MACHINE, DIRT_CAUSE_SMOKE, DIRT_CAUSE_SLIMED, DIRT_CAUSE_SLIMED_BACK)
	if(material.flags & DIRT_MATERIAL_WET)
		return FALSE
	switch(kind)
		if(DIRT_SHAPE_TAIL)
			return cause in tail_causes
		if(DIRT_SHAPE_WINGS)
			return cause in wing_causes
		if(DIRT_SHAPE_PART)
			return cause in field_causes
	return FALSE

/**
 * Returns the organ slots of a person's drawn parts that take a general cause's dirt in a material, each while it's
 * drawn. The taur body takes what reaches its lower half (dirt_taur_takes()). That's only when its kind has a back
 * (dirt_taur_takes_pools()) and no taur suit takes it in its place. Every other drawn part takes it by its kind's rules
 * (dirt_shape_takes()).
 *
 * Arguments:
 * - target: The person.
 * - cause: A DIRT_CAUSE_* define.
 * - material: Its /datum/dirt_material.
 * - taur_suited: Whether a taur suit takes the taur body's (dirt_taur_suit()).
 */
/proc/dirt_shape_slots(mob/living/carbon/human/target, cause, datum/dirt_material/material, taur_suited)
	RETURN_TYPE(/list)
	. = list()
	var/datum/component/dirtiness/own = target.GetComponent(/datum/component/dirtiness)
	if(!taur_suited && own && dirt_taur_takes(cause, material) && dirt_taur_takes_pools(target, own))
		. += ORGAN_SLOT_EXTERNAL_TAUR
	for(var/obj/item/organ/organ as anything in target.organs)
		var/datum/bodypart_overlay/mutant/overlay = organ.bodypart_overlay
		var/obj/item/bodypart/limb = organ.bodypart_owner
		if(!istype(overlay) || !limb || !overlay.dirt_shape_kind() || !overlay.can_draw_on_bodypart(limb, target))
			continue
		var/datum/dirt_shape_source/source = overlay.dirt_shape_source_of(limb)
		if(source && dirt_shape_takes(source.kind, cause, material))
			. += organ.slot

/**
 * Returns a general deposit on a drawn shape in one direction, by the shape's own rules, as the reference generator
 * draws each. A taur body takes a contact coat from the ground (crawling coats as walking), on its fur or on the cloth
 * of a taur suit over it. It takes slime in its own pixels and a douse along its own top edges. The rest comes from the
 * canvas field, as fur, or as a taur suit's cloth. A tail draws by dirt_tail_rasterise(), wings by
 * dirt_wing_rasterise(), and any other part from the field (dirt_shape_rasterise()). Each draws inside its own drafting.
 *
 * Arguments:
 * - source: The shape.
 * - owners: What each pixel of its canvas shows in that direction, from dirt_taur_owners(). The shape's pixels are
 *   those its layers show, with the rider's left out.
 * - cause: A DIRT_CAUSE_* define.
 * - material: The /datum/dirt_material it's made of.
 * - level: The deposit's level.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - direction: The direction.
 * - surface_kind: DIRT_SURFACE_FUR, or DIRT_SURFACE_CLOTH for a taur suit.
 * - side: The person's dirtier side, 1 or -1.
 */
/proc/dirt_shape_deposit(datum/dirt_shape_source/source, list/owners, cause, datum/dirt_material/material, level, variant, direction, surface_kind, side)
	RETURN_TYPE(/datum/dirt_pixels)
	var/alist/mask = dirt_shape_mask(owners)
	switch(source.kind)
		if(DIRT_SHAPE_TAUR)
			if(copytext(cause, 1, length(DIRT_CAUSE_SLIMED) + 1) == DIRT_CAUSE_SLIMED)
				return dirt_splat_rasterise(mask, cause, material, level, variant, DIRT_SHAPE_TAUR, direction, side)
			if(cause == DIRT_CAUSE_DOUSE)
				return dirt_douse_rasterise(mask, material, level, variant, source.canvas, direction)
			var/coat_cause = dirt_taur_coat_cause(cause)
			if(coat_cause)
				return dirt_taur_coat(source, coat_cause, material, level, variant, direction)
			return dirt_canvas_rasterise(cause, material, level, variant, source.canvas, direction, surface_kind, side)
		if(DIRT_SHAPE_TAIL)
			return dirt_tail_rasterise(mask, cause, material, level, variant, direction, ICON_SIZE_Y - 1, side)
		if(DIRT_SHAPE_WINGS)
			return dirt_wing_rasterise(mask, cause, material, level, variant, direction, side)
	return dirt_shape_rasterise(mask, cause, material, level, variant, source.canvas, direction, DIRT_SURFACE_FUR, side)

/**
 * Returns the direction a general deposit's canvas field is drawn facing on a kind of shape seen one way. It's for a
 * shape that takes the deposit from that field (dirt_shape_deposit(), the hair's dirt_shape_rasterise()). Returns null
 * where it draws the deposit otherwise. A tail's field faces north whichever way the tail is seen
 * (dirt_tail_rasterise()), so one field serves all four directions. The other shapes' fields face the way they're seen,
 * one for each direction. A tail, wings and any other part take a fall, a splash, a plunge and a blast from the field.
 * The hair takes all it takes from it but a douse and slime. A taur body takes all it takes from it but slime, a douse
 * and the ground's coat (dirt_taur_coat()). A douse follows the shape's own top edges, so that field never draws it.
 *
 * Arguments:
 * - kind: The shape's DIRT_SHAPE_* define.
 * - cause: A DIRT_CAUSE_* define.
 * - direction: The direction it's seen from.
 */
/proc/dirt_shape_field_facing(kind, cause, direction)
	var/slime = copytext(cause, 1, length(DIRT_CAUSE_SLIMED) + 1) == DIRT_CAUSE_SLIMED
	switch(kind)
		if(DIRT_SHAPE_HAIR)
			return (slime || cause == DIRT_CAUSE_DOUSE) ? null : direction
		if(DIRT_SHAPE_TAUR)
			if(slime || cause == DIRT_CAUSE_DOUSE || dirt_taur_coat_cause(cause))
				return null
			return direction
	if(cause != DIRT_CAUSE_FALL && cause != DIRT_CAUSE_SPLASH && cause != DIRT_CAUSE_PLUNGE && cause != DIRT_CAUSE_BLAST)
		return null
	switch(kind)
		if(DIRT_SHAPE_TAIL)
			return NORTH
		if(DIRT_SHAPE_PART, DIRT_SHAPE_WINGS)
			return direction
	return null

/// Whether the tail wags (/datum/bodypart_overlay/mutant/proc/dirt_wagging()).
/datum/bodypart_overlay/mutant/tail/dirt_wagging()
	return wagging

/// Reads the tail still, so a wag never makes its still masks again, or reads it wagging for its wag.
/datum/bodypart_overlay/mutant/tail/dirt_shape_source_of(obj/item/bodypart/limb, wagged = FALSE, list/own_key = null)
	RETURN_TYPE(/datum/dirt_shape_source)
	var/was_wagging = wagging
	wagging = wagged
	// a runtime mustn't leave a tail drawn otherwise than it wags
	try
		. = ..()
	catch(var/exception/error)
		wagging = was_wagging
		throw error
	wagging = was_wagging

/**
 * Reads the frills as no shape while a hat's hair masks draw them. Then they're drawn from an icon made at run time,
 * which dirt can't read. The read kept from before the hat is left as it is, so it holds again once the hat comes off.
 */
/datum/bodypart_overlay/mutant/frills/dirt_shape_source_of(obj/item/bodypart/limb, wagged = FALSE, list/own_key = null)
	RETURN_TYPE(/datum/dirt_shape_source)
	if(LAZYLEN(limb?.owner?.hair_masks))
		return null
	return ..()

/**
 * A tail's sprite read wagging, with its states animated. Each frame is read as it's made, from sprites its job holds
 * (dirt_frame_owners()). Each takes the still sprite's dirt, carried along the tail (/datum/dirt_tail_carry), and is
 * baked into one animated icon for each layer (/datum/dirt_mask_job/proc/bake_frame()). The source is made once. Only
 * shows_still changes, once a job finds it out.
 */
/datum/dirt_wag_source
	parent_type = /datum/dirt_shape_source
	/// alist(state = its frame count).
	var/alist/state_frames
	/// alist(EXTERNAL_* layer key = list(each frame's delay, whether it rewinds)), from the layer's state with the most
	/// frames, so its dirt plays as that state does.
	var/alist/layer_frames
	/// The most frames a layer has, which is how many frames are made.
	var/frames
	/// The part read still. Every frame takes its dirt, carried along it, or as it is where a frame shows its pixels.
	var/datum/dirt_shape_source/still
	/// Whether its one frame shows the still sprite's pixels in every direction, once a job has found it does. If so,
	/// the still masks draw while it wags, and no job is asked for.
	var/shows_still = FALSE

/**
 * Returns what the wag's frames and its still sprite draw, as text. SSdirt.wag_sprites keeps what its frames show under
 * this key (/datum/dirt_mask_job/var/sprite_frames). Wags with the same key show the same pixels in every frame,
 * whatever their dirt or colours.
 */
/datum/dirt_wag_source/proc/sprite_key()
	return "[shape_key()]|[jointext(stack, ",")]>[still.shape_key()]|[jointext(still.stack, ",")]>[canvas]"

/**
 * Returns a part's wag as dirt draws it, from its sprite read wagging and still: a /datum/dirt_wag_source of its
 * frames, from its sheet's DMI metadata. Its job finds out, a piece at a time, whether a one-frame wag shows the still
 * sprite's pixels, so the still masks draw. Returns null for a sheet made at run time, whose frames can't be read.
 * Returns null too for a wag on another canvas than the still sprite's, because its frames can't be carried from it.
 * Either way, it draws no dirt while it wags.
 *
 * Arguments:
 * - read: The part read wagging.
 * - still: The part read still.
 */
/proc/dirt_wag_frames(datum/dirt_shape_source/read, datum/dirt_shape_source/still)
	RETURN_TYPE(/datum/dirt_wag_source)
	if(read.canvas != still.canvas)
		return null
	var/list/states_data = icon_metadata(read.icon)?["states"]
	if(!states_data)
		return null
	var/alist/layer_of = alist()
	for(var/layer_key, states in read.layer_states)
		for(var/state in states)
			layer_of[state] = layer_key
	var/alist/state_frames = alist()
	var/alist/layer_frames = alist()
	var/frames = 1
	for(var/list/state_data as anything in states_data)
		var/layer_key = layer_of[state_data["name"]]
		if(!layer_key)
			continue
		var/list/delays = state_data["delay"]
		if(!length(delays))
			delays = list(1)
		state_frames[state_data["name"]] = length(delays)
		var/list/held = layer_frames[layer_key]
		if(!held || length(delays) > length(held[1]))
			layer_frames[layer_key] = list(delays, !!state_data["rewind"])
		frames = max(frames, length(delays))
	var/datum/dirt_wag_source/wag = new(read.icon, read.layer_states, read.stack, read.canvas, read.kind)
	wag.state_frames = state_frames
	wag.layer_frames = layer_frames
	wag.frames = frames
	wag.still = still
	return wag

/**
 * Returns what each pixel of a wag's canvas shows in one direction at one frame, as dirt_taur_owners() gives a still
 * sprite's. Each state is read at that frame as dirt_sprite_pixels() reads a still one, and a state with fewer frames
 * shows its last. Each state's sprite is loaded once into the job's own `sheets`, and never kept in
 * SSdirt.sprite_reads, which holds still sprites.
 *
 * Arguments:
 * - source: The wag.
 * - direction: The direction.
 * - frame: The frame, from 1.
 * - sheets: alist(state = its sprite, every frame), the job's, added to.
 */
/proc/dirt_frame_owners(datum/dirt_wag_source/source, direction, frame, alist/sheets)
	RETURN_TYPE(/list)
	var/list/size = dirt_canvases()[source.canvas]
	var/width = size[1]
	var/height = size[2]
	var/list/owners = new /list(width * height)
	for(var/shown in source.stack)
		for(var/state in source.layer_states[shown])
			var/icon/sprite = sheets[state]
			if(!sprite)
				sprite = icon(source.icon, state)
				sheets[state] = sprite
			if(sprite.Width() != width || sprite.Height() != height)
				continue
			var/state_frame = min(frame, source.state_frames[state] || 1)
			for(var/row in 0 to height - 1)
				for(var/column in 0 to width - 1)
					if(sprite.GetPixel(column + 1, height - row, null, direction, state_frame))
						owners[row * width + column + 1] = shown
	return owners

/**
 * Returns where each pixel of a tail, or another part that wags, lies on it in one direction, as list(along, across,
 * steps, root). It's worked out from what each pixel of its canvas shows (dirt_taur_owners(), dirt_frame_owners()),
 * with its layers taken together.
 * - along: How far along it the pixel lies from where it joins the body, 0 there to 1 at its far end. That's each
 *   pixel's distance inside it (dirt_tail_spread()) from its root and the pixels beside the root, over the longest. A
 *   piece the rest doesn't reach (drawn apart, as either side of the body) goes on from its own pixel nearest the join.
 *   That pixel is as far along as it lies from the root.
 * - across: Where across it the pixel lies at that distance, -1 to 1, on the same side of it whichever way it bends.
 * - steps: How many pixels long it is.
 * - root: The pixel it's measured from. For a wag frame, that's the pixel beside its still sprite's root (still_root),
 *   as a tail's base doesn't move as it wags. Otherwise it's its pixel nearest the join. That's the hips
 *   (DIRT_TAIL_ROOT_UP over the floor, at the tile's middle). On the taur canvas, where only taurs' tails wag, it's the
 *   taur's rump (DIRT_TAUR_RUMP_BACK, DIRT_TAUR_RUMP_UP).
 * along and across are indexed by the canvas's pixels, and are null off the shape.
 *
 * Arguments:
 * - owners: What each pixel of the canvas shows.
 * - canvas: The DIRT_CANVAS_* define.
 * - direction: The direction it's seen from.
 * - still_root: For a wag frame, its still sprite's root in that direction, or null.
 */
/proc/dirt_tail_coordinates(list/owners, canvas, direction, still_root = null)
	RETURN_TYPE(/list)
	var/list/size = dirt_canvases()[canvas]
	var/width = size[1]
	var/height = size[2]
	var/count = length(owners)
	var/join_column = 15.5 - size[3]
	var/join_row = height - 1 - DIRT_TAIL_ROOT_UP + size[4]
	if(canvas == DIRT_CANVAS_TAUR)
		join_column += direction == EAST ? -DIRT_TAUR_RUMP_BACK : (direction == WEST ? DIRT_TAUR_RUMP_BACK : 0)
		join_row = height - 1 - DIRT_TAUR_RUMP_UP + size[4]
	var/list/shape = list()
	for(var/index in 1 to count)
		if(owners[index] && owners[index] != DIRT_TAUR_RIDER)
			shape += index
	var/list/along = new /list(count)
	var/list/across = new /list(count)
	var/list/distances = new /list(count)
	var/list/pieces = new /list(count)
	var/piece = 0
	var/root
	var/root_column
	var/root_row
	if(still_root)
		var/still_row = floor((still_root - 1) / width)
		var/still_column = still_root - 1 - still_row * width
		var/root_reach = INFINITY
		for(var/index in shape)
			var/row = floor((index - 1) / width)
			var/reach = (index - 1 - row * width - still_column) ** 2 + (row - still_row) ** 2
			// beside it: a step across, down or diagonal
			if(reach <= 2 && reach < root_reach)
				root = index
				root_reach = reach
	for(var/turn in 1 to length(shape))
		// the root, or the pixel nearest the join that no piece reaches yet
		var/start = !piece && root
		if(!start)
			var/start_reach = INFINITY
			for(var/index in shape)
				var/row = floor((index - 1) / width)
				var/reach = (index - 1 - row * width - join_column) ** 2 + (row - join_row) ** 2
				if(!pieces[index] && reach < start_reach)
					start = index
					start_reach = reach
		if(!start)
			break
		piece++
		var/list/seeds = list(start)
		var/base = 0
		var/start_row = floor((start - 1) / width)
		var/start_column = start - 1 - start_row * width
		if(piece > 1)
			base = round(2 * sqrt((start_column - root_column) ** 2 + (start_row - root_row) ** 2), 1)
		else
			root = start
			root_column = start_column
			root_row = start_row
			// the root and the pixels beside it
			for(var/near_row in max(0, start_row - 1) to min(height - 1, start_row + 1))
				for(var/near_column in max(0, start_column - 1) to min(width - 1, start_column + 1))
					var/near = near_row * width + near_column + 1
					if(near != start && owners[near] && owners[near] != DIRT_TAUR_RIDER)
						seeds += near
		dirt_tail_spread(owners, canvas, seeds, base, piece, distances, pieces)
	var/longest = 0
	for(var/index in shape)
		longest = max(longest, distances[index])
	var/steps = round(longest / 2, 1)
	// each piece's pixels in bands a pixel along apart, at (piece - 1) * band_count + band_place + 1, with their
	// columns and rows summed and how many there are
	var/band_count = steps + 1
	var/list/band_columns = new /list(piece * band_count)
	var/list/band_rows = new /list(piece * band_count)
	var/list/band_sizes = new /list(piece * band_count)
	var/list/band_of = new /list(count)
	for(var/index in shape)
		var/band = (pieces[index] - 1) * band_count + round(distances[index] / 2, 1) + 1
		band_of[index] = band
		var/row = floor((index - 1) / width)
		band_columns[band] += index - 1 - row * width
		band_rows[band] += row
		band_sizes[band] += 1
	// across each band is the way along the tail there, from two bands before to two after, turned a quarter
	var/list/across_columns = new /list(length(band_sizes))
	var/list/across_rows = new /list(length(band_sizes))
	for(var/band in 1 to length(band_sizes))
		if(!band_sizes[band])
			continue
		var/band_place = (band - 1) % band_count
		var/before = band
		var/after = band
		for(var/reach in 2 to 1 step -1)
			if(before == band && band_place >= reach && band_sizes[band - reach])
				before = band - reach
			if(after == band && band_place + reach < band_count && band_sizes[band + reach])
				after = band + reach
		var/way_column = band_columns[after] / band_sizes[after] - band_columns[before] / band_sizes[before]
		var/way_row = band_rows[after] / band_sizes[after] - band_rows[before] / band_sizes[before]
		var/way = sqrt(way_column ** 2 + way_row ** 2) || 1
		across_columns[band] = -way_row / way
		across_rows[band] = way_column / way
	var/list/widest = new /list(length(band_sizes))
	for(var/index in shape)
		var/band = band_of[index]
		var/row = floor((index - 1) / width)
		var/offset = (index - 1 - row * width - band_columns[band] / band_sizes[band]) * across_columns[band] + (row - band_rows[band] / band_sizes[band]) * across_rows[band]
		across[index] = offset
		widest[band] = max(widest[band] || 0, abs(offset))
	for(var/index in shape)
		var/band_widest = widest[band_of[index]]
		across[index] = band_widest >= 0.5 ? across[index] / band_widest : 0
		along[index] = longest ? distances[index] / longest : 0
	return list(along, across, steps, root)

/**
 * Spreads the distances inside a shape for one of its pieces, out from where the piece starts
 * (dirt_tail_coordinates()). They spread over the shape's pixels that no piece reaches yet. It changes distances and
 * pieces. A step across or down adds 2, and a diagonal one adds 3.
 *
 * Arguments:
 * - owners: What each pixel of the canvas shows.
 * - canvas: The DIRT_CANVAS_* define.
 * - seeds: The piece's first pixels, each at `base`.
 * - base: Their distance.
 * - piece: The piece's number.
 * - distances: Each pixel's distance, by index.
 * - pieces: Each pixel's piece, by index.
 */
/proc/dirt_tail_spread(list/owners, canvas, list/seeds, base, piece, list/distances, list/pieces)
	var/list/size = dirt_canvases()[canvas]
	var/width = size[1]
	var/height = size[2]
	// distance + 1 -> the pixels reached at it, each taken once it's the nearest left
	var/list/reached = new /list(base + 1)
	reached[base + 1] = seeds.Copy()
	for(var/seed in seeds)
		distances[seed] = base
	// a pixel lies at most 3 past the one it's reached from
	for(var/distance in base to base + 3 * length(owners))
		if(distance >= length(reached))
			break
		var/list/at_distance = reached[distance + 1]
		for(var/index in at_distance)
			if(pieces[index] || distances[index] != distance)
				continue
			pieces[index] = piece
			var/row = floor((index - 1) / width)
			var/column = index - 1 - row * width
			for(var/near_row in max(0, row - 1) to min(height - 1, row + 1))
				for(var/near_column in max(0, column - 1) to min(width - 1, column + 1))
					var/near = near_row * width + near_column + 1
					var/shown = owners[near]
					if(!shown || shown == DIRT_TAUR_RIDER || pieces[near])
						continue
					var/further = distance + (near_row != row && near_column != column ? 3 : 2)
					if(!isnull(distances[near]) && distances[near] <= further)
						continue
					distances[near] = further
					if(length(reached) <= further)
						reached.len = further + 1
					var/list/later = reached[further + 1]
					if(!later)
						later = list()
						reached[further + 1] = later
					later += near

/**
 * A wag frame's dirt carried from the still sprite's in one direction, some of its pixels at a time (carry_pixels()).
 * Each pixel of the frame's shape takes the dirt of the still's pixel nearest it along the shape and across it
 * (dirt_tail_coordinates()). It takes none where that pixel has none. So the dirt swings and bends with the tail and
 * draws as it does when the tail is still. The still's pixels are looked through a pixel along at a time, out from the
 * frame pixel's place. The look stops one past the first of those that holds any, because one further across can lie
 * nearer.
 */
/datum/dirt_tail_carry
	/// The frame's dirt so far.
	var/datum/dirt_pixels/carried
	/// The still's dirt in that direction.
	var/datum/dirt_pixels/still_merged
	/// dirt_tail_coordinates() of the still sprite in that direction.
	var/list/still_coordinates
	/// dirt_tail_coordinates() of the frame, measured from beside the still's root.
	var/list/frame_coordinates
	/// The still's pixels by how far along it they lie: pixels along + 1 -> the still's pixels there.
	var/list/bands
	/// The next pixel of the canvas to carry, from 1.
	var/next_index = 1
	/// For each frame pixel by index, the still pixel it takes the dirt of, or null where none is near. It's what the
	/// wag's sprites keep of the carry (dirt_wag_pack()), whatever the dirt.
	var/list/sources

/**
 * Arguments:
 * - frame_owners: What each pixel of the canvas shows at the frame.
 * - still_coordinates: dirt_tail_coordinates() of the still sprite in that direction.
 * - still_merged: The still's dirt in that direction.
 * - canvas: The DIRT_CANVAS_* define.
 * - direction: The direction.
 */
/datum/dirt_tail_carry/New(list/frame_owners, list/still_coordinates, datum/dirt_pixels/still_merged, canvas, direction)
	. = ..()
	src.still_coordinates = still_coordinates
	src.still_merged = still_merged
	carried = new(still_merged.width, still_merged.height)
	if(still_merged.materials)
		carried.materials = new /list(length(still_merged.roles))
	sources = new /list(length(still_merged.roles))
	var/list/still_along = still_coordinates[1]
	var/steps = max(1, still_coordinates[3])
	bands = new /list(steps + 1)
	for(var/index in 1 to length(still_along))
		if(isnull(still_along[index]))
			continue
		var/band = round(still_along[index] * steps, 1) + 1
		var/list/at_band = bands[band]
		if(!at_band)
			at_band = list()
			bands[band] = at_band
		at_band += index
	frame_coordinates = dirt_tail_coordinates(frame_owners, canvas, direction, still_coordinates[4])

/**
 * Carries the frame's next pixels, `count` of them at most, in the canvas's order.
 *
 * Arguments:
 * - count: The most pixels to carry.
 *
 * Returns whether every pixel is carried.
 */
/datum/dirt_tail_carry/proc/carry_pixels(count)
	var/list/still_along = still_coordinates[1]
	var/list/still_across = still_coordinates[2]
	var/steps = max(1, still_coordinates[3])
	var/list/still_bands = bands
	var/list/frame_along = frame_coordinates[1]
	var/list/frame_across = frame_coordinates[2]
	var/list/roles = still_merged.roles
	var/list/thicknesses = still_merged.thicknesses
	var/list/materials = still_merged.materials
	var/left = count
	for(var/index in next_index to length(frame_along))
		var/position = frame_along[index]
		if(isnull(position))
			continue
		if(left <= 0)
			next_index = index
			return FALSE
		left--
		var/home = round(position * steps, 1) + 1
		var/nearest
		var/nearest_cost = INFINITY
		// a tie goes to the still's own pixel there, so a frame drawing the still's shape draws its dirt as it is
		if(!isnull(still_along[index]))
			nearest = index
			nearest_cost = ((still_along[index] - position) * steps) ** 2 + (still_across[index] - frame_across[index]) ** 2
		// how far out the first of the still's pixels lay
		var/found_reach
		for(var/reach in 0 to steps)
			// home alone, then a band either side
			var/stride = max(1, 2 * reach)
			for(var/band in home - reach to home + reach step stride)
				if(band < 1 || band > steps + 1)
					continue
				for(var/still_index in still_bands[band])
					if(isnull(found_reach))
						found_reach = reach
					var/cost = ((still_along[still_index] - position) * steps) ** 2 + (still_across[still_index] - frame_across[index]) ** 2
					if(cost < nearest_cost)
						nearest = still_index
						nearest_cost = cost
			if(!isnull(found_reach) && reach > found_reach)
				break
		sources[index] = nearest
		if(nearest && roles[nearest])
			carried.put_index(index, roles[nearest], thicknesses[nearest])
			if(materials)
				carried.materials[index] = materials[nearest]
	return TRUE

/**
 * Returns a frame's pixels or a still sprite's, packed as text as SSdirt.wag_sprites keeps them. Each pixel of the
 * shape, in the canvas's order, gives its index in two digits and its layer's place in the stack in one. A frame's
 * pixel then gives its carry's still pixel in two (0 for none). The digits are in base 64, "0" to "o" (ASCII 48 to
 * 111), as drawn() writes them. dirt_wag_owners() and dirt_wag_carried() give its pixels and carry back as they were.
 *
 * Arguments:
 * - owners: What each pixel of the canvas shows (dirt_taur_owners(), dirt_frame_owners()).
 * - stack: The layer keys it shows, its source's stack.
 * - sources: For a frame, each pixel's still pixel (/datum/dirt_tail_carry/var/sources), or null for a still sprite.
 */
/proc/dirt_wag_pack(list/owners, list/stack, list/sources)
	var/static/list/digits
	if(!digits)
		digits = list()
		for(var/digit in 0 to 63)
			digits += ascii2text(48 + digit)
	var/alist/places = alist()
	for(var/place in 1 to length(stack))
		places[stack[place]] = digits[place + 1]
	var/list/chars = list()
	for(var/index in 1 to length(owners))
		var/shown = owners[index]
		if(!shown)
			continue
		chars += digits[floor(index / 64) + 1]
		chars += digits[index % 64 + 1]
		chars += places[shown]
		if(sources)
			var/source = sources[index] || 0
			chars += digits[floor(source / 64) + 1]
			chars += digits[source % 64 + 1]
	return jointext(chars, "")

/**
 * Returns what each pixel of a canvas shows, from a frame's or a still sprite's packed pixels (dirt_wag_pack()), as
 * dirt_frame_owners() or dirt_taur_owners() read them.
 *
 * Arguments:
 * - packed: The packed pixels.
 * - stack: The layer keys it shows, its source's stack.
 * - count: How many pixels the canvas has.
 * - carried: Whether it's a frame's, packed with its carry.
 */
/proc/dirt_wag_owners(packed, list/stack, count, carried)
	RETURN_TYPE(/list)
	var/list/owners = new /list(count)
	var/stride = carried ? 5 : 3
	for(var/pixel in 0 to length(packed) / stride - 1)
		var/position = pixel * stride + 1
		owners[(text2ascii(packed, position) - 48) * 64 + text2ascii(packed, position + 1) - 48] = stack[text2ascii(packed, position + 2) - 48]
	return owners

/**
 * Returns a wag frame's dirt carried from the still sprite's in one direction, as /datum/dirt_tail_carry carried it, by
 * the still pixel each of the frame's pixels takes (dirt_wag_pack()).
 *
 * Arguments:
 * - packed: The frame's pixels packed with its carry.
 * - still_merged: The still's dirt in that direction.
 */
/proc/dirt_wag_carried(packed, datum/dirt_pixels/still_merged)
	RETURN_TYPE(/datum/dirt_pixels)
	var/datum/dirt_pixels/carried = new(still_merged.width, still_merged.height)
	var/list/roles = still_merged.roles
	var/list/thicknesses = still_merged.thicknesses
	var/list/materials = still_merged.materials
	if(materials)
		carried.materials = new /list(length(roles))
	for(var/pixel in 0 to length(packed) / 5 - 1)
		var/position = pixel * 5 + 1
		var/nearest = (text2ascii(packed, position + 3) - 48) * 64 + text2ascii(packed, position + 4) - 48
		if(nearest && roles[nearest])
			var/index = (text2ascii(packed, position) - 48) * 64 + text2ascii(packed, position + 1) - 48
			carried.put_index(index, roles[nearest], thicknesses[nearest])
			if(materials)
				carried.materials[index] = materials[nearest]
	return carried

#undef DIRT_TAIL_ROOT_UP
#undef DIRT_TAUR_RUMP_BACK
#undef DIRT_TAUR_RUMP_UP
