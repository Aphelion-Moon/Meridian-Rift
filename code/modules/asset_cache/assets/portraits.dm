/datum/asset/simple/portraits
	assets = list()

/datum/asset/simple/portraits/New()
	/* // APHELION EDIT REMOVAL START - Register even when empty so midround imports can add assets.
	if(!length(SSpersistent_paintings.paintings))
		return
	*/ // APHELION EDIT REMOVAL END
	for(var/datum/painting/portrait as anything in SSpersistent_paintings.paintings)
		var/png = "data/paintings/images/[portrait.md5].png"
		if(fexists(png))
			var/asset_name = "paintings_[portrait.md5].png" // APHELION EDIT CHANGE - ORIGINAL: var/asset_name = "paintings_[portrait.md5]"
			assets[asset_name] = png
	..() //this is where it registers all these assets we added to the list
