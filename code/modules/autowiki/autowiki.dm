/// When the `AUTOWIKI` define is enabled, will generate an output file for tools/autowiki/autowiki.js to consume.
/// Autowiki code intentionally still *exists* even without the define, to ensure developers notice
/// when they break it immediately, rather than until CI or worse, call time.
#if defined(AUTOWIKI) || defined(UNIT_TESTS)
/proc/setup_autowiki()
	Master.sleep_offline_after_initializations = FALSE
	SSticker.OnRoundstart(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(generate_autowiki)))
	SSticker.start_immediately = TRUE
	CONFIG_SET(number/round_end_countdown, 0)

/proc/generate_autowiki()
	// Round-start callbacks can run while the ticker is still initializing. Let normal
	// subsystem startup finish before initialized adapters and behavioral fixtures run.
	for(var/attempt in 1 to 300)
		if(MC_RUNNING())
			break
		sleep(1)
	if(!MC_RUNNING())
		CRASH("Autowiki requires a running initialized fixture world")
	var/output = generate_autowiki_output()
	var/datum/autowiki_export/structured_export = new
	structured_export.generate()
	rustg_file_write(output, "data/autowiki_edits.txt")
	world.FinishTestRun()
#endif

/// Returns a string of the autowiki output file
/proc/generate_autowiki_output()
	var/total_output = ""

	for (var/datum/autowiki/autowiki_type as anything in subtypesof(/datum/autowiki))
		var/datum/autowiki/autowiki = new autowiki_type
		var/output = autowiki.generate()

		if (!istext(output))
			CRASH("[autowiki_type] does not generate a proper output!")

		total_output += json_encode(list(
			"title" = autowiki.page,
			"text" = output,
		)) + "\n"

	return total_output
