/datum/techweb_node/basic_microfusion
	node_flags = parent_type::node_flags | TECHWEB_NODE_STARTER
	display_name = "Basic Microfusion Technology"
	description = "Basic microfusion technology allowing for basic microfusion designs."
	unlocked_designs = list(
		/datum/design/microfusion/cell/basic,
	)

//Enhanced microfusion
/datum/techweb_node/enhanced_microfusion
	display_name = "Enhanced Microfusion Technology"
	description = "Enhanced microfusion technology allowing for upgraded basic microfusion!"
	prerequisite_nodes = list(
		/datum/techweb_node/basic_microfusion,
		/datum/techweb_node/construction,
		/datum/techweb_node/basic_arms,
		/datum/techweb_node/parts_upg,
	)
	unlocked_designs = list(
		/datum/design/microfusion/cell/enhanced,
		/datum/design/microfusion/cell_attachment/rechargeable,
		/datum/design/microfusion/phase_emitter/enhanced,
		/datum/design/microfusion/attachment/unique/camo_black,
		/datum/design/microfusion/attachment/unique/camo_nanotrasen,
		/datum/design/microfusion/attachment/underbarrel/heatsink,
		/datum/design/microfusion/attachment/unique/rgb,
		/datum/design/microfusion/cell_attachment/tactical,
		/datum/design/microfusion/cell_attachment/reloader,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = 3500)

//Advanced microfusion
/datum/techweb_node/advanced_microfusion
	display_name = "Advanced Microfusion Technology"
	description = "Advanced microfusion technology allowing for advanced microfusion!"
	prerequisite_nodes = list(
		/datum/techweb_node/enhanced_microfusion,
		/datum/techweb_node/spec_eng,
		/datum/techweb_node/electric_weapons,
		/datum/techweb_node/energy_manipulation,
		/datum/techweb_node/plasma_control,
	)
	unlocked_designs = list(
		/datum/design/microfusion/cell/advanced,
		/datum/design/microfusion/cell_attachment/overcapacity,
		/datum/design/microfusion/cell_attachment/stabilising,
		/datum/design/microfusion/attachment/barrel/scatter,
		/datum/design/microfusion/attachment/barrel/hellfire,
		/datum/design/microfusion/phase_emitter/advanced,
		/datum/design/microfusion/attachment/barrel/lance,
		/datum/design/microfusion/attachment/underbarrel/grip,
		/datum/design/microfusion/attachment/rail_slot/rail,
		/datum/design/microfusion/attachment/rail_slot/scope,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = 5000)


// Bluespace microfusion
/datum/techweb_node/bluespace_microfusion
	display_name = "Bluespace Microfusion Technology"
	description = "Bluespace tinkering plus microfusion technology!"
	prerequisite_nodes = list(
		/datum/techweb_node/advanced_microfusion,
		/datum/techweb_node/applied_bluespace,
		/datum/techweb_node/beam_weapons,
		/datum/techweb_node/explosives,
	)
	unlocked_designs = list(
		/datum/design/microfusion/cell/bluespace,
		/datum/design/microfusion/attachment/barrel/repeater,
		/datum/design/microfusion/phase_emitter/bluespace,
		/datum/design/microfusion/cell_attachment/selfcharging,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = 10000)

// Quantum microfusion
/datum/techweb_node/quantum_microfusion
	display_name = "Quantum Microfusion Technology"
	description = "Bleeding edge microfusion tech, making use of the latest in materials and components, bluespace or otherwise."
	prerequisite_nodes = list(
		/datum/techweb_node/bluespace_microfusion,
		/datum/techweb_node/alien/base,
	)
	unlocked_designs = list(
		/datum/design/microfusion/attachment/barrel/xray,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = 15000)

// Warcrime microfusion
/datum/techweb_node/illegal_microfusion
	display_name = "Illegal Microfusion Technology"
	description = "Microfusion tech that has previously been banned by SolFed. I love the smell of plasma in the mornings."
	prerequisite_nodes = list(
		/datum/techweb_node/advanced_microfusion,
		/datum/techweb_node/syndicate_basic,
	)
	unlocked_designs = list(
		/datum/design/microfusion/attachment/barrel/superheat,
		/datum/design/microfusion/attachment/barrel/scatter/max,
		/datum/design/microfusion/attachment/barrel/repeater/penetrator,
		/datum/design/microfusion/attachment/unique/camo_syndicate,
		/datum/design/microfusion/attachment/barrel/suppressor,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = 5000)

// clown microfusion. | This exists to not make this non modular
/datum/techweb_node/clown_microfusion
	display_name = "Honkicron Clownery Systems Technology"
	description = "Microfusion tech that is proprietary tech of Honkicron Clownery Systems. HONK!!"
	prerequisite_nodes = list(
		/datum/techweb_node/basic_microfusion,
		/datum/techweb_node/mech_clown, //Closest thing to clown tech we have left
	)
	unlocked_designs = list(
		/datum/design/microfusion/attachment/barrel/honk,
		/datum/design/microfusion/attachment/unique/camo_bananium,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = 500) //Its normally supposed to be in clown tech so
