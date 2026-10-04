// Fresh disposable process for each population; never loaded into the real game.
/world
	fps = 20
	visibility = 0

/datum/calibration_empty

/datum/calibration_fields
	var/a
	var/b
	var/c
	var/d
	var/e
	var/f
	var/g
	var/h

/world/New()
	..()
	var/list/options = world.params
	var/count = min(100000, max(0, text2num(options["count"])))
	var/size = min(512, max(0, text2num(options["size"])))
	var/family = options["family"]
	if(!count || isnull(family))
		world.log << "CALIBRATION_ERROR missing workload parameters"
		shutdown()
		return
	var/list/held = new/list(count)
	// Warm list allocator and code path before the independent process baseline.
	for(var/index in 1 to 2000)
		var/list/warm = new/list(size)
		if(length(warm) != size)
			return
		warm = null
	text2file("ready", "baseline.marker")
	sleep(15)
	for(var/index in 1 to count)
		switch(family)
			if("datum_empty")
				held[index] = new /datum/calibration_empty
			if("datum_fields")
				held[index] = new /datum/calibration_fields
			if("alist")
				var/alist/value = alist()
				for(var/slot in 1 to size)
					value[slot] = slot
				held[index] = value
			if("assoc")
				var/list/value = list()
				for(var/slot in 1 to size)
					value["key[slot]"] = slot
				held[index] = value
			else
				held[index] = new/list(size)
		if(index % 1000 == 0)
			sleep(world.tick_lag)
	text2file("allocated", "allocated.marker")
	sleep(15)
	if(family == "shrink")
		for(var/index in 1 to count)
			var/list/value = held[index]
			value.len = 0
			if(index % 1000 == 0)
				sleep(world.tick_lag)
		text2file("shrunk", "shrunk.marker")
		sleep(15)
	// Release ordinary ownership only; no force-GC command or del loop.
	for(var/index in 1 to count)
		held[index] = null
		if(index % 1000 == 0)
			sleep(world.tick_lag)
	text2file("released", "released.marker")
	sleep(15)
	world.log << "CALIBRATION_DONE family=[family] count=[count] size=[size]"
	shutdown()
