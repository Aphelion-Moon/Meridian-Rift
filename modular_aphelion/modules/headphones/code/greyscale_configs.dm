// GAGS configs for the headphone sets. The templates (one DMI for every set) and JSON are generated from the approved
// art by the lab's export script (runs/headphones-20261005/impl/export/export_assets.py); regenerate rather than
// hand-edit them.

/datum/greyscale_config/headphones_studio
	name = "Studio Headphones"
	icon_file = 'modular_aphelion/modules/headphones/icons/headphones_gags.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/studiophones.json'

/datum/greyscale_config/headphones_studio/worn
	name = "Studio Headphones (Worn)"
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/studiophones_worn.json'

/datum/greyscale_config/headphones_studio/inhand_left
	name = "Studio Headphones (Left Hand)"
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/studiophones_inhand_left.json'

/datum/greyscale_config/headphones_studio/inhand_right
	name = "Studio Headphones (Right Hand)"
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/studiophones_inhand_right.json'

/datum/greyscale_config/headphones_streetjack
	name = "Streetjack Cans"
	icon_file = 'modular_aphelion/modules/headphones/icons/headphones_gags.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/streetcans.json'

/datum/greyscale_config/headphones_streetjack/worn
	name = "Streetjack Cans (Worn)"
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/streetcans_worn.json'

/datum/greyscale_config/headphones_streetjack/inhand_left
	name = "Streetjack Cans (Left Hand)"
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/streetcans_inhand_left.json'

/datum/greyscale_config/headphones_streetjack/inhand_right
	name = "Streetjack Cans (Right Hand)"
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/streetcans_inhand_right.json'

/// Both Raid versions: the headset draws its boom mic over these (headphones_raid_mic).
/datum/greyscale_config/headphones_raid
	name = "Raid Headset"
	icon_file = 'modular_aphelion/modules/headphones/icons/headphones_gags.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/raid.json'

/datum/greyscale_config/headphones_raid/worn
	name = "Raid Headset (Worn)"
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/raid_worn.json'

/datum/greyscale_config/headphones_raid/inhand_left
	name = "Raid Headset (Left Hand)"
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/raid_inhand_left.json'

/datum/greyscale_config/headphones_raid/inhand_right
	name = "Raid Headset (Right Hand)"
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/raid_inhand_right.json'

/// The Raid Headset's boom mic, worn and on the item. It takes the pads colour alone.
/datum/greyscale_config/headphones_raid_mic
	name = "Raid Headset (Boom Mic)"
	icon_file = 'modular_aphelion/modules/headphones/icons/headphones_gags.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/raid_mic.json'

/datum/greyscale_config/headphones_halo
	name = "Halo Phones"
	icon_file = 'modular_aphelion/modules/headphones/icons/headphones_gags.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/halophones.json'

/datum/greyscale_config/headphones_halo/worn
	name = "Halo Phones (Worn)"
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/halophones_worn.json'

/datum/greyscale_config/headphones_halo/inhand_left
	name = "Halo Phones (Left Hand)"
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/halophones_inhand_left.json'

/datum/greyscale_config/headphones_halo/inhand_right
	name = "Halo Phones (Right Hand)"
	json_config = 'modular_nova/modules/GAGS/json_configs/head/headphones/halophones_inhand_right.json'
