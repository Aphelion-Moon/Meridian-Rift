/obj/item/organ/eyes
	/// State of a greyscale version of these eyes, for eyes whose own sprite is too dark, or fixed, to take an eye colour.
	var/greyscale_icon_state
	/// Icon file holding that state, when it isn't the eyes' own.
	var/greyscale_icon
	/// Whether these eyes draw their greyscale version. Set by the Eye Greyscale preference.
	var/greyscale_sprite = FALSE

/obj/item/organ/eyes/moth
	greyscale_icon_state = "motheyes_white"

/obj/item/organ/eyes/fly
	greyscale_icon_state = "motheyes_white" // Same shape as fly eyes.

/obj/item/organ/eyes/akula
	greyscale_icon = 'modular_aphelion/modules/greyscale_eyes/icons/greyscale_eyes.dmi'
	greyscale_icon_state = "akula"

/obj/item/organ/eyes/akula/on_bodypart_insert(obj/item/bodypart/head/limb, movement_flags)
	. = ..()
	// Akula heads swap their own eye sheet in, which has no greyscale version.
	if(greyscale_sprite)
		eye_icon = greyscale_icon
