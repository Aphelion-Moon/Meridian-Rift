// Shiptest neckwear, and the hoods of the wardrobe's hooded garments, all cosmetic - no armour
/obj/item/clothing/neck/shiptest
	abstract_type = /obj/item/clothing/neck/shiptest

/obj/item/clothing/neck/shiptest/cloak
	abstract_type = /obj/item/clothing/neck/shiptest/cloak
	body_parts_covered = CHEST|GROIN|LEGS|ARMS
	flags_inv = HIDESUITSTORAGE

/obj/item/clothing/head/hooded/shiptest/cropped_hoodie
	abstract_type = /obj/item/clothing/head/hooded/shiptest/cropped_hoodie

/obj/item/clothing/head/hooded/shiptest/hoodie
	abstract_type = /obj/item/clothing/head/hooded/shiptest/hoodie

/obj/item/clothing/head/hooded/shiptest/poncho
	abstract_type = /obj/item/clothing/head/hooded/shiptest/poncho

/obj/item/clothing/head/hooded/shiptest/survivor_suit
	abstract_type = /obj/item/clothing/head/hooded/shiptest/survivor_suit

/obj/item/clothing/head/hooded/shiptest/winter_coat
	abstract_type = /obj/item/clothing/head/hooded/shiptest/winter_coat

/obj/item/clothing/neck/shiptest/cloak/rank_cape
	abstract_type = /obj/item/clothing/neck/shiptest/cloak/rank_cape

/obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape
	abstract_type = /obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape

/obj/item/clothing/neck/shiptest/cloak/sash
	abstract_type = /obj/item/clothing/neck/shiptest/cloak/sash

/obj/item/clothing/neck/shiptest/hooded_cape
	abstract_type = /obj/item/clothing/neck/shiptest/hooded_cape

/obj/item/clothing/neck/shiptest/mantle
	abstract_type = /obj/item/clothing/neck/shiptest/mantle

/obj/item/clothing/neck/shiptest/neckwraps
	abstract_type = /obj/item/clothing/neck/shiptest/neckwraps

/obj/item/clothing/neck/shiptest/scarf
	abstract_type = /obj/item/clothing/neck/shiptest/scarf

/obj/item/clothing/neck/shiptest/shemagh
	parent_type = /obj/item/clothing/mask
	abstract_type = /obj/item/clothing/neck/shiptest/shemagh
	slot_flags = ITEM_SLOT_NECK
	body_parts_covered = NECK
	supports_variations_flags = NONE
	/// Whether it is tied as a face wrap
	var/is_mask = FALSE

/obj/item/clothing/neck/shiptest/shemagh/examine(mob/user)
	. = ..()
	. += span_notice("Use it in hand to wear it as a [is_mask ? "neck scarf" : "face wrap"].")

// Like tg's bandanas, tying moves it to another slot without replacing it. Alt-click opens its styles, so we tie it
// in hand
/obj/item/clothing/neck/shiptest/shemagh/attack_self(mob/user)
	. = ..()
	if(.)
		return
	if(!iscarbon(user) || !user.can_perform_action(src))
		return FALSE
	if(!user.is_holding(src))
		balloon_alert(user, "hold it first!")
		return FALSE
	is_mask = !is_mask
	slot_flags = is_mask ? ITEM_SLOT_MASK : ITEM_SLOT_NECK
	body_parts_covered = is_mask ? HEAD : NECK
	flags_inv = is_mask ? HIDEEARS|HIDEHAIR|HIDEFACIALHAIR|HIDEFACE : NONE
	flags_cover = is_mask ? MASKCOVERSMOUTH : NONE
	update_appearance(UPDATE_ICON)
	update_slot_icon()
	balloon_alert(user, is_mask ? "tied into face wrap" : "untied into scarf")
	return TRUE

/obj/item/clothing/neck/shiptest/shemagh/update_icon_state()
	. = ..()
	// A family style moves the base state, so we tie from that rather than the type's own
	icon_state = "[BASE_OR_INITIAL_ICON_STATE(src)][is_mask ? "_over" : ""]"

/obj/item/clothing/neck/shiptest/pride_tie
	parent_type = /obj/item/clothing/neck/tie
	abstract_type = /obj/item/clothing/neck/shiptest/pride_tie
	clip_on = TRUE
	post_init_icon_state = null
	greyscale_config = null
	greyscale_config_worn = null
	greyscale_colors = null
	flags_1 = NONE

// Shiptest drew the dogtags for the inventory only, so we show nothing worn
/obj/item/clothing/neck/shiptest/dogtag
	abstract_type = /obj/item/clothing/neck/shiptest/dogtag
	slot_flags = ITEM_SLOT_NECK|ITEM_SLOT_POCKETS

/obj/item/clothing/neck/shiptest/dogtag/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_WORN_ICON, INNATE_TRAIT)

/obj/item/clothing/neck/shiptest/poncho
	abstract_type = /obj/item/clothing/neck/shiptest/poncho
	body_parts_covered = CHEST
	/// The hood the poncho puts up
	var/hoodtype

/obj/item/clothing/neck/shiptest/poncho/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/toggle_attached_clothing,\
		deployable_type = hoodtype,\
		equipped_slot = ITEM_SLOT_HEAD,\
		action_name = "Toggle Hood",\
		parent_icon_state_suffix = "_t",\
		auto_deploy_on_outfit_equip = FALSE,\
		on_created = CALLBACK(src, PROC_REF(on_shiptest_hood_created)),\
	)

// The hood wears the poncho's colours, also when the poncho makes it again
/obj/item/clothing/neck/shiptest/poncho/proc/on_shiptest_hood_created(obj/item/created_hood)
	shiptest_hood_follows(src)

/obj/item/clothing/neck/shiptest/poncho/update_greyscale()
	. = ..()
	shiptest_hood_follows(src)

/obj/item/clothing/neck/shiptest/cloak/rank_cape/black
	name = "black rank cape"
	desc = "A flowing black cape with a military cut."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "rank_cape_black"
	inhand_icon_state = "bl_suit"
	lefthand_file = 'icons/mob/inhands/clothing/suits_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/clothing/suits_righthand.dmi'

/obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/black
	parent_type = /obj/item/clothing/neck/shiptest/cloak/rank_cape/black
	name = "black rank shoulder cape"
	desc = "A folded black cape draped across one shoulder."
	icon_state = "rank_shoulder_cape_black"

/obj/item/clothing/neck/shiptest/cloak/rank_cape/captain
	parent_type = /obj/item/clothing/neck/shiptest/cloak/rank_cape/black
	name = "captain's rank cape"
	desc = "A flowing black cape with a captain's insignia."
	icon_state = "rank_cape_captain"

/obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/captain
	parent_type = /obj/item/clothing/neck/shiptest/cloak/rank_cape/captain
	name = "captain's rank shoulder cape"
	icon_state = "rank_shoulder_cape_captain"

/obj/item/clothing/neck/shiptest/cloak/rank_cape/command
	parent_type = /obj/item/clothing/neck/shiptest/cloak/rank_cape/black
	name = "command rank cape"
	desc = "A flowing black cape with an officer's insignia."
	icon_state = "rank_cape_command"

/obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/command
	parent_type = /obj/item/clothing/neck/shiptest/cloak/rank_cape/command
	name = "command rank shoulder cape"
	icon_state = "rank_shoulder_cape_command"

/obj/item/clothing/neck/shiptest/cloak/rank_cape/engineering
	parent_type = /obj/item/clothing/neck/shiptest/cloak/rank_cape/black
	name = "engineering rank cape"
	desc = "A flowing black cape with an engineering insignia."
	icon_state = "rank_cape_engineering"

/obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/engineering
	parent_type = /obj/item/clothing/neck/shiptest/cloak/rank_cape/engineering
	name = "engineering rank shoulder cape"
	icon_state = "rank_shoulder_cape_engineering"

/obj/item/clothing/neck/shiptest/cloak/rank_cape/medic
	parent_type = /obj/item/clothing/neck/shiptest/cloak/rank_cape/black
	name = "medic rank cape"
	desc = "A flowing black cape with a medical insignia."
	icon_state = "rank_cape_medic"

/obj/item/clothing/neck/shiptest/cloak/rank_shoulder_cape/medic
	parent_type = /obj/item/clothing/neck/shiptest/cloak/rank_cape/medic
	name = "medic rank shoulder cape"
	icon_state = "rank_shoulder_cape_medic"

/obj/item/clothing/neck/shiptest/cloak/black_ceremonial
	name = "black ceremonial cloak"
	desc = "A black ceremonial cloak with a broad collar and gold edging."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cloak_black_ceremonial"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'

/obj/item/clothing/neck/shiptest/cloak/striped_ceremonial
	name = "striped ceremonial cloak"
	desc = "A striped white and navy ceremonial cloak with gold edging."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cloak_striped_ceremonial"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'

/obj/item/clothing/neck/shiptest/cloak/fur_trimmed_navy
	name = "fur-trimmed navy cloak"
	desc = "A navy cloak with a plush white collar and gold edging."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cloak_fur_trimmed_navy"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'

/obj/item/clothing/neck/shiptest/cloak/purple_short
	name = "purple short cloak"
	desc = "Worn by both the young and old alike. You can almost feel the academic pride."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cloak_purple_short"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	inhand_icon_state = "cloak_purple_short"
	lefthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/righthand.dmi'

/obj/item/clothing/neck/shiptest/cloak/gold_trimmed_black
	parent_type = /obj/item/clothing/neck/shiptest/cloak/purple_short
	name = "gold-trimmed black cloak"
	desc = "A long black cloak with gold trim and a purple lining."
	icon_state = "cloak_gold_trimmed_black"
	inhand_icon_state = "cloak_gold_trimmed_black"

/obj/item/clothing/neck/shiptest/cloak/purple_academic
	parent_type = /obj/item/clothing/neck/shiptest/cloak/purple_short
	name = "purple academic cloak"
	desc = "A purple academic cloak with gold trim and an imposing collar."
	icon_state = "cloak_purple_academic"
	inhand_icon_state = "cloak_purple_academic"

/obj/item/clothing/neck/shiptest/cloak/sash/command
	name = "command sash"
	desc = "A fine red silk sash that pairs nicely with a formal uniform."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "sash_command"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	inhand_icon_state = "sash_command"
	lefthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/righthand.dmi'

/obj/item/clothing/neck/shiptest/crystal_amulet
	name = "crystal amulet"
	desc = "A decorative crystal amulet. Its mysterious appearance makes it a striking costume accessory."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "crystal_amulet"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/clothing/neck/shiptest/dogtag/plain
	name = "dogtag"
	desc = "A non-military dogtag, often worn for style in certain circles."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "dogtag_plain"

/obj/item/clothing/neck/shiptest/mantle/black
	name = "black mantle"
	desc = "A big mantle for big shoulders."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "mantle_black"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/clothing/neck/shiptest/mantle/desert
	name = "desert mantle"
	desc = "A big mantle for big shoulders."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "mantle_desert"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/clothing/neck/shiptest/neckwraps/black
	name = "black neckwraps"
	desc = "A fashionable piece of cloth cover your neck."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "neckwraps_black"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/clothing/neck/shiptest/neckwraps/blue
	name = "blue neckwraps"
	desc = "A fashionable piece of cloth cover your neck."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "neckwraps_blue"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/clothing/neck/shiptest/neckwraps/brown
	name = "brown neckwraps"
	desc = "A fashionable piece of cloth cover your neck."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "neckwraps_brown"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/clothing/neck/shiptest/hooded_cape/black
	name = "black hooded cape"
	desc = "A soft woven replica of an optical camouflage cloak. Its camouflage electronics are nonfunctional."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hooded_cape_black-0"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	body_parts_covered = CHEST | GROIN | LEGS | ARMS
	w_class = WEIGHT_CLASS_BULKY
	flags_inv = HIDESUITSTORAGE
	alternate_worn_layer = BODY_FRONT_LAYER
	/// Whether the hood is up - only the look, the replica cloak has no camouflage
	var/hood_up = FALSE

/obj/item/clothing/neck/shiptest/poncho/black
	name = "black poncho"
	desc = "Perfect for a rainy night with jazz."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "poncho_black"
	w_class = WEIGHT_CLASS_NORMAL
	hoodtype = /obj/item/clothing/head/hooded/shiptest/poncho/black

/obj/item/clothing/neck/shiptest/poncho/blue
	name = "blue poncho"
	desc = "Perfect for a rainy night with jazz."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "poncho_blue"
	w_class = WEIGHT_CLASS_NORMAL
	hoodtype = /obj/item/clothing/head/hooded/shiptest/poncho/blue

/obj/item/clothing/neck/shiptest/poncho/brown
	name = "brown poncho"
	desc = "Perfect for a rainy night with jazz."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "poncho_brown"
	w_class = WEIGHT_CLASS_NORMAL
	hoodtype = /obj/item/clothing/head/hooded/shiptest/poncho/brown

/obj/item/clothing/neck/shiptest/poncho/dark_blue
	name = "dark blue poncho"
	desc = "Perfect for a rainy night with jazz."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "poncho_dark_blue"
	w_class = WEIGHT_CLASS_NORMAL
	hoodtype = /obj/item/clothing/head/hooded/shiptest/poncho/dark_blue

/obj/item/clothing/neck/shiptest/poncho/dark_green
	name = "dark green poncho"
	desc = "Perfect for a rainy night with jazz."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "poncho_dark_green"
	w_class = WEIGHT_CLASS_NORMAL
	hoodtype = /obj/item/clothing/head/hooded/shiptest/poncho/dark_green

/obj/item/clothing/neck/shiptest/scarf/black
	name = "black scarf"
	desc = "A stylish scarf. The perfect winter accessory for those with a keen fashion sense, and those who just can't handle a cold breeze on their necks."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "scarf_black"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/clothing/neck/shiptest/scarf/blue
	name = "blue scarf"
	desc = "A stylish scarf. The perfect winter accessory for those with a keen fashion sense, and those who just can't handle a cold breeze on their necks."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "scarf_blue"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/clothing/neck/shiptest/scarf/brown
	name = "brown scarf"
	desc = "A stylish scarf. The perfect winter accessory for those with a keen fashion sense, and those who just can't handle a cold breeze on their necks."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "scarf_brown"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/clothing/neck/shiptest/scarf/dark_blue
	name = "dark blue scarf"
	desc = "A stylish scarf. The perfect winter accessory for those with a keen fashion sense, and those who just can't handle a cold breeze on their necks."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "scarf_dark_blue"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/clothing/neck/shiptest/scarf/dark_green
	name = "dark green scarf"
	desc = "A stylish scarf. The perfect winter accessory for those with a keen fashion sense, and those who just can't handle a cold breeze on their necks."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "scarf_dark_green"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/clothing/neck/shiptest/shemagh/red
	name = "red shemagh"
	desc = "An oversized shemagh in blood red."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "shemagh_red"

/obj/item/clothing/neck/shiptest/shemagh/maroon
	name = "maroon shemagh"
	desc = "An oversized shemagh, in a dark maroon."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "shemagh_maroon"

/obj/item/clothing/neck/shiptest/scarf/orange_grey_striped
	name = "orange and grey striped scarf"
	desc = "A warm scarf with broad orange and grey stripes and tasseled ends."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "scarf_orange_grey_striped"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/clothing/neck/shiptest/pride_tie/ally
	name = "ally tie"
	desc = "A neosilk clip-on tie. This one is in the colors of the ally flag."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "pride_tie_ally"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'

/obj/item/clothing/neck/shiptest/pride_tie/asexual
	name = "asexual tie"
	desc = "A neosilk clip-on tie. This one is in the colors of the asexual flag."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "pride_tie_asexual"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'

/obj/item/clothing/neck/shiptest/pride_tie/bisexual
	name = "bisexual tie"
	desc = "A neosilk clip-on tie. This one is in the colors of the bisexual flag."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "pride_tie_bisexual"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'

/obj/item/clothing/neck/shiptest/hooded_cape/black/examine(mob/user)
	. = ..()
	. += span_notice("Alt-click to raise or lower the hood.")

/obj/item/clothing/neck/shiptest/hooded_cape/black/click_alt(mob/user)
	if(!isliving(user) || !user.can_perform_action(src))
		return CLICK_ACTION_BLOCKING
	set_hood_up(!hood_up)
	balloon_alert(user, hood_up ? "hood raised" : "hood lowered")
	return CLICK_ACTION_SUCCESS

/obj/item/clothing/neck/shiptest/hooded_cape/black/dropped(mob/user)
	. = ..()
	set_hood_up(FALSE)

/// Raises or lowers the hood, which hides hair and ears while it is up
/obj/item/clothing/neck/shiptest/hooded_cape/black/proc/set_hood_up(raised)
	hood_up = raised
	icon_state = hood_up ? "hooded_cape_black-1" : "hooded_cape_black-0"
	flags_inv = HIDESUITSTORAGE
	if(hood_up)
		flags_inv |= HIDEHAIR|HIDEEARS
	update_slot_icon()
	if(iscarbon(loc))
		var/mob/living/carbon/wearer = loc
		wearer.refresh_obscured()

// The hooded garments' hoods, put up and down by tg's toggle_attached_clothing on their garment
/obj/item/clothing/head/hooded/shiptest
	abstract_type = /obj/item/clothing/head/hooded/shiptest
	supports_variations_flags = NONE
	flags_inv = HIDEHAIR|HIDEEARS

/obj/item/clothing/head/hooded/shiptest/poncho/black
	name = "poncho"
	desc = "Perfect for a rainy night with jazz."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_poncho_black"
	flags_inv = HIDEHAIR|HIDEFACE|HIDEEARS

/obj/item/clothing/head/hooded/shiptest/poncho/blue
	name = "poncho"
	desc = "Perfect for a rainy night with jazz."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_poncho_blue"
	flags_inv = HIDEHAIR|HIDEFACE|HIDEEARS

/obj/item/clothing/head/hooded/shiptest/poncho/brown
	name = "poncho"
	desc = "Perfect for a rainy night with jazz."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_poncho_brown"
	flags_inv = HIDEHAIR|HIDEFACE|HIDEEARS

/obj/item/clothing/head/hooded/shiptest/poncho/dark_blue
	name = "poncho"
	desc = "Perfect for a rainy night with jazz."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_poncho_dark_blue"
	flags_inv = HIDEHAIR|HIDEFACE|HIDEEARS

/obj/item/clothing/head/hooded/shiptest/poncho/dark_green
	name = "poncho"
	desc = "Perfect for a rainy night with jazz."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_poncho_dark_green"
	flags_inv = HIDEHAIR|HIDEFACE|HIDEEARS

/obj/item/clothing/head/hooded/shiptest/cropped_hoodie/black_and_white
	name = "white hood"
	desc = "A white hood attached to a black and white hoodie."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_hoodie_white"
	cold_protection = HEAD
	min_cold_protection_temperature = FIRE_SUIT_MIN_TEMP_PROTECT

/obj/item/clothing/head/hooded/shiptest/hoodie/black
	name = "black hood"
	desc = "A black hood for your black hoodie."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_hoodie_black"
	cold_protection = HEAD
	min_cold_protection_temperature = FIRE_SUIT_MIN_TEMP_PROTECT

/obj/item/clothing/head/hooded/shiptest/hoodie/black_and_white
	name = "white hood"
	desc = "A white hood attached to a black and white hoodie."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_hoodie_white"
	cold_protection = HEAD
	min_cold_protection_temperature = FIRE_SUIT_MIN_TEMP_PROTECT

/obj/item/clothing/head/hooded/shiptest/hoodie/blue
	name = "blue hood"
	desc = "A blue hood for your blue hoodie."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_hoodie_blue"
	cold_protection = HEAD
	min_cold_protection_temperature = FIRE_SUIT_MIN_TEMP_PROTECT

/obj/item/clothing/head/hooded/shiptest/hoodie/brown
	name = "brown hood"
	desc = "A brown hood for your brown hoodie."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_hoodie_brown"
	cold_protection = HEAD
	min_cold_protection_temperature = FIRE_SUIT_MIN_TEMP_PROTECT

/obj/item/clothing/head/hooded/shiptest/survivor_suit/grey
	name = "survivor hood"
	desc = "A loose-fitting hood, patched with sealant and adhesive."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_survivor_suit_grey"
	flags_inv = HIDEHAIR|HIDEFACE|HIDEEARS

/obj/item/clothing/head/hooded/shiptest/survivor_suit/brown
	name = "survivor hood"
	desc = "A loose-fitting hood, patched with sealant and adhesive."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_survivor_suit_brown"
	flags_inv = HIDEHAIR|HIDEFACE|HIDEEARS

/obj/item/clothing/head/hooded/shiptest/survivor_suit/olive
	name = "survivor hood"
	desc = "A loose-fitting hood, patched with sealant and adhesive."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_survivor_suit_olive"
	flags_inv = HIDEHAIR|HIDEFACE|HIDEEARS

/obj/item/clothing/head/hooded/shiptest/survivor_suit/blue
	name = "survivor hood"
	desc = "A loose-fitting hood, patched with sealant and adhesive."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_survivor_suit_blue"
	flags_inv = HIDEHAIR|HIDEFACE|HIDEEARS

/obj/item/clothing/head/hooded/shiptest/survivor_suit/yellow
	name = "survivor hood"
	desc = "A loose-fitting hood, patched with sealant and adhesive."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_survivor_suit_yellow"
	flags_inv = HIDEHAIR|HIDEFACE|HIDEEARS

/obj/item/clothing/head/hooded/shiptest/winter_coat/brown
	name = "winter hood"
	desc = "A hood attached to a heavy winter jacket."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_winter_coat_brown"
	cold_protection = HEAD
	min_cold_protection_temperature = FIRE_SUIT_MIN_TEMP_PROTECT

/obj/item/clothing/head/hooded/shiptest/winter_coat/brown_hooded
	name = "brown hood"
	desc = "A comfortable looking brown hood."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "hood_winter_coat_brown_hooded"
	cold_protection = HEAD
	min_cold_protection_temperature = FIRE_SUIT_MIN_TEMP_PROTECT
