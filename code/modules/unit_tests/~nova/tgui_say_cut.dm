/// A say box with no client or window, since alter_entry() reads only the payload and its phrases
/datum/tgui_say/bug_report_test

/datum/tgui_say/bug_report_test/New()
	return

/// A hurt player's forced say is cut by letter, so it comes out the same length in any alphabet
/datum/unit_test/tgui_say_cut_by_letter

/datum/unit_test/tgui_say_cut_by_letter/Run()
	var/datum/tgui_say/bug_report_test/say = new
	var/list/cases = list(
		list("letter" = 1076, "count" = 25, "low" = 24, "high" = 24),
		list("letter" = 1076, "count" = 30, "low" = 29, "high" = 29),
		list("letter" = 100, "count" = 30, "low" = 29, "high" = 29),
		list("letter" = 1076, "count" = 60, "low" = 39, "high" = 49),
	)
	for(var/list/test_case as anything in cases)
		var/entry = ""
		for(var/letter in 1 to test_case["count"])
			entry += ascii2text(test_case["letter"])
		var/said = say.alter_entry(list("entry" = entry, "channel" = SAY_CHANNEL))
		var/kept = length_char(copytext(said, 1, findtext(said, "-")))
		TEST_ASSERT(kept >= test_case["low"] && kept <= test_case["high"], "[test_case["count"]] of letter [test_case["letter"]] kept [kept], not [test_case["low"]] to [test_case["high"]]")
