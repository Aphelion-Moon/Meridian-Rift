// Disposable engine contract fixture. No connection to a game server or client.
/world
	fps = 20
	visibility = 0

/datum/memory_fixture
	var/list/self_cycle
	var/list/mutual_cycle
	var/list/shared
	var/list/equal_independent
	var/list/keys_and_values
	var/alist/numeric_keys
	var/list/huge
	var/list/deep
	var/list/numeric
	var/list/empty = list()

/world/New()
	..()
	var/datum/memory_fixture/root = new
	root.self_cycle = list()
	root.self_cycle += list(root.self_cycle)
	root.mutual_cycle = list()
	var/list/other_cycle = list(root.mutual_cycle)
	root.mutual_cycle += list(other_cycle)
	root.shared = list(1, 1, 2, null, "private game text never exported")
	root.equal_independent = root.shared.Copy()
	var/list/key = list("secret key")
	var/list/associated = list("secret value")
	root.keys_and_values = list()
	root.keys_and_values[key] = associated
	root.numeric_keys = alist(7 = associated, key = key, "null" = null)
	root.huge = new/list(10000)
	root.numeric = new/list(32)
	root.deep = list()
	var/list/tail = root.deep
	for(var/index in 1 to 100)
		var/list/next = list()
		tail += list(next)
		tail = next
	var/datum/memory_fixture/second = new
	second.shared = root.shared
	second.self_cycle = root.self_cycle
	var/datum/memory_capture/capture = new("fixture.ndjson", list("capture_id" = "engine-fixture", "run_id" = "disposable-fixture", "byond" = "[world.byond_version].[world.byond_build]", "os" = world.system_type, "architecture" = "x86", "evidence_class" = "synthetic_calibration_fixture", "workload" = "cycles-sharing-alists", "real_clients" = 0, "simulated_actors" = 0))
	capture.add_root(root, "fixture")
	capture.add_root(second, "second")
	// Test-mode relaxation permits measuring cold file I/O; defaults are separately exercised.
	capture.budget_ms = 10
	capture.tick_fraction = 1
	var/mode = world.params["mode"]
	switch(mode)
		if("default")
			capture.budget_ms = 1
			capture.tick_fraction = 0.02
		if("nodes")
			capture.node_limit = 3
		if("output")
			capture.output_limit = 1400
		if("work")
			capture.work_limit = 16
		if("duration")
			capture.duration_limit = 2
		if("write")
			capture.output_path = "."
		if("cancel_early")
			capture.finish("cancelled", "fixture_cancel_early")
		if("delete")
			// Prepare the two queued identities at a deterministic lifecycle boundary.
			// This mode checks deletion handling, not scheduler timing.
			for(var/setup_step in 1 to 4)
				capture.advance()
			del(second)
	var/ticks = 0
	while(capture.state != "done")
		capture.tick()
		ticks++
		if(ticks == 3)
			switch(mode)
				if("cancel")
					capture.finish("cancelled", "fixture_cancel")
				if("mutation")
					root.huge.len = 50
		sleep(world.tick_lag)
	if(length(capture.entries) || length(capture.identities) || length(capture.roots))
		world.log << "MEMORY_FIXTURE_FAILURE retained references"
	world.log << "MEMORY_FIXTURE_DONE status=[capture.result] nodes=[capture.node_count] edges=[capture.edge_count] retained=[length(capture.entries)] worst=[capture.worst_atomic_ms]ms"
	shutdown()
