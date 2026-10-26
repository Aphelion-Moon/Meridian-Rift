use super::*;
use tempfile::TempDir;

const ID: &str = "0123456789abcdef0123456789abcdef";
const OTHER: &str = "fedcba9876543210fedcba9876543210";
const TOKEN: &str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
/// Create an isolated store whose entire filesystem lifetime belongs to the test.
fn fixture() -> (TempDir, Store) {
    let dir = tempfile::tempdir().unwrap();
    let store = Store::for_test(dir.path());
    (dir, store)
}
/// Build a small valid record with private tags and unknown metadata to preserve.
fn painting(id: &str) -> Value {
    json!({"md5":id,"title":"An original","creator_ckey":"alice","creator_name":"Anonymous","creation_date":"Mon Sep 21 12:00:00 2026","width":11,"height":11,"tags":["library_private"],"show_in_webgallery":0,"future_field":{"preserve":true}})
}
/// Encode a real 11-by-11 PNG so validation exercises decoded pixels.
fn png() -> Vec<u8> {
    let mut bytes = Vec::new();
    {
        let mut writer = png::Encoder::new(&mut bytes, 11, 11)
            .write_header()
            .unwrap();
        writer.write_image_data(&[0; 121]).unwrap();
    }
    bytes
}
/// Read the live collection through the same locked recovery path as production.
fn snapshot(store: &Store) -> Value {
    store
        .execute(&json!({"op":"snapshot","source":"live"}))
        .unwrap()
}
/// Build a commit against the latest snapshot with explicit changes to retained fields.
fn request(store: &Store, paintings: Vec<Value>) -> Value {
    let snapshot = snapshot(store);
    let originals = rows(&snapshot["snapshot"]);
    let mut changes = Vec::new();
    for row in &paintings {
        let id = row["md5"].as_str().unwrap();
        if let Some(original) = originals.get(id) {
            let fields: Vec<_> = KNOWN_FIELDS
                .iter()
                .filter(|field| **field != "md5" && original.get(**field) != row.get(**field))
                .copied()
                .collect();
            if !fields.is_empty() {
                changes.push(json!({"id":id,"fields":fields}));
            }
        }
    }
    json!({"op":"submit_commit","expected_sha256":snapshot["sha256"],"candidate":{"version":3,"paintings":paintings},"images":[],"deletes":[],"changed_fields":changes})
}
/// Write a synthetic PNG into the game staging location for one painting identity.
fn stage(store: &Store, id: &str) {
    let path = child(&store.live, &format!("paintings/staging/{TOKEN}/{id}.png")).unwrap();
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, png()).unwrap();
}
/// Prepare a new painting and its staged image for an atomic append.
fn add_request(store: &Store, id: &str) -> Value {
    stage(store, id);
    let mut request = request(store, vec![painting(id)]);
    request["images"] = json!([{"id":id,"source":"staged","stage":TOKEN}]);
    request
}
/// Commit one fixture painting as the baseline for mutation and recovery checks.
fn seed(store: &Store) {
    let request = add_request(store, ID);
    store.execute(&request).unwrap();
}
/// Inject a checkpoint failure and clear it before inspecting restart recovery.
fn interrupted(store: &Store, request: &Value, point: &str) {
    FAILPOINT.with(|p| *p.borrow_mut() = Some(point.into()));
    assert_eq!(store.execute(request).unwrap_err().code, "injected");
    FAILPOINT.with(|p| *p.borrow_mut() = None);
}

/// A first read may expose an empty collection without writing a new database.
#[test]
fn missing_live_is_an_empty_snapshot_without_creating_database() {
    let (_dir, store) = fixture();
    let result = snapshot(&store);
    assert_eq!(result["exists"], false);
    assert_eq!(result["sha256"], hash(b""));
    assert!(!store.live.join("paintings.json").exists());
}
/// A successful append retains unknown fields and leaves a valid image with no active journal.
#[test]
fn append_preserves_unknown_metadata_and_decodes_png() {
    let (_dir, store) = fixture();
    seed(&store);
    assert_eq!(snapshot(&store)["snapshot"]["paintings"][0], painting(ID));
    assert_eq!(fs::read(store.image(ID).unwrap()).unwrap(), png());
    assert!(!store.private("journal.json").unwrap().exists());
}
/// A no-op must leave database bytes, timestamps, images, and backup state untouched.
#[test]
fn duplicate_only_is_byte_and_timestamp_stable() {
    let (_dir, store) = fixture();
    seed(&store);
    let path = store.live.join("paintings.json");
    let before = fs::read(&path).unwrap();
    let modified = fs::metadata(&path).unwrap().modified().unwrap();
    let request = request(&store, vec![painting(ID)]);
    assert_eq!(store.execute(&request).unwrap()["changed"], false);
    assert_eq!(fs::read(&path).unwrap(), before);
    assert_eq!(fs::metadata(path).unwrap().modified().unwrap(), modified);
    assert!(!store.private("last-good.json").unwrap().exists());
}
/// Omitting an unknown field from the submitted candidate must preserve its native value.
#[test]
fn unknown_fields_cannot_be_dropped() {
    let (_dir, store) = fixture();
    seed(&store);
    let mut painting = painting(ID);
    painting.as_object_mut().unwrap().remove("future_field");
    let request = request(&store, vec![painting]);
    let result = store.execute(&request).unwrap();
    assert_eq!(result["changed"], false);
    assert_eq!(
        result["snapshot"]["paintings"][0]["future_field"],
        json!({"preserve":true})
    );
}
/// Model BYOND JSON type loss for booleans and empty objects recursively.
fn byond_roundtrip(value: &Value) -> Value {
    match value {
        Value::Bool(value) => json!(if *value { 1 } else { 0 }),
        Value::Object(value) if value.is_empty() => json!([]),
        Value::Object(value) => Value::Object(
            value
                .iter()
                .map(|(key, value)| (key.clone(), byond_roundtrip(value)))
                .collect(),
        ),
        Value::Array(value) => Value::Array(value.iter().map(byond_roundtrip).collect()),
        value => value.clone(),
    }
}
/// Seed native JSON values whose types would be lost in a BYOND round trip.
fn raw_metadata_fixture(store: &Store) -> Value {
    let mut record = painting(ID);
    record["show_in_webgallery"] = json!(true);
    record["future_field"] = json!({"enabled":true,"empty":{},"list":[],"nested":[false,{}]});
    let value =
        json!({"version":3,"paintings":[record],"future_header":{"empty":{},"enabled":false}});
    fs::write(store.live.join("paintings.json"), value.to_string()).unwrap();
    fs::write(store.image(ID).unwrap(), png()).unwrap();
    value
}
/// Reconstruction must recognize unchanged content despite BYOND type conversion.
#[test]
fn byond_roundtrip_noop_preserves_original_bytes_and_json_types() {
    let (_dir, store) = fixture();
    let raw = raw_metadata_fixture(&store);
    let before = fs::read(store.live.join("paintings.json")).unwrap();
    let mut request = request(&store, vec![]);
    request["candidate"] = byond_roundtrip(&raw);
    request["changed_fields"] = json!([]);
    let result = store.execute(&request).unwrap();
    assert_eq!(result["changed"], false);
    assert_eq!(result["snapshot"], raw);
    assert_eq!(fs::read(store.live.join("paintings.json")).unwrap(), before);
}
/// An explicit field patch must leave every unlisted value and JSON type intact.
#[test]
fn explicit_patch_preserves_other_fields_unknown_objects_and_boolean_consent() {
    let (_dir, store) = fixture();
    let raw = raw_metadata_fixture(&store);
    let mut request = request(&store, vec![]);
    request["candidate"] = byond_roundtrip(&raw);
    request["candidate"]["paintings"][0]["title"] = json!("New title");
    request["changed_fields"] = json!([{"id":ID,"fields":["title"]}]);
    let result = store.execute(&request).unwrap();
    let mut expected = raw;
    expected["paintings"][0]["title"] = json!("New title");
    assert_eq!(result["snapshot"], expected);
}
/// Appending artwork must preserve existing rows and unknown top-level metadata.
#[test]
fn mixed_append_preserves_existing_native_json_types() {
    let (_dir, store) = fixture();
    let raw = raw_metadata_fixture(&store);
    stage(&store, OTHER);
    let mut request = request(&store, vec![]);
    request["candidate"] = byond_roundtrip(&raw);
    request["candidate"]["paintings"]
        .as_array_mut()
        .unwrap()
        .push(painting(OTHER));
    request["changed_fields"] = json!([]);
    request["images"] = json!([{"id":OTHER,"source":"staged","stage":TOKEN}]);
    let result = store.execute(&request).unwrap();
    assert_eq!(result["snapshot"]["paintings"][0], raw["paintings"][0]);
    assert_eq!(result["snapshot"]["future_header"], raw["future_header"]);
}
/// Imported records must retain native source types instead of the DM candidate representation.
#[test]
fn nova_import_preserves_raw_unknown_booleans_and_empty_objects() {
    let (_dir, store) = fixture();
    let mut row = painting(ID);
    row["future_field"] = json!({"boolean":true,"empty":{},"nested":[false,{}]});
    let source = json!({"version":3,"paintings":[row]});
    fs::write(store.nova.join("paintings.json"), source.to_string()).unwrap();
    fs::write(store.nova.join(format!("paintings/images/{ID}.png")), png()).unwrap();
    let mut request = request(&store, vec![byond_roundtrip(&source["paintings"][0])]);
    request["images"] = json!([{"id":ID,"source":"nova"}]);
    request["nova_sha256"] = json!(store.nova_snapshot().unwrap().1);
    let result = store.execute(&request).unwrap();
    assert_eq!(result["snapshot"]["paintings"][0], source["paintings"][0]);
}
/// Explicit patches may change only supported metadata fields, never identity.
#[test]
fn field_descriptors_cannot_change_id_or_unknown_fields() {
    let (_dir, store) = fixture();
    seed(&store);
    for field in ["md5", "future_field"] {
        let mut request = request(&store, vec![painting(ID)]);
        request["changed_fields"] = json!([{"id":ID,"fields":[field]}]);
        assert!(store.execute(&request).is_err());
    }
}
/// Publishing must retain the original signature and date and produce a verifiable prior backup.
#[test]
fn changing_visibility_retains_original_attribution() {
    let (_dir, store) = fixture();
    seed(&store);
    let mut record = painting(ID);
    record["show_in_webgallery"] = json!(1);
    let result = store
        .execute(&request(&store, vec![record.clone()]))
        .unwrap();
    assert_eq!(result["snapshot"]["paintings"][0], record);
    let backup: Backup =
        serde_json::from_slice(&fs::read(store.private("last-good.json").unwrap()).unwrap())
            .unwrap();
    assert_eq!(hash(backup.bytes.as_bytes()), backup.sha256);
}
/// A corrupt input image must fail before visible files or recovery state change.
#[test]
fn invalid_source_png_has_no_database_effect() {
    let (_dir, store) = fixture();
    let request = add_request(&store, ID);
    fs::write(
        store
            .live
            .join(format!("paintings/staging/{TOKEN}/{ID}.png")),
        b"broken",
    )
    .unwrap();
    assert!(store.execute(&request).is_err());
    assert_eq!(snapshot(&store)["exists"], false);
    assert!(!store.private("journal.json").unwrap().exists());
}
/// A readable PNG header is insufficient when the file is incomplete.
#[test]
fn truncated_png_is_rejected() {
    let row = painting(ID);
    let mut bytes = png();
    bytes.truncate(bytes.len() - 8);
    assert!(validate_png(&bytes, &row).is_err());
}
/// Reject oversized PNG input and dimensions inconsistent with the record.
#[test]
fn png_size_and_declared_dimensions_must_match() {
    let mut row = painting(ID);
    row["width"] = json!(19);
    row["height"] = json!(19);
    assert!(validate_png(&png(), &row).is_err());
}
/// A stale expected hash must not overwrite a newer committed painting.
#[test]
fn stale_snapshot_rejected_without_overwriting() {
    let (_dir, store) = fixture();
    let stale = add_request(&store, OTHER);
    seed(&store);
    assert_eq!(store.execute(&stale).unwrap_err().code, "conflict");
    assert_eq!(snapshot(&store)["snapshot"]["paintings"][0]["md5"], ID);
}
/// A second store handle must reject a snapshot while another writer holds the lock.
#[test]
fn competing_os_lock_rejects_snapshot() {
    let (_dir, store) = fixture();
    let lock = store.lock().unwrap();
    assert_eq!(
        store
            .execute(&json!({"op":"snapshot","source":"live"}))
            .unwrap_err()
            .code,
        "busy"
    );
    drop(lock);
    snapshot(&store);
}
/// A dropped writer lock must be free at once, not whenever Windows gets to the closed handle.
#[test]
fn released_writer_lock_is_immediately_available() {
    let (_dir, store) = fixture();
    for _ in 0..500 {
        drop(store.lock().unwrap());
    }
}
/// Verify that writer exclusion applies across processes, not merely threads.
#[test]
fn second_process_cannot_acquire_writer_lock() {
    let (dir, store) = fixture();
    let _lock = store.lock().unwrap();
    let status = std::process::Command::new(std::env::current_exe().unwrap())
        .args(["--exact", "store::tests::lock_child_process", "--ignored"])
        .env("PAINTING_STORE_TEST_LOCK_ROOT", dir.path())
        .status()
        .unwrap();
    assert!(status.success());
}
/// Run only as the lock test child and assert that its parent retains exclusive ownership.
#[test]
#[ignore = "Invoked by second_process_cannot_acquire_writer_lock with a private root"]
fn lock_child_process() {
    let root = std::env::var_os("PAINTING_STORE_TEST_LOCK_ROOT").expect("test-only child root");
    let store = Store::for_test(Path::new(&root));
    assert_eq!(
        store
            .execute(&json!({"op":"snapshot","source":"live"}))
            .unwrap_err()
            .code,
        "busy"
    );
}
/// A journal written before image promotion must roll back to an empty collection.
#[test]
fn journal_before_promotion_recovers_without_visible_changes() {
    let (_dir, store) = fixture();
    let request = add_request(&store, ID);
    interrupted(&store, &request, "journal");
    assert_eq!(snapshot(&store)["exists"], false);
    assert!(!store.image(ID).unwrap().exists());
}
/// Recovery must remove the promoted image when metadata never reached its commit point.
#[test]
fn interrupted_image_promotion_removes_only_its_own_image() {
    let (_dir, store) = fixture();
    let request = add_request(&store, ID);
    interrupted(&store, &request, "image");
    assert!(store.image(ID).unwrap().exists());
    assert_eq!(snapshot(&store)["exists"], false);
    assert!(!store.image(ID).unwrap().exists());
}
/// After metadata commits, recovery must retain the new image and finish cleanup.
#[test]
fn interrupted_commit_preserves_new_database_and_image() {
    let (_dir, store) = fixture();
    let request = add_request(&store, ID);
    interrupted(&store, &request, "commit");
    assert_eq!(snapshot(&store)["snapshot"]["paintings"][0]["md5"], ID);
    assert!(store.image(ID).unwrap().exists());
    assert!(!store.private("journal.json").unwrap().exists());
}
/// A committed metadata deletion must eventually remove its exact image after restart.
#[test]
fn committed_deletion_retries_cleanup_after_restart() {
    let (_dir, store) = fixture();
    seed(&store);
    let mut request = request(&store, vec![]);
    request["deletes"] = json!([ID]);
    interrupted(&store, &request, "commit");
    assert!(store.image(ID).unwrap().exists());
    assert_eq!(snapshot(&store)["snapshot"]["paintings"], json!([]));
    assert!(!store.image(ID).unwrap().exists());
}
/// Recovery must preserve an unexpected valid database and require operator investigation.
#[test]
fn unexplained_valid_database_blocks_recovery() {
    let (_dir, store) = fixture();
    let request = add_request(&store, ID);
    interrupted(&store, &request, "image");
    let external = br#"{"version":3,"paintings":[],"external":true}"#;
    fs::write(store.live.join("paintings.json"), external).unwrap();
    assert_eq!(
        store
            .execute(&json!({"op":"snapshot","source":"live"}))
            .unwrap_err()
            .code,
        "recovery"
    );
    assert_eq!(
        fs::read(store.live.join("paintings.json")).unwrap(),
        external
    );
}
/// A damaged live database may be restored only from the verified prior snapshot.
#[test]
fn malformed_database_restores_only_verified_journal_before() {
    let (_dir, store) = fixture();
    seed(&store);
    let mut record = painting(ID);
    record["show_in_webgallery"] = json!(1);
    let request = request(&store, vec![record]);
    interrupted(&store, &request, "journal");
    fs::write(store.live.join("paintings.json"), b"{").unwrap();
    assert_eq!(
        snapshot(&store)["snapshot"]["paintings"][0]["show_in_webgallery"],
        0
    );
}
/// Recovery must fail closed when a snapshot sidecar no longer matches its digest.
#[test]
fn corrupted_sidecar_blocks_recovery() {
    let (_dir, store) = fixture();
    let request = add_request(&store, ID);
    interrupted(&store, &request, "journal");
    fs::write(store.private("after.json").unwrap(), b"{}").unwrap();
    assert!(store
        .execute(&json!({"op":"snapshot","source":"live"}))
        .is_err());
    assert!(!store.live.join("paintings.json").exists());
}
/// Matching image bytes alone do not authorize deleting a file created by another writer.
#[test]
fn recovery_does_not_delete_identical_unowned_image() {
    let (_dir, store) = fixture();
    let request = add_request(&store, ID);
    interrupted(&store, &request, "journal");
    fs::write(store.image(ID).unwrap(), png()).unwrap();
    assert!(store
        .execute(&json!({"op":"snapshot","source":"live"}))
        .is_err());
    assert!(store.image(ID).unwrap().exists());
}
/// An existing destination image takes precedence even when no metadata references it.
#[test]
fn orphan_destination_is_never_overwritten() {
    let (_dir, store) = fixture();
    let request = add_request(&store, ID);
    fs::write(store.image(ID).unwrap(), b"preexisting orphan").unwrap();
    assert!(store.execute(&request).is_err());
    assert_eq!(
        fs::read(store.image(ID).unwrap()).unwrap(),
        b"preexisting orphan"
    );
}
/// Nova imports must preserve source attribution while applying only explicit new visibility.
#[test]
fn nova_import_uses_native_source_metadata_and_explicit_visibility() {
    let (_dir, store) = fixture();
    let source = json!({"version":3,"paintings":[painting(ID)]});
    fs::write(store.nova.join("paintings.json"), source.to_string()).unwrap();
    fs::write(store.nova.join(format!("paintings/images/{ID}.png")), png()).unwrap();
    let nova = store
        .execute(&json!({"op":"snapshot","source":"nova"}))
        .unwrap();
    let mut request = request(&store, vec![painting(ID)]);
    request["nova_sha256"] = nova["sha256"].clone();
    request["images"] = json!([{"id":ID,"source":"nova"}]);
    request["candidate"]["paintings"][0]["show_in_webgallery"] = json!(1);
    request["candidate"]["paintings"][0]["title"] = json!("Changed");
    let result = store.execute(&request).unwrap();
    assert_eq!(result["changed"], true);
    assert_eq!(
        result["snapshot"]["paintings"][0]["title"],
        source["paintings"][0]["title"]
    );
    assert_eq!(result["snapshot"]["paintings"][0]["show_in_webgallery"], 1);
}
/// An invalid source fingerprint must prevent any Nova import commit.
#[test]
fn source_change_and_conflicting_identity_fail_closed() {
    let (_dir, store) = fixture();
    let source = json!({"version":3,"paintings":[painting(ID),painting(ID)]});
    fs::write(store.nova.join("paintings.json"), source.to_string()).unwrap();
    assert!(store
        .execute(&json!({"op":"snapshot","source":"nova"}))
        .is_err());
}
/// Historical decimal round IDs must retain their source string representation.
#[test]
fn historical_round_identifiers_remain_strings() {
    let (_dir, store) = fixture();
    let mut row = painting(ID);
    row["creation_round_id"] = json!("3826");
    let source = json!({"version":3,"paintings":[row]});
    fs::write(store.nova.join("paintings.json"), source.to_string()).unwrap();
    fs::write(store.nova.join(format!("paintings/images/{ID}.png")), png()).unwrap();
    let snapshot = store.nova_snapshot().unwrap();
    let mut request = request(&store, vec![source["paintings"][0].clone()]);
    request["images"] = json!([{"id":ID,"source":"nova"}]);
    request["nova_sha256"] = json!(snapshot.1);
    let result = store.execute(&request).unwrap();
    assert_eq!(
        result["snapshot"]["paintings"][0]["creation_round_id"],
        json!("3826")
    );
}
/// Round-ID compatibility must still reject oversized or nondecimal strings.
#[test]
fn round_identifiers_reject_unbounded_or_non_decimal_text() {
    for bad in [
        "",
        "no SQL",
        "3.5",
        "-1",
        "1000000000000001",
        "99999999999999999999999999999999999999",
    ] {
        let mut row = painting(ID);
        row["creation_round_id"] = json!(bad);
        assert!(validate(&json!({"version":3,"paintings":[row]}), false).is_err());
    }
}
/// A confirmed source hash must not authorize records from a subsequently replaced backup.
#[test]
fn source_replacement_after_confirmation_is_rejected() {
    let (_dir, store) = fixture();
    let source = json!({"version":3,"paintings":[painting(ID)]});
    fs::write(store.nova.join("paintings.json"), source.to_string()).unwrap();
    fs::write(store.nova.join(format!("paintings/images/{ID}.png")), png()).unwrap();
    let digest = store.nova_snapshot().unwrap().1;
    let mut request = request(&store, vec![painting(ID)]);
    request["images"] = json!([{"id":ID,"source":"nova"}]);
    request["nova_sha256"] = json!(digest);
    let mut changed = source;
    changed["paintings"][0]["title"] = json!("Replaced source");
    fs::write(store.nova.join("paintings.json"), changed.to_string()).unwrap();
    assert!(store.execute(&request).is_err());
    assert!(!store.live.join("paintings.json").exists());
}
/// Declared image deletions must match removed metadata identities exactly.
#[test]
fn delete_requires_an_exact_candidate_diff() {
    let (_dir, store) = fixture();
    seed(&store);
    assert!(store.execute(&request(&store, vec![])).is_err());
    let mut request = request(&store, vec![painting(ID)]);
    request["deletes"] = json!([ID]);
    assert!(store.execute(&request).is_err());
    assert!(store.image(ID).unwrap().exists());
}
/// Repeating recovery after interrupted deletion cleanup must preserve the committed empty collection.
#[test]
fn interrupted_cleanup_after_deletion_is_idempotent() {
    let (_dir, store) = fixture();
    seed(&store);
    let mut request = request(&store, vec![]);
    request["deletes"] = json!([ID]);
    interrupted(&store, &request, "delete");
    assert!(!store.image(ID).unwrap().exists());
    assert_eq!(snapshot(&store)["snapshot"]["paintings"], json!([]));
}
/// The commit boundary accepts only numeric zero or one for newly supplied visibility.
#[test]
fn new_or_changed_visibility_requires_explicit_numeric_consent() {
    let (_dir, store) = fixture();
    let mut request = add_request(&store, ID);
    request["candidate"]["paintings"][0]["show_in_webgallery"] = json!("yes");
    assert!(store.execute(&request).is_err());
    seed(&store);
    let mut record = painting(ID);
    record["show_in_webgallery"] = json!(true);
    assert!(store.execute(&request_for_record(&store, record)).is_err());
}
/// Build a one-record candidate for focused metadata validation checks.
fn request_for_record(store: &Store, record: Value) -> Value {
    request(store, vec![record])
}
/// Windows junctions below a trusted root must be rejected like other linked descendants.
#[cfg(windows)]
#[test]
fn junction_source_directory_is_rejected_without_symlink_privilege() {
    let (dir, store) = fixture();
    let request = add_request(&store, ID);
    let path = store.live.join(format!("paintings/staging/{TOKEN}"));
    fs::remove_file(path.join(format!("{ID}.png"))).unwrap();
    fs::remove_dir(&path).unwrap();
    let external = dir.path().join("outside");
    fs::create_dir(&external).unwrap();
    fs::write(external.join(format!("{ID}.png")), png()).unwrap();
    let status = std::process::Command::new("cmd.exe")
        .args(["/c", "mklink", "/J"])
        .arg(&path)
        .arg(&external)
        .output()
        .unwrap();
    assert!(
        status.status.success(),
        "{}",
        String::from_utf8_lossy(&status.stderr)
    );
    assert!(store.execute(&request).is_err());
    // Remove the junction itself through Rust, never traverse its target.
    fs::remove_dir(&path).unwrap();
}
/// A traversal token must never select a staging file outside the trusted directory.
#[test]
fn staged_tokens_cannot_escape_the_root() {
    let (_dir, store) = fixture();
    let mut request = add_request(&store, ID);
    request["images"][0]["stage"] = json!("../../outside");
    assert!(store.execute(&request).is_err());
}
/// Migration may reuse an existing valid PNG without replacing its bytes.
#[test]
fn legacy_existing_image_can_migrate_without_overwrite() {
    let (_dir, store) = fixture();
    fs::write(store.image(ID).unwrap(), png()).unwrap();
    fs::write(
        store.live.join("paintings.json"),
        json!({"library":[{"md5":ID,"ckey":"alice"}]}).to_string(),
    )
    .unwrap();
    assert_eq!(
        store.execute(&request(&store, vec![painting(ID)])).unwrap()["changed"],
        true
    );
}
/// A symbolic-link image source must fail validation before import.
#[test]
fn linked_source_is_rejected() {
    let (dir, store) = fixture();
    let request = add_request(&store, ID);
    let path = store
        .live
        .join(format!("paintings/staging/{TOKEN}/{ID}.png"));
    remove(&path).unwrap();
    let external = dir.path().join("outside.png");
    fs::write(&external, png()).unwrap();
    #[cfg(unix)]
    std::os::unix::fs::symlink(&external, &path).unwrap();
    #[cfg(windows)]
    {
        if let Err(error) = std::os::windows::fs::symlink_file(&external, &path) {
            // Developer Mode is not guaranteed on Windows CI. The reparse/junction test
            // below still exercises the same guard without symlink privilege.
            if error.raw_os_error() == Some(1314) {
                return;
            }
            panic!("{error}");
        }
    }
    assert!(store.execute(&request).is_err());
}
