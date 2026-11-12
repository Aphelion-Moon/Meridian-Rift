// Shiptest jumpsuits, trousers, shorts, skirts and dresses

// The recolourable ones get their configs and colours in greyscale.dm
/obj/item/clothing/under/shiptest
	abstract_type = /obj/item/clothing/under/shiptest
	can_adjust = FALSE
	female_sprite_flags = NO_FEMALE_UNIFORM
	bodyshapes_with_variations = NONE

/obj/item/clothing/under/shiptest/prisoner_jumpsuit/light_brown
	parent_type = /obj/item/clothing/under/shiptest
	name = "light brown prisoner jumpsuit"
	desc = "A cheap, lightweight jumpsuit in prisoner brown, with ordinary adjustable suit sensors."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "prisoner_jumpsuit_light_brown"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	can_adjust = TRUE
	inhand_icon_state = "lb_suit"

/obj/item/clothing/under/shiptest/tango_dress/black
	parent_type = /obj/item/clothing/under/shiptest
	name = "black tango dress"
	desc = "A silky black satin dress, traditionally made for dancing. It's light and easy to move in."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "tango_dress_black"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	worn_icon_vox = 'modular_aphelion/modules/shiptest_clothing/icons/vox.dmi'
	inhand_icon_state = "wcoat"

/obj/item/clothing/under/shiptest/formal_gown/red
	parent_type = /obj/item/clothing/under/shiptest
	name = "red formal gown"
	desc = "A long red gown with a fitted waist and broad decorative shoulders."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "formal_gown_red"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	inhand_icon_state = "bl_suit"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'

/obj/item/clothing/under/shiptest/one_shoulder_dress
	parent_type = /obj/item/clothing/under/shiptest
	name = "one shoulder dress"
	desc = "A modern black dress with only one shoulder strap. Comes with a matching pair of arm warmers."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "one_shoulder_dress"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	inhand_icon_state = "bl_suit"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	// Shiptest's rolled sleeves (_s) are drawn as tg's adjusted state _d
	can_adjust = TRUE
	alt_covers_chest = TRUE

/obj/item/clothing/under/shiptest/evening_gown/red
	parent_type = /obj/item/clothing/under/shiptest
	name = "red evening gown"
	desc = "Fancy dress for space bar singers."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "evening_gown_red"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	inhand_icon_state = "bl_suit"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'

/obj/item/clothing/under/shiptest/skirt/black
	parent_type = /obj/item/clothing/under/shiptest
	name = "black skirt"
	desc = "A black, casual skirt."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "skirt_black"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	can_adjust = TRUE
	inhand_icon_state = "bl_suit"

/obj/item/clothing/under/shiptest/skirt/blue
	parent_type = /obj/item/clothing/under/shiptest
	name = "blue skirt"
	desc = "A blue, casual skirt."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "skirt_blue"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	can_adjust = TRUE
	inhand_icon_state = "bl_suit"

/obj/item/clothing/under/shiptest/skirt/purple
	parent_type = /obj/item/clothing/under/shiptest
	name = "purple skirt"
	desc = "A purple, casual skirt."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "skirt_purple"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	can_adjust = TRUE
	inhand_icon_state = "bl_suit"

/obj/item/clothing/under/shiptest/skirt/red
	parent_type = /obj/item/clothing/under/shiptest
	name = "red skirt"
	desc = "A red, casual skirt."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "skirt_red"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	can_adjust = TRUE
	inhand_icon_state = "bl_suit"

/obj/item/clothing/under/shiptest/pinafore/black
	parent_type = /obj/item/clothing/under/shiptest
	name = "black pinafore"
	desc = "It's really just an apron that one wears over a shirt or dress. This one is black."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "pinafore_black"
	inhand_icon_state = "bl_suit"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	// Shiptest's rolled sleeves (_s) are drawn as tg's adjusted state _d
	can_adjust = TRUE
	alt_covers_chest = TRUE

/obj/item/clothing/under/shiptest/pinafore/cerulean
	parent_type = /obj/item/clothing/under/shiptest
	name = "cerulean pinafore"
	desc = "It's really just an apron that one wears over a shirt or dress. This one is cerulean."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "pinafore_cerulean"
	inhand_icon_state = "bl_suit"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	// Shiptest's rolled sleeves (_s) are drawn as tg's adjusted state _d
	can_adjust = TRUE
	alt_covers_chest = TRUE

/obj/item/clothing/under/shiptest/pinafore/maroon
	parent_type = /obj/item/clothing/under/shiptest
	name = "maroon pinafore"
	desc = "It's really just an apron that one wears over a shirt or dress. This one is maroon."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "pinafore_maroon"
	inhand_icon_state = "bl_suit"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	// Shiptest's rolled sleeves (_s) are drawn as tg's adjusted state _d
	can_adjust = TRUE
	alt_covers_chest = TRUE

/obj/item/clothing/under/shiptest/plaid_pinafore/red
	parent_type = /obj/item/clothing/under/shiptest
	name = "red plaid pinafore"
	desc = "It's really just an apron that one wears over a shirt or dress. This one is in red plaid."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "plaid_pinafore_red"
	inhand_icon_state = "bl_suit"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	// Shiptest's rolled sleeves (_s) are drawn as tg's adjusted state _d
	can_adjust = TRUE
	alt_covers_chest = TRUE

/obj/item/clothing/under/shiptest/plaid_pinafore/brown
	parent_type = /obj/item/clothing/under/shiptest
	name = "brown plaid pinafore"
	desc = "It's really just an apron that one wears over a shirt or dress. This one is in brown plaid."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "plaid_pinafore_brown"
	inhand_icon_state = "bl_suit"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	// Shiptest's rolled sleeves (_s) are drawn as tg's adjusted state _d
	can_adjust = TRUE
	alt_covers_chest = TRUE

/obj/item/clothing/under/shiptest/plaid_pinafore/green
	parent_type = /obj/item/clothing/under/shiptest
	name = "green plaid pinafore"
	desc = "It's really just an apron that one wears over a shirt or dress. This one is in green plaid."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "plaid_pinafore_green"
	inhand_icon_state = "bl_suit"
	body_parts_covered = CHEST|GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	// Shiptest's rolled sleeves (_s) are drawn as tg's adjusted state _d
	can_adjust = TRUE
	alt_covers_chest = TRUE

/obj/item/clothing/under/shiptest/cargo_pants/grey
	parent_type = /obj/item/clothing/under/shiptest
	name = "grey cargo pants"
	desc = "A pocket for every need."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cargo_pants_grey"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/cargo_pants/black
	parent_type = /obj/item/clothing/under/shiptest
	name = "black cargo pants"
	desc = "A pocket for every need."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cargo_pants_black"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/cargo_pants/brown
	parent_type = /obj/item/clothing/under/shiptest
	name = "brown cargo pants"
	desc = "A pocket for every need."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cargo_pants_brown"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/cargo_pants/jean
	parent_type = /obj/item/clothing/under/shiptest
	name = "jean cargo pants"
	desc = "A pocket for every need."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cargo_pants_jean"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/cargo_pants/khaki
	parent_type = /obj/item/clothing/under/shiptest
	name = "khaki cargo pants"
	desc = "A pocket for every need."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cargo_pants_khaki"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/cargo_pants/navy
	parent_type = /obj/item/clothing/under/shiptest
	name = "navy cargo pants"
	desc = "A pocket for every need."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cargo_pants_navy"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/cargo_pants/olive
	parent_type = /obj/item/clothing/under/shiptest
	name = "olive cargo pants"
	desc = "A pocket for every need."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cargo_pants_olive"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/pajama_pants/blue
	parent_type = /obj/item/clothing/under/shiptest
	name = "blue pajama pants"
	desc = "A comfy pair of pajamas. Probably not the best for work attire."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "pajama_pants_blue"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/pajama_pants/green
	parent_type = /obj/item/clothing/under/shiptest
	name = "green pajama pants"
	desc = "A comfy pair of pajamas. Probably not the best for work attire."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "pajama_pants_green"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/sweatpants/black
	parent_type = /obj/item/clothing/under/shiptest
	name = "sweatpants"
	desc = "A pair of sweatpants, for the athletic."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "sweatpants_black"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/sweatpants/blue
	parent_type = /obj/item/clothing/under/shiptest
	name = "blue sweatpants"
	desc = "A pair of sweatpants, for the athletic."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "sweatpants_blue"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/sweatpants/purple
	parent_type = /obj/item/clothing/under/shiptest
	name = "purple sweatpants"
	desc = "A pair of sweatpants, for the athletic."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "sweatpants_purple"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/sweatpants/red
	parent_type = /obj/item/clothing/under/shiptest
	name = "red sweatpants"
	desc = "A pair of sweatpants, for the athletic."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "sweatpants_red"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/sweatpants/teal
	parent_type = /obj/item/clothing/under/shiptest
	name = "teal sweatpants"
	desc = "A pair of sweatpants, for the athletic."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "sweatpants_teal"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/track_pants/grey
	parent_type = /obj/item/clothing/under/shiptest
	name = "track pants"
	desc = "A pair of track pants, for the athletic."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "track_pants_grey"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'

/obj/item/clothing/under/shiptest/track_pants/blue
	parent_type = /obj/item/clothing/under/shiptest
	name = "blue track pants"
	desc = "A pair of track pants, for the athletic."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "track_pants_blue"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/track_pants/pink
	parent_type = /obj/item/clothing/under/shiptest
	name = "pink track pants"
	desc = "A pair of track pants, for the athletic."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "track_pants_pink"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/track_pants/purple
	parent_type = /obj/item/clothing/under/shiptest
	name = "purple track pants"
	desc = "A pair of track pants, for the athletic."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "track_pants_purple"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/track_pants/red
	parent_type = /obj/item/clothing/under/shiptest
	name = "red track pants"
	desc = "A pair of track pants, for the athletic."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "track_pants_red"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/track_pants/teal
	parent_type = /obj/item/clothing/under/shiptest
	name = "teal track pants"
	desc = "A pair of track pants, for the athletic."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "track_pants_teal"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN|LEGS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/under/shiptest/athletic_shorts/grey
	parent_type = /obj/item/clothing/under/shiptest
	name = "grey athletic shorts"
	desc = "95% Polyester, 5% Spandex!"
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "athletic_shorts_grey"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/athletic_shorts/black
	parent_type = /obj/item/clothing/under/shiptest
	name = "black athletic shorts"
	desc = "95% Polyester, 5% Spandex!"
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "athletic_shorts_black"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/athletic_shorts/blue
	parent_type = /obj/item/clothing/under/shiptest
	name = "blue athletic shorts"
	desc = "95% Polyester, 5% Spandex!"
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "athletic_shorts_blue"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/jorts/brown
	parent_type = /obj/item/clothing/under/shiptest
	name = "brown jorts"
	desc = "Jean shorts cut from denim."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "jorts_brown"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/cargo_shorts/grey
	parent_type = /obj/item/clothing/under/shiptest
	name = "cargo shorts"
	desc = "A pocket for every need on a hot day."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cargo_shorts_grey"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/cargo_shorts/brown
	parent_type = /obj/item/clothing/under/shiptest
	name = "brown cargo shorts"
	desc = "A pocket for every need on a hot day."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cargo_shorts_brown"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/cargo_shorts/jean
	parent_type = /obj/item/clothing/under/shiptest
	name = "jean cargo shorts"
	desc = "A pocket for every need on a hot day."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cargo_shorts_jean"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/cargo_shorts/olive
	parent_type = /obj/item/clothing/under/shiptest
	name = "olive cargo shorts"
	desc = "A pocket for every need on a hot day."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "cargo_shorts_olive"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/compression_shorts/grey
	parent_type = /obj/item/clothing/under/shiptest
	name = "compression shorts"
	desc = "Short shorts made for blistering hot days and athletic use."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "compression_shorts_grey"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/compression_shorts/blue
	parent_type = /obj/item/clothing/under/shiptest
	name = "blue compression shorts"
	desc = "Short shorts made for blistering hot days and athletic use."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "compression_shorts_blue"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/compression_shorts/brown
	parent_type = /obj/item/clothing/under/shiptest
	name = "brown compression shorts"
	desc = "Short shorts made for blistering hot days and athletic use."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "compression_shorts_brown"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/dolphin_shorts
	parent_type = /obj/item/clothing/under/shiptest
	name = "dolphin shorts"
	desc = "Short shorts made for blistering hot days and athletic use."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "dolphin_shorts"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/explorer_shorts
	parent_type = /obj/item/clothing/under/shiptest
	name = "explorer shorts"
	desc = "Bright khaki short shorts for higher humidity, hot planets."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "explorer_shorts"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/athletic_shorts/green
	parent_type = /obj/item/clothing/under/shiptest
	name = "green athletic shorts"
	desc = "95% Polyester, 5% Spandex!"
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "athletic_shorts_green"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/athletic_shorts/pink
	parent_type = /obj/item/clothing/under/shiptest
	name = "pink athletic shorts"
	desc = "95% Polyester, 5% Spandex!"
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "athletic_shorts_pink"
	inhand_icon_state = "bl_suit"
	body_parts_covered = GROIN
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	vox_short_legs = TRUE

/obj/item/clothing/under/shiptest/engineer_jumpsuit/red
	parent_type = /obj/item/clothing/under/shiptest
	name = "red engineer jumpsuit"
	desc = "A red engineering jumpsuit with dark trousers and utility detailing."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "engineer_jumpsuit_red"
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	inhand_icon_state = "bl_suit"

/obj/item/clothing/under/shiptest/technician_jumpsuit/black_and_khaki
	parent_type = /obj/item/clothing/under/shiptest
	name = "black and khaki technician jumpsuit"
	desc = "A black work shirt with yellow shoulder tabs and khaki trousers."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "technician_jumpsuit_black_and_khaki"
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	inhand_icon_state = "bl_suit"

/obj/item/clothing/under/shiptest/chief_engineer_jumpsuit/white
	parent_type = /obj/item/clothing/under/shiptest
	name = "white chief engineer jumpsuit"
	desc = "A white engineering jumpsuit with gold shoulder tabs and dark trousers."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "chief_engineer_jumpsuit_white"
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	inhand_icon_state = "bl_suit"

/obj/item/clothing/under/shiptest/utility_uniform/maroon
	parent_type = /obj/item/clothing/under/shiptest
	name = "maroon utility uniform"
	desc = "A maroon work uniform with a pale collar and rugged trousers."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "utility_uniform_maroon"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	inhand_icon_state = "bl_suit"

/obj/item/clothing/under/shiptest/polo_and_khakis/red
	parent_type = /obj/item/clothing/under/shiptest
	name = "red polo and khaki pants"
	desc = "A non-descript and slightly suspicious looking polo paired with a respectable yet also suspicious pair of khaki pants."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "polo_and_khakis_red"
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	inhand_icon_state = "bl_suit"

// Abstract family nodes
/obj/item/clothing/under/shiptest/athletic_shorts
	abstract_type = /obj/item/clothing/under/shiptest/athletic_shorts

/obj/item/clothing/under/shiptest/cargo_pants
	abstract_type = /obj/item/clothing/under/shiptest/cargo_pants

/obj/item/clothing/under/shiptest/cargo_shorts
	abstract_type = /obj/item/clothing/under/shiptest/cargo_shorts

/obj/item/clothing/under/shiptest/chief_engineer_jumpsuit
	abstract_type = /obj/item/clothing/under/shiptest/chief_engineer_jumpsuit

/obj/item/clothing/under/shiptest/compression_shorts
	abstract_type = /obj/item/clothing/under/shiptest/compression_shorts

/obj/item/clothing/under/shiptest/engineer_jumpsuit
	abstract_type = /obj/item/clothing/under/shiptest/engineer_jumpsuit

/obj/item/clothing/under/shiptest/evening_gown
	abstract_type = /obj/item/clothing/under/shiptest/evening_gown

/obj/item/clothing/under/shiptest/formal_gown
	abstract_type = /obj/item/clothing/under/shiptest/formal_gown

/obj/item/clothing/under/shiptest/jorts
	abstract_type = /obj/item/clothing/under/shiptest/jorts

/obj/item/clothing/under/shiptest/pajama_pants
	abstract_type = /obj/item/clothing/under/shiptest/pajama_pants

/obj/item/clothing/under/shiptest/pinafore
	abstract_type = /obj/item/clothing/under/shiptest/pinafore

/obj/item/clothing/under/shiptest/plaid_pinafore
	abstract_type = /obj/item/clothing/under/shiptest/plaid_pinafore

/obj/item/clothing/under/shiptest/polo_and_khakis
	abstract_type = /obj/item/clothing/under/shiptest/polo_and_khakis

/obj/item/clothing/under/shiptest/prisoner_jumpsuit
	abstract_type = /obj/item/clothing/under/shiptest/prisoner_jumpsuit

/obj/item/clothing/under/shiptest/skirt
	abstract_type = /obj/item/clothing/under/shiptest/skirt

/obj/item/clothing/under/shiptest/sweatpants
	abstract_type = /obj/item/clothing/under/shiptest/sweatpants

/obj/item/clothing/under/shiptest/tango_dress
	abstract_type = /obj/item/clothing/under/shiptest/tango_dress

/obj/item/clothing/under/shiptest/technician_jumpsuit
	abstract_type = /obj/item/clothing/under/shiptest/technician_jumpsuit

/obj/item/clothing/under/shiptest/track_pants
	abstract_type = /obj/item/clothing/under/shiptest/track_pants

/obj/item/clothing/under/shiptest/utility_uniform
	abstract_type = /obj/item/clothing/under/shiptest/utility_uniform
