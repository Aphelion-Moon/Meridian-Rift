/// Domain tests use an isolated store; the native crate tests real disk transactions.
/datum/controller/subsystem/persistent_paintings/gallery_fixture
	name = "Gallery test fixture"
	ss_flags = SS_NO_INIT | SS_NO_FIRE
	store_writable = TRUE
	/// Isolated committed JSON; null represents a new, empty version-3 store.
	var/list/test_snapshot
	/// Last submitted native request, captured for transaction assertions.
	var/list/test_commit
	/// Number of attempted commits, including injected failures.
	var/test_commits = 0
	/// Inject a commit failure without changing the committed snapshot.
	var/test_fail = FALSE
	/// Optional unsaved canvas identities that an import must skip.
	var/list/test_pending

/datum/controller/subsystem/persistent_paintings/gallery_fixture/New()
	return

/datum/controller/subsystem/persistent_paintings/gallery_fixture/pending_canvas_ids()
	return test_pending

/datum/controller/subsystem/persistent_paintings/gallery_fixture/store_request(list/request)
	if(request["op"] == "snapshot")
		return list("ok" = TRUE, "snapshot" = deep_copy_list(test_snapshot || list("version" = 3, "paintings" = list())), "sha256" = "test-snapshot")
	test_commits++
	test_commit = deep_copy_list(request)
	if(test_fail)
		return painting_store_failure("Injected commit failure")
	test_snapshot = deep_copy_list(request["candidate"])
	return list("ok" = TRUE, "snapshot" = deep_copy_list(test_snapshot), "changed" = TRUE)

/datum/preferences/gallery_fixture
	/// Inject a preference write failure to verify consent rollback.
	var/fail_flush = FALSE

/datum/preferences/gallery_fixture/New()
	savefile = new /datum/json_savefile(null)

/datum/preferences/gallery_fixture/flush_nova_import_preferences()
	return !fail_flush

/datum/persistent_client/gallery_fixture/New()
	return

/datum/persistent_client/gallery_fixture/Destroy(force)
	return QDEL_HINT_QUEUE

/proc/gallery_test_row(seed, owner = "galleryowner")
	return list(
		"md5" = md5(seed), "creator_ckey" = owner, "creator_name" = "Anonymous",
		"title" = "A test painting", "creation_date" = "Mon Sep 21 12:00:00 2026", "creation_round_id" = 42,
		"tags" = list("library_private"), "patron_ckey" = "someoneelse", "patron_name" = "Patron",
		"credit_value" = 0, "frame_type" = "simple", "width" = 11, "height" = 11, "medium" = "Oil",
	)

/datum/unit_test/gallery_visibility_contract/Run()
	var/datum/painting/painting = new
	var/list/row = gallery_test_row("contract")
	painting.load_from_json(row)
	TEST_ASSERT(!painting.show_in_webgallery, "Missing consent must be private")
	for(var/invalid in list(null, 0, "1", "true", 2, -1))
		row["show_in_webgallery"] = invalid
		painting.load_from_json(row)
		TEST_ASSERT(!painting.show_in_webgallery, "Invalid consent [invalid] became public")
	row["show_in_webgallery"] = TRUE
	row["future_field"] = list("preserve" = "me")
	painting.load_from_json(row)
	var/list/roundtrip = painting.to_json()
	TEST_ASSERT_EQUAL(roundtrip["show_in_webgallery"], 1, "Gallery contract regression")
	TEST_ASSERT_EQUAL(roundtrip["creator_name"], "Anonymous", "Gallery contract regression")
	TEST_ASSERT_EQUAL(roundtrip["creation_date"], row["creation_date"], "Gallery contract regression")
	TEST_ASSERT_EQUAL(json_encode(roundtrip["future_field"]), json_encode(row["future_field"]), "Gallery contract regression")

/datum/unit_test/gallery_import_preserves_existing/Run()
	var/datum/controller/subsystem/persistent_paintings/gallery_fixture/store = allocate(/datum/controller/subsystem/persistent_paintings/gallery_fixture)
	var/list/existing = gallery_test_row("existing")
	existing["show_in_webgallery"] = FALSE
	existing["future_field"] = "untouched"
	store.test_snapshot = list("version" = 3, "paintings" = list(existing))
	var/list/addition = gallery_test_row("addition")
	var/list/foreign = gallery_test_row("foreign", "otherowner")
	var/list/source = list("version" = 3, "paintings" = list(existing.Copy(), addition, foreign))
	var/list/result = store.run_store_operation("import", list("owner" = "galleryowner", "snapshot" = source, "sha256" = "source", "public" = TRUE))
	TEST_ASSERT(result["ok"], "Import should succeed")
	TEST_ASSERT_EQUAL(result["imported"], 1, "Gallery contract regression")
	var/list/rows = store.test_snapshot["paintings"]
	TEST_ASSERT_EQUAL(length(rows), 2, "Gallery contract regression")
	TEST_ASSERT_EQUAL(json_encode(rows[1]), json_encode(existing), "Existing record changed during import")
	var/list/imported = rows[2]
	TEST_ASSERT_EQUAL(imported["show_in_webgallery"], TRUE, "Gallery contract regression")
	TEST_ASSERT_EQUAL(imported["creation_date"], addition["creation_date"], "Gallery contract regression")
	TEST_ASSERT_EQUAL(imported["creator_ckey"], "galleryowner", "Gallery contract regression")
	TEST_ASSERT("library_private" in imported["tags"], "Private in-game tags must survive opt-in imports")
	TEST_ASSERT_EQUAL(source["paintings"][2]["show_in_webgallery"], null, "Read-only source was mutated")

/datum/unit_test/gallery_duplicate_import_noop/Run()
	var/datum/controller/subsystem/persistent_paintings/gallery_fixture/store = allocate(/datum/controller/subsystem/persistent_paintings/gallery_fixture)
	var/list/existing = gallery_test_row("duplicate")
	store.test_snapshot = list("version" = 3, "paintings" = list(existing))
	var/before = json_encode(store.test_snapshot)
	var/list/result = store.run_store_operation("import", list("owner" = "galleryowner", "snapshot" = deep_copy_list(store.test_snapshot), "sha256" = "source", "public" = TRUE))
	TEST_ASSERT(result["ok"], "Duplicate import should succeed without changes")
	TEST_ASSERT_EQUAL(result["imported"], 0, "Gallery contract regression")
	TEST_ASSERT_EQUAL(store.test_commits, 0, "Duplicate import must not submit any commit")
	TEST_ASSERT_EQUAL(json_encode(store.test_snapshot), before, "Gallery contract regression")

/datum/unit_test/gallery_pending_and_deleted_import/Run()
	var/datum/controller/subsystem/persistent_paintings/gallery_fixture/store = allocate(/datum/controller/subsystem/persistent_paintings/gallery_fixture)
	var/list/pending = gallery_test_row("pending")
	var/list/deleted = gallery_test_row("deleted")
	LAZYADD(store.test_pending, pending["md5"])
	store.deleted_paintings_md5s += deleted["md5"]
	var/list/source = list("version" = 3, "paintings" = list(pending, deleted))
	var/list/result = store.run_store_operation("import", list("owner" = "galleryowner", "snapshot" = source, "sha256" = "source", "public" = FALSE))
	TEST_ASSERT_EQUAL(result["imported"], 0, "Gallery contract regression")
	TEST_ASSERT_EQUAL(store.test_commits, 0, "Gallery contract regression")

/datum/unit_test/gallery_visibility_owner_gate/Run()
	var/datum/controller/subsystem/persistent_paintings/gallery_fixture/store = allocate(/datum/controller/subsystem/persistent_paintings/gallery_fixture)
	var/list/row = gallery_test_row("owner-gate")
	store.test_snapshot = list("version" = 3, "paintings" = list(row))
	var/list/result = store.run_store_operation("patch", list("id" = row["md5"], "owner" = "someoneelse", "patch" = list("show_in_webgallery" = TRUE)))
	TEST_ASSERT(!result["ok"], "Foreign visibility change was accepted")
	TEST_ASSERT_EQUAL(store.test_commits, 0, "Gallery contract regression")
	result = store.run_store_operation("patch", list("id" = row["md5"], "owner" = "galleryowner", "patch" = list("show_in_webgallery" = TRUE)))
	TEST_ASSERT(result["ok"], "Owner visibility change was rejected")
	TEST_ASSERT_EQUAL(store.test_snapshot["paintings"][1]["show_in_webgallery"], TRUE, "Gallery contract regression")
	TEST_ASSERT_EQUAL(length(store.get_owned_paintings("galleryowner")), 1, "Gallery contract regression")
	TEST_ASSERT_NULL(store.owner_painting_data?["someoneelse"], "Gallery contract regression")

/datum/unit_test/gallery_failed_commit_and_queue/Run()
	var/datum/controller/subsystem/persistent_paintings/gallery_fixture/store = allocate(/datum/controller/subsystem/persistent_paintings/gallery_fixture)
	var/list/row = gallery_test_row("failed-commit")
	store.test_snapshot = list("version" = 3, "paintings" = list(row))
	store.test_fail = TRUE
	var/before = json_encode(store.test_snapshot)
	var/list/result = store.run_store_operation("patch", list("id" = row["md5"], "owner" = "galleryowner", "patch" = list("show_in_webgallery" = TRUE)))
	TEST_ASSERT(!result["ok"], "Injected failure was ignored")
	TEST_ASSERT_EQUAL(json_encode(store.test_snapshot), before, "Gallery contract regression")
	TEST_ASSERT(!store.store_busy, "Failed commit left queue locked")
	TEST_ASSERT_NULL(store.store_queue, "A drained failure queue should release its list")
	store.test_fail = FALSE
	result = store.run_store_operation("patch", list("id" = row["md5"], "owner" = "galleryowner", "patch" = list("show_in_webgallery" = FALSE)))
	TEST_ASSERT(result["ok"], "Queue did not recover after failure")
	TEST_ASSERT_NULL(store.store_queue, "A drained successful queue should release its list")

/datum/unit_test/gallery_import_answer_preservation/Run()
	var/datum/preferences/gallery_fixture/preferences = allocate(/datum/preferences/gallery_fixture)
	TEST_ASSERT_NULL(preferences.nova_painting_import_answer(), "Gallery contract regression")
	TEST_ASSERT(preferences.save_nova_painting_import_answer("no"), "Explicit No must save")
	TEST_ASSERT_EQUAL(preferences.nova_painting_import_answer(), "no", "Gallery contract regression")
	TEST_ASSERT(!preferences.save_nova_painting_import_answer(null), "Unanswered dialog must not overwrite No")
	var/list/upload = list(NOVA_PAINTING_IMPORT_ANSWER = "yes", "version" = 52)
	var/list/imported = prefs_import_player_root(upload, preferences.savefile.get_entry())
	TEST_ASSERT_EQUAL(imported[NOVA_PAINTING_IMPORT_ANSWER], "no", "Preferences import reset a local No")
	TEST_ASSERT(preferences.save_nova_painting_import_answer("yes"), "Admin-prompted explicit Yes must save")
	TEST_ASSERT_EQUAL(preferences.nova_painting_import_answer(), "yes", "Gallery contract regression")

/datum/unit_test/gallery_pda_default_installation/Run()
	var/obj/item/modular_computer/pda/pda = allocate(/obj/item/modular_computer/pda)
	var/count = 0
	for(var/datum/computer_file/program/portrait_printer/program in pda.stored_files)
		count++
	TEST_ASSERT_EQUAL(count, 1, "Standard PDA must contain exactly one Art Galaxy")
	var/obj/item/modular_computer/pda/crew/curator/curator = allocate(/obj/item/modular_computer/pda/crew/curator)
	count = 0
	for(var/datum/computer_file/program/portrait_printer/program in curator.stored_files)
		count++
	TEST_ASSERT_EQUAL(count, 1, "Curator PDA duplicated Art Galaxy")

/datum/unit_test/gallery_preference_write_failure/Run()
	var/datum/preferences/gallery_fixture/preferences = allocate(/datum/preferences/gallery_fixture)
	preferences.fail_flush = TRUE
	TEST_ASSERT(!preferences.save_nova_painting_import_answer("yes"), "Failed consent write must report failure")
	TEST_ASSERT_NULL(preferences.nova_painting_import_answer(), "Failed write changed unset state")
	preferences.fail_flush = FALSE
	TEST_ASSERT(preferences.save_nova_painting_import_answer("no"), "No should persist")
	preferences.fail_flush = TRUE
	TEST_ASSERT(!preferences.save_nova_painting_import_answer("yes"), "Failed Yes must not replace No")
	TEST_ASSERT_EQUAL(preferences.nova_painting_import_answer(), "no", "Failed write replaced No")

/datum/unit_test/gallery_prompt_cooldowns/Run()
	var/datum/persistent_client/gallery_fixture/admin_a = allocate(/datum/persistent_client/gallery_fixture)
	var/datum/persistent_client/gallery_fixture/admin_b = allocate(/datum/persistent_client/gallery_fixture)
	var/datum/persistent_client/gallery_fixture/target_a = allocate(/datum/persistent_client/gallery_fixture)
	var/datum/persistent_client/gallery_fixture/target_b = allocate(/datum/persistent_client/gallery_fixture)
	TEST_ASSERT(claim_nova_import_prompt(admin_a, target_a, 100), "Initial prompt should be allowed")
	TEST_ASSERT(!claim_nova_import_prompt(admin_a, target_b, 100), "Admin bypassed own cooldown with another target")
	TEST_ASSERT(!claim_nova_import_prompt(admin_b, target_a, 100), "Second admin bypassed target cooldown")
	TEST_ASSERT_EQUAL(admin_b.next_nova_painting_admin_prompt, 0, "Rejected prompt consumed admin cooldown")
	TEST_ASSERT_EQUAL(target_b.next_nova_painting_target_prompt, 0, "Rejected prompt consumed target cooldown")
	admin_a.set_client(null)
	target_a.set_client(null)
	TEST_ASSERT(!claim_nova_import_prompt(admin_a, target_a, 699), "Disconnect cleared cooldown")
	TEST_ASSERT(claim_nova_import_prompt(admin_a, target_a, 700), "One minute should release both cooldowns")

/datum/unit_test/gallery_read_only_snapshot_validation/Run()
	var/datum/controller/subsystem/persistent_paintings/gallery_fixture/store = allocate(/datum/controller/subsystem/persistent_paintings/gallery_fixture)
	store.store_writable = FALSE
	var/list/valid = gallery_test_row("valid-view")
	var/list/text_dimensions = gallery_test_row("text-dimensions")
	text_dimensions["width"] = "11"
	var/list/zero_dimensions = gallery_test_row("zero-dimensions")
	zero_dimensions["height"] = 0
	var/list/path_escape = gallery_test_row("path-escape")
	path_escape["md5"] = "../outside"
	store.apply_store_snapshot(list("version" = 3, "paintings" = list(42, text_dimensions, zero_dimensions, path_escape, valid)))
	TEST_ASSERT_EQUAL(length(store.paintings), 1, "Malformed read-only rows must not enter the gallery")
	TEST_ASSERT_EQUAL(length(store.get_owned_paintings("galleryowner")), 1, "Valid read-only artwork remains viewable")
	TEST_ASSERT(!store.store_writable, "Reading a snapshot must not enable writes without the helper")

/// Empty snapshots and accounts allocate no global payloads until requested.
/datum/unit_test/gallery_lazy_caches/Run()
	var/datum/controller/subsystem/persistent_paintings/gallery_fixture/store = allocate(/datum/controller/subsystem/persistent_paintings/gallery_fixture)
	TEST_ASSERT_NULL(store.owner_painting_data, "Owner cache must start unallocated")
	TEST_ASSERT_NULL(store.paintings_by_id, "Empty identity cache must start unallocated")
	TEST_ASSERT_NULL(store.store_queue, "Idle queue must start unallocated")
	TEST_ASSERT_NULL(store.gallery_programs, "Unused program registry must start unallocated")
	TEST_ASSERT_NULL(store.pending_canvases, "Unused canvas registry must start unallocated")
	TEST_ASSERT_NULL(store.nova_import_busy, "Disabled imports must not allocate busy state")
	TEST_ASSERT_NULL(store.nova_import_status, "Disabled imports must not allocate statuses")
	TEST_ASSERT_NULL(store.nova_painting_ids_by_owner, "Disabled imports must not retain a catalog")
	var/list/row = gallery_test_row("lazy-owner")
	store.apply_store_snapshot(list("version" = 3, "paintings" = list(row)))
	TEST_ASSERT_NULL(store.owner_painting_data, "Loading a snapshot must not prebuild every owner's UI")
	var/datum/painting/original = store.paintings_by_id[row["md5"]]
	var/list/owned = store.get_owned_paintings("galleryowner")
	TEST_ASSERT_EQUAL(length(owned), 1, "Owner query lost its painting")
	TEST_ASSERT(store.get_owned_paintings("galleryowner") == owned, "Unchanged owner payload should be reused")
	row["show_in_webgallery"] = TRUE
	store.apply_store_snapshot(list("version" = 3, "paintings" = list(row)))
	TEST_ASSERT(store.paintings_by_id[row["md5"]] == original, "Snapshot refresh replaced the live painting datum")
	TEST_ASSERT_NULL(store.owner_painting_data, "Committed change left stale owner data cached")
	owned = store.get_owned_paintings("galleryowner")
	TEST_ASSERT_EQUAL(owned[1]["show_in_webgallery"], TRUE, "Owner query returned stale publication consent")
	store.apply_store_snapshot(list("version" = 3, "paintings" = list()))
	TEST_ASSERT_NULL(store.paintings_by_id, "Empty snapshot retained the old identity cache")
	TEST_ASSERT_NULL(store.owner_painting_data, "Empty snapshot retained old owner payloads")
	owned = store.get_owned_paintings("galleryowner")
	TEST_ASSERT_EQUAL(length(owned), 0, "Deleted painting remains in owner view")
	TEST_ASSERT(store.get_owned_paintings("galleryowner") == owned, "Empty owner results should be cached")
	var/list/source = list("paintings" = list(row, gallery_test_row("foreign", "foreignowner")))
	var/list/prepared = store.prepare_nova_import(source, "galleryowner")
	var/list/ids = store.nova_painting_ids_by_owner["galleryowner"]
	TEST_ASSERT_EQUAL(length(prepared["paintings"]), 1, "Confirmation retained other owners' records")
	TEST_ASSERT_EQUAL(length(source["paintings"]), 2, "Preparing an import mutated the source snapshot")
	TEST_ASSERT_EQUAL(length(ids), 1, "Nova ID cache included another owner's artwork")
	TEST_ASSERT_EQUAL(ids[1], row["md5"], "Nova cache must contain identities, not full records")
	TEST_ASSERT_NULL(store.nova_painting_ids_by_owner?["foreignowner"], "Nova lookup cached an account that never opened a prompt")
	TEST_ASSERT_EQUAL(length(store.prepare_nova_import(source, "emptyowner")["paintings"]), 0, "Unmatched owner got Nova records")
	TEST_ASSERT(!isnull(store.nova_painting_ids_by_owner?["emptyowner"]), "Known empty account must differ from an unchecked account")
	TEST_ASSERT_NULL(store.nova_painting_ids_by_owner?["uncheckedowner"], "Unchecked account should remain unset")
	TEST_ASSERT(store.nova_painting_ids_by_owner["galleryowner"] == ids, "A second account replaced the first account's cache")

/// Exercise the user's associative key/value migration loop through the transaction builder.
/datum/unit_test/gallery_legacy_category_migration
	/// Unique fixture PNG paths owned by this test and removed on teardown.
	var/list/owned_files

/datum/unit_test/gallery_legacy_category_migration/Destroy()
	for(var/path in owned_files)
		fdel(path)
	return ..()

/datum/unit_test/gallery_legacy_category_migration/Run()
	var/datum/controller/subsystem/persistent_paintings/gallery_fixture/store = allocate(/datum/controller/subsystem/persistent_paintings/gallery_fixture)
	var/legacy_id = md5("legacy-[REF(src)]")
	var/existing_id = md5("existing-[REF(src)]")
	var/legacy_path = "data/paintings/library/[legacy_id].png"
	var/existing_path = "data/paintings/images/[existing_id].png"
	TEST_ASSERT(!fexists(legacy_path) && !fexists(existing_path), "Migration fixture must not overwrite existing artwork")
	var/icon/fixture = icon('icons/turf/floors.dmi', "floor")
	fixture.Scale(11, 11)
	LAZYADD(owned_files, legacy_path)
	TEST_ASSERT(fcopy(fixture, legacy_path), "Could not create isolated legacy PNG")
	fixture.Scale(19, 19)
	LAZYADD(owned_files, existing_path)
	TEST_ASSERT(fcopy(fixture, existing_path), "Could not create isolated canonical PNG")
	var/legacy_hash = md5(file(legacy_path))
	var/existing_hash = md5(file(existing_path))
	var/list/legacy_row = list("md5" = legacy_id, "ckey" = "galleryowner", "title" = "Legacy Artwork")
	store.test_snapshot = list(
		"version" = 0,
		"library" = list(legacy_row),
		"library_private" = list(legacy_row.Copy()),
		"library_large" = list(list("md5" = existing_id, "ckey" = "secondowner", "title" = "Existing Artwork")),
	)
	var/list/result = store.run_store_operation("migrate")
	TEST_ASSERT(result["ok"], "Legacy category migration failed")
	TEST_ASSERT_EQUAL(store.test_commits, 1, "Migration must submit one complete transaction")
	TEST_ASSERT_EQUAL(store.test_snapshot["version"], 3, "Migration did not reach version 3")
	TEST_ASSERT_EQUAL(length(store.test_snapshot["paintings"]), 2, "Duplicate categories created duplicate paintings")
	var/datum/painting/migrated = store.paintings_by_id[legacy_id]
	TEST_ASSERT_EQUAL(migrated.creator_ckey, "galleryowner", "Legacy owner was lost")
	TEST_ASSERT_EQUAL(migrated.title, "Legacy Artwork", "Legacy title was lost")
	TEST_ASSERT_EQUAL(migrated.width, 11, "Legacy PNG width was lost")
	TEST_ASSERT_EQUAL(migrated.height, 11, "Legacy PNG height was lost")
	TEST_ASSERT("library" in migrated.tags, "Original category was lost: [json_encode(migrated.tags)]")
	TEST_ASSERT("library_private" in migrated.tags, "Duplicate category was lost: [json_encode(migrated.tags)]")
	TEST_ASSERT(!migrated.show_in_webgallery, "Legacy migration must remain private")
	TEST_ASSERT(migrated.frame_type, "Version 2 frame migration was skipped")
	migrated = store.paintings_by_id[existing_id]
	TEST_ASSERT_EQUAL(migrated.creator_ckey, "secondowner", "A second category used the wrong row")
	TEST_ASSERT_EQUAL(migrated.width, 19, "Migration did not prefer the existing canonical PNG")
	TEST_ASSERT_EQUAL(length(store.test_commit["images"]), 1, "Existing canonical image was queued for replacement")
	TEST_ASSERT_EQUAL(store.test_commit["images"][1]["id"], legacy_id, "Incorrect legacy image was queued")
	TEST_ASSERT_EQUAL(md5(file(legacy_path)), legacy_hash, "Migration modified the legacy source PNG")
	TEST_ASSERT_EQUAL(md5(file(existing_path)), existing_hash, "Migration modified the canonical PNG")
	TEST_ASSERT_NULL(store.store_queue, "Migration left its queue allocated")

/// Avoid real application registration while exercising the production search cache and refresh path.
/datum/computer_file/program/portrait_printer/gallery_fixture
	/// Number of search evaluations; idle/status refreshes must not increment it.
	var/searches = 0

/datum/computer_file/program/portrait_printer/gallery_fixture/New()
	return

/datum/computer_file/program/portrait_printer/gallery_fixture/generate_matching_paintings_list()
	searches++
	matching_paintings = list()

/datum/unit_test/gallery_deferred_search/Run()
	var/datum/controller/subsystem/persistent_paintings/gallery_fixture/store = allocate(/datum/controller/subsystem/persistent_paintings/gallery_fixture)
	var/datum/computer_file/program/portrait_printer/gallery_fixture/program = allocate(/datum/computer_file/program/portrait_printer/gallery_fixture)
	program.search_string = "No matching paintings"
	LAZYADD(store.gallery_programs, program)
	var/list/first = program.gallery_browse_data()
	TEST_ASSERT_EQUAL(length(first), 0, "An empty search must not fall back to all paintings")
	TEST_ASSERT(program.gallery_browse_data() == first, "Empty search results should be cached")
	store.refresh_gallery_uis()
	TEST_ASSERT(program.gallery_browse_data() == first, "Status update discarded a valid search")
	store.refresh_gallery_uis(rebuild = TRUE)
	TEST_ASSERT_EQUAL(program.searches, 1, "Closed application recomputed its search after a commit")
	TEST_ASSERT_NULL(program.matching_paintings, "Commit failed to invalidate old search data")
	program.gallery_browse_data()
	TEST_ASSERT_EQUAL(program.searches, 2, "Opening the gallery did not refresh its invalidated search")

/// Limit gallery payloads independently of collection size, with stable selection after updates.
/datum/unit_test/gallery_bounded_payload/Run()
	var/datum/computer_file/program/portrait_printer/gallery_fixture/program = allocate(/datum/computer_file/program/portrait_printer/gallery_fixture)
	var/datum/art_galaxy_view/view = program.get_gallery_view("galleryowner")
	var/list/entries = list()
	for(var/i in 1 to 100)
		entries += list(list("ref" = "ref-[i]", "md5" = md5("fixture-[i]"), "title" = "Painting [i]", "width" = 11, "creation_date" = "Recorded date"))
	var/list/data = list()
	program.add_gallery_page(data, entries, view)
	TEST_ASSERT_EQUAL(length(data["paintings"]), 24, "Thumbnail payload must be bounded")
	TEST_ASSERT_EQUAL(data["gallery_pages"], 5, "Incorrect page count")
	TEST_ASSERT(!("width" in data["paintings"][1]), "Unused image dimensions leaked into payload")
	TEST_ASSERT(!("creation_date" in data["paintings"][1]), "Detail metadata leaked into thumbnails")
	view.page = 100
	program.add_gallery_page(data, entries, view)
	TEST_ASSERT_EQUAL(data["gallery_page"], 5, "Oversized page was not bounded")
	TEST_ASSERT_EQUAL(length(data["paintings"]), 4, "Last page should have four works")
	program.select_gallery_painting(list("selected" = "foreign-ref"), entries, view)
	TEST_ASSERT_NULL(view.selected, "Unknown reference became selected")
	program.select_gallery_painting(list("index" = -1), entries, view)
	TEST_ASSERT_NULL(view.selected, "Invalid index became selected")
	program.select_gallery_painting(list("selected" = "ref-50"), entries, view)
	program.add_gallery_page(data, entries, view)
	TEST_ASSERT_EQUAL(length(data["paintings"]), 0, "Detail view still sends thumbnails")
	TEST_ASSERT_EQUAL(data["selected_painting"]["ref"], "ref-50", "Selected detail changed")
	TEST_ASSERT_EQUAL(data["gallery_page"], 3, "Returning to thumbnails would lose the selected page")
	entries.Cut(1, 2)
	program.add_gallery_page(data, entries, view)
	TEST_ASSERT_EQUAL(data["selected_painting"]["ref"], "ref-50", "Removal before selection changed the selected painting")
	TEST_ASSERT_EQUAL(data["painting_index"], 48, "Selected position did not refresh")
	view.tab = "mine"
	program.add_gallery_page(data, entries, view)
	TEST_ASSERT_EQUAL(data["selected_painting"]["creation_date"], "Recorded date", "Owned detail lost recorded date")
	program.add_gallery_page(data, list(), view)
	TEST_ASSERT_NULL(data["selected_painting"], "Deleted selection remained open")
	TEST_ASSERT_EQUAL(length(data["paintings"]), 0, "Empty gallery returned artwork")
	TEST_ASSERT_EQUAL(data["gallery_page"], 1, "Empty gallery retained stale page")

/// Multiple viewers of one PDA must not clear or inherit each other's personal navigation.
/datum/unit_test/gallery_viewer_navigation/Run()
	var/datum/computer_file/program/portrait_printer/gallery_fixture/program = allocate(/datum/computer_file/program/portrait_printer/gallery_fixture)
	var/datum/art_galaxy_view/owner = program.get_gallery_view("galleryowner")
	var/datum/art_galaxy_view/visitor = program.get_gallery_view("visitor")
	owner.tab = "mine"
	visitor.tab = "mine"
	var/list/entries = list(list("ref" = "own-painting", "md5" = md5("personal"), "title" = "Personal painting"))
	program.select_gallery_painting(list("selected" = "own-painting"), entries, owner)
	var/list/data = list()
	for(var/i in 1 to 3)
		program.add_gallery_page(data, entries, owner)
		TEST_ASSERT_EQUAL(data["selected_painting"]?["ref"], "own-painting", "Another viewer's refresh closed the owner's detail")
		program.add_gallery_page(data, list(), visitor)
		TEST_ASSERT_NULL(data["selected_painting"], "Another viewer inherited the owner's painting")
	visitor.tab = "browse"
	visitor.page = 2
	program.add_gallery_page(data, entries, owner)
	TEST_ASSERT_EQUAL(data["gallery_tab"], "mine", "Another viewer changed the owner's tab")
	TEST_ASSERT_EQUAL(data["gallery_page"], 1, "Another viewer changed the owner's page")
	TEST_ASSERT_EQUAL(data["selected_painting"]?["ref"], "own-painting", "Another viewer's navigation cleared the owner's detail")
	program.add_gallery_page(data, list(), owner)
	TEST_ASSERT_NULL(data["selected_painting"], "Deleting the selected artwork must still close its detail")
