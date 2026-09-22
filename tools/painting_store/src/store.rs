use atomicwrites::{AllowOverwrite, AtomicFile, DisallowOverwrite};
use fs2::FileExt;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::{HashMap, HashSet};
use std::fs::{self, File, OpenOptions};
use std::io::{Cursor, Read, Write};
use std::path::{Component, Path, PathBuf};

pub const MAX_JSON: usize = 32 * 1024 * 1024;
const MAX_ROWS: usize = 10_000;
const MAX_PNG: usize = 1024 * 1024;
const DIMENSIONS: &[(u64, u64)] = &[
    (11, 11),
    (19, 19),
    (23, 19),
    (23, 23),
    (24, 24),
    (36, 24),
    (45, 27),
];
const KNOWN_FIELDS: &[&str] = &[
    "md5",
    "title",
    "creator_ckey",
    "creator_name",
    "creation_date",
    "creation_round_id",
    "tags",
    "patron_ckey",
    "patron_name",
    "credit_value",
    "width",
    "height",
    "medium",
    "frame_type",
    "show_in_webgallery",
];
const CATEGORIES: &[&str] = &[
    "library",
    "library_secure",
    "library_private",
    "library_large",
    "library_large_private",
];

#[derive(Clone, Debug)]
pub struct Error {
    code: &'static str,
    message: String,
}
impl Error {
    /// Build a stable API error code with a human-readable failure description.
    pub fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
    /// Encode a terminal failure using the JSON envelope expected by BYOND polling.
    pub fn value(&self) -> Value {
        json!({"ok":false,"pending":false,"error":{"code":self.code,"message":self.message}})
    }
}
type Result<T> = std::result::Result<T, Error>;
impl From<std::io::Error> for Error {
    /// Preserve filesystem error details under the API filesystem-error code.
    fn from(error: std::io::Error) -> Self {
        Self::new("io", error.to_string())
    }
}
/// Reject a failed invariant before the operation can proceed.
fn require(condition: bool, message: &str) -> Result<()> {
    if condition {
        Ok(())
    } else {
        Err(Error::new("validation", message))
    }
}
/// Compute the lowercase SHA-256 used for snapshot and image integrity checks.
fn hash(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}
/// Accept only a fixed-length lowercase hexadecimal identity or digest.
fn hex(value: &str, length: usize) -> bool {
    value.len() == length
        && value
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}
/// Borrow a required JSON string, reporting a request error for missing or wrong types.
fn str_field<'a>(value: &'a Value, field: &str) -> Result<&'a str> {
    value
        .get(field)
        .and_then(Value::as_str)
        .ok_or_else(|| Error::new("request", format!("Missing string field {field}")))
}
/// Decode JSON bytes without converting native JSON types through BYOND.
fn parse(bytes: &[u8]) -> Result<Value> {
    serde_json::from_slice(bytes).map_err(|_| Error::new("json", "Painting JSON is invalid"))
}
/// Read at most the allowed size, rejecting files that grow during the read.
fn read_bounded(path: &Path, limit: usize) -> Result<Vec<u8>> {
    let file = File::open(path)?;
    require(
        file.metadata()?.len() <= limit as u64,
        "File exceeds size limit",
    )?;
    let mut bytes = Vec::new();
    file.take((limit + 1) as u64).read_to_end(&mut bytes)?;
    require(bytes.len() <= limit, "File exceeds size limit")?;
    Ok(bytes)
}
/// Detect symbolic links and Windows reparse points before following a descendant path.
fn reparse(metadata: &fs::Metadata) -> bool {
    if metadata.file_type().is_symlink() {
        return true;
    }
    #[cfg(windows)]
    {
        use std::os::windows::fs::MetadataExt;
        if metadata.file_attributes() & 0x400 != 0 {
            return true;
        }
    }
    false
}
/// The top-level data directory can be a verified TGS junction. Descendants cannot.
fn child(root: &Path, relative: &str) -> Result<PathBuf> {
    let mut result = root.to_path_buf();
    for component in Path::new(relative).components() {
        let Component::Normal(component) = component else {
            return Err(Error::new("path", "Invalid path component"));
        };
        result.push(component);
        match fs::symlink_metadata(&result) {
            Ok(metadata) => require(!reparse(&metadata), "Linked painting paths are forbidden")?,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => (),
            Err(error) => return Err(error.into()),
        }
    }
    Ok(result)
}
/// Flush complete bytes to a same-filesystem temporary file before atomic publication.
fn atomic(path: &Path, bytes: &[u8], overwrite: bool) -> Result<()> {
    AtomicFile::new(
        path,
        if overwrite {
            AllowOverwrite
        } else {
            DisallowOverwrite
        },
    )
    .write(|file| -> std::io::Result<()> {
        file.write_all(bytes)?;
        file.sync_all()
    })
    .map_err(|error| Error::new("io", error.to_string()))
}
/// Remove one file idempotently and sync its parent directory on Unix.
fn remove(path: &Path) -> Result<()> {
    match fs::remove_file(path) {
        Ok(()) => {
            #[cfg(unix)]
            File::open(path.parent().unwrap())?.sync_all()?;
            Ok(())
        }
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error.into()),
    }
}

/// Validate bounded painting metadata and unique identities, optionally allowing legacy schemas.
fn validate(value: &Value, legacy: bool) -> Result<()> {
    let object = value
        .as_object()
        .ok_or_else(|| Error::new("schema", "Database must be an object"))?;
    let version = value.get("version").and_then(Value::as_u64).unwrap_or(0);
    require(
        version <= 3 && (legacy || version == 3),
        "Unsupported painting database version",
    )?;
    if version == 0 {
        require(legacy, "Legacy database cannot be committed")?;
        let mut count = 0;
        for (category, rows) in object {
            if category == "version" {
                continue;
            }
            require(
                CATEGORIES.contains(&category.as_str()),
                "Unknown legacy painting category",
            )?;
            let rows = rows
                .as_array()
                .ok_or_else(|| Error::new("schema", "Legacy category must be a list"))?;
            count += rows.len();
            for row in rows {
                require(hex(str_field(row, "md5")?, 32), "Invalid legacy identity")?;
            }
        }
        return require(count <= MAX_ROWS, "Too many paintings");
    }
    let rows = value
        .get("paintings")
        .and_then(Value::as_array)
        .ok_or_else(|| Error::new("schema", "Missing painting array"))?;
    require(rows.len() <= MAX_ROWS, "Too many paintings")?;
    let mut ids = HashSet::new();
    for row in rows {
        require(row.is_object(), "Painting must be an object")?;
        let id = str_field(row, "md5")?;
        require(
            hex(id, 32) && ids.insert(id),
            "Invalid or duplicate painting identity",
        )?;
        let width = row.get("width").and_then(Value::as_u64).unwrap_or(0);
        let height = row.get("height").and_then(Value::as_u64).unwrap_or(0);
        require(
            DIMENSIONS.contains(&(width, height)),
            "Unsupported painting dimensions",
        )?;
        for field in [
            "title",
            "creator_name",
            "creation_date",
            "patron_name",
            "medium",
            "frame_type",
        ] {
            if let Some(value) = row.get(field) {
                require(
                    value.is_null()
                        || value
                            .as_str()
                            .is_some_and(|v| v.len() <= 4096 && !v.contains('\0')),
                    "Invalid painting text",
                )?;
            }
        }
        for field in ["creator_ckey", "patron_ckey"] {
            if let Some(value) = row.get(field) {
                require(
                    value.is_null()
                        || value.as_str().is_some_and(|v| {
                            v.len() <= 128
                                && v.bytes()
                                    .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit())
                        }),
                    "Invalid painting owner",
                )?;
            }
        }
        if let Some(tags) = row.get("tags").filter(|v| !v.is_null()) {
            require(
                tags.as_array().is_some_and(|tags| {
                    tags.len() <= 64
                        && tags
                            .iter()
                            .all(|tag| tag.as_str().is_some_and(|s| s.len() <= 512))
                }),
                "Invalid painting tags",
            )?;
        }
        for field in ["credit_value", "creation_round_id"] {
            if let Some(value) = row.get(field) {
                require(
                    value.is_null()
                        || value
                            .as_f64()
                            .is_some_and(|n| n.is_finite() && n.abs() <= 1e15)
                        // BYOND's SQL round identifier is historically serialized as text.
                        // Keep its original type; only bounded decimal identifiers are valid.
                        || (field == "creation_round_id" && value.as_str().is_some_and(|text| {
                            !text.is_empty() && text.len() <= 16 && text.bytes().all(|byte| byte.is_ascii_digit()) && text.parse::<u64>().is_ok_and(|number| number <= 1_000_000_000_000_000)
                        })),
                    "Invalid numeric metadata",
                )?;
            }
        }
        // Historical unknown consent values remain readable but never normalize to public.
        // DM writes the known field as exactly 0 or 1 for changed/new records.
    }
    Ok(())
}
/// Index painting records by pixel identity without cloning their metadata.
fn rows(value: &Value) -> HashMap<String, &Value> {
    value
        .get("paintings")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|row| {
            row.get("md5")
                .and_then(Value::as_str)
                .map(|id| (id.to_owned(), row))
        })
        .collect()
}

/// BYOND JSON decoding erases booleans and the empty-object/empty-list distinction.
/// Therefore only explicitly named known fields may travel back through DM.
/// Untouched existing rows and imported source metadata stay native JSON values.
fn reconstruct(
    old: &Value,
    submitted: &Value,
    changes: &[Value],
    image_sources: &HashMap<String, &Value>,
    nova: Option<&Value>,
) -> Result<Value> {
    let old_rows = rows(old);
    let submitted_rows = rows(submitted);
    let nova_rows = nova.map(rows).unwrap_or_default();
    let mut fields_by_id = HashMap::new();
    require(changes.len() <= MAX_ROWS, "Too many field changes")?;
    for change in changes {
        let id = str_field(change, "id")?;
        require(
            old_rows.contains_key(id) && submitted_rows.contains_key(id),
            "Field changes require a retained existing painting",
        )?;
        let fields = change
            .get("fields")
            .and_then(Value::as_array)
            .ok_or_else(|| Error::new("request", "Missing changed fields list"))?;
        require(
            fields.len() <= KNOWN_FIELDS.len() && fields_by_id.insert(id, fields).is_none(),
            "Invalid or duplicate field changes",
        )?;
        let mut unique = HashSet::new();
        for field in fields {
            let field = field
                .as_str()
                .ok_or_else(|| Error::new("request", "Invalid changed field"))?;
            require(
                field != "md5" && KNOWN_FIELDS.contains(&field) && unique.insert(field),
                "Only distinct known metadata fields may be changed",
            )?;
            require(
                submitted_rows[id].get(field).is_some(),
                "Changed field must be present in candidate",
            )?;
        }
    }
    let mut output = if old.get("version").and_then(Value::as_u64).unwrap_or(0) >= 1 {
        old.clone()
    } else {
        submitted.clone()
    };
    output["version"] = json!(3);
    let mut paintings = Vec::new();
    for row in submitted["paintings"].as_array().unwrap() {
        let id = str_field(row, "md5")?;
        if let Some(original) = old_rows.get(id) {
            let mut preserved = (*original).clone();
            if let Some(fields) = fields_by_id.get(id) {
                for field in *fields {
                    let field = field.as_str().unwrap();
                    preserved[field] = row[field].clone();
                }
            }
            paintings.push(preserved);
        } else if image_sources
            .get(id)
            .is_some_and(|source| source.get("source").and_then(Value::as_str) == Some("nova"))
        {
            let original = nova_rows
                .get(id)
                .ok_or_else(|| Error::new("source", "Painting is absent from Nova source"))?;
            let mut preserved = (*original).clone();
            preserved["show_in_webgallery"] =
                row.get("show_in_webgallery").cloned().unwrap_or(json!(0));
            paintings.push(preserved);
        } else {
            paintings.push(row.clone());
        }
    }
    output["paintings"] = json!(paintings);
    Ok(output)
}
/// Decode the complete bounded PNG and require static pixels matching the recorded dimensions.
fn validate_png(bytes: &[u8], row: &Value) -> Result<()> {
    require(bytes.len() <= MAX_PNG, "PNG is too large")?;
    let mut decoder = png::Decoder::new(Cursor::new(bytes));
    decoder.set_limits(png::Limits { bytes: MAX_PNG * 4 });
    let mut reader = decoder
        .read_info()
        .map_err(|_| Error::new("png", "Invalid PNG header"))?;
    let info = reader.info();
    require(
        info.animation_control.is_none(),
        "Animated PNGs are unsupported",
    )?;
    require(
        Some(info.width as u64) == row.get("width").and_then(Value::as_u64)
            && Some(info.height as u64) == row.get("height").and_then(Value::as_u64),
        "PNG dimensions do not match metadata",
    )?;
    require(
        reader.output_buffer_size() <= MAX_PNG * 4,
        "Decoded PNG is too large",
    )?;
    let mut output = vec![0; reader.output_buffer_size()];
    reader
        .next_frame(&mut output)
        .map_err(|_| Error::new("png", "PNG pixel data is corrupt"))?;
    reader
        .finish()
        .map_err(|_| Error::new("png", "PNG is incomplete"))?;
    Ok(())
}

#[derive(Serialize, Deserialize)]
struct ImageRecord {
    id: String,
    sha256: String,
}
#[derive(Serialize, Deserialize)]
struct Journal {
    api: u32,
    before_sha256: String,
    before_exists: bool,
    after_sha256: String,
    images: Vec<ImageRecord>,
    deletes: Vec<ImageRecord>,
}
#[derive(Serialize, Deserialize)]
struct Backup {
    sha256: String,
    bytes: String,
}

pub struct Store {
    live: PathBuf,
    nova: PathBuf,
}
impl Store {
    /// Resolve storage from the game working directory, never from caller-supplied roots.
    pub fn production() -> Result<Self> {
        let cwd = std::env::current_dir()?;
        Ok(Self {
            live: fs::canonicalize(cwd.join("data"))?,
            nova: cwd.join("config/nova"),
        })
    }
    /// Create isolated live and Nova roots beneath a test-owned temporary directory.
    #[cfg(test)]
    fn for_test(root: &Path) -> Self {
        fs::create_dir_all(root.join("data/paintings/images")).unwrap();
        fs::create_dir_all(root.join("config/nova/paintings/images")).unwrap();
        Self {
            live: fs::canonicalize(root.join("data")).unwrap(),
            nova: fs::canonicalize(root.join("config/nova")).unwrap(),
        }
    }
    /// Resolve a transaction sidecar beneath the trusted store root with descendant link checks.
    fn private(&self, name: &str) -> Result<PathBuf> {
        child(&self.live, &format!("paintings/.store/{name}"))
    }
    /// Resolve a live PNG path only for a validated painting identity.
    fn image(&self, id: &str) -> Result<PathBuf> {
        require(hex(id, 32), "Invalid image identity")?;
        child(&self.live, &format!("paintings/images/{id}.png"))
    }
    /// Acquire a nonblocking OS writer lock held until the returned file is dropped.
    fn lock(&self) -> Result<File> {
        fs::create_dir_all(self.private("")?)?;
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(self.private("lock")?)?;
        FileExt::try_lock_exclusive(&file)
            .map_err(|_| Error::new("busy", "Another painting writer holds the database lock"))?;
        Ok(file)
    }
    /// Read bounded live database bytes while distinguishing a missing file from an empty one.
    fn live_bytes(&self) -> Result<(Vec<u8>, bool)> {
        let path = child(&self.live, "paintings.json")?;
        if !path.try_exists()? {
            return Ok((Vec::new(), false));
        }
        Ok((read_bounded(&path, MAX_JSON)?, true))
    }
    /// Validate the read-only version-3 source and return its exact-byte fingerprint.
    fn nova_snapshot(&self) -> Result<(Value, String)> {
        // Pin a real root and reject all links below it. No request may select roots.
        let root = fs::canonicalize(&self.nova)?;
        let bytes = read_bounded(&child(&root, "paintings.json")?, MAX_JSON)?;
        let value = parse(&bytes)?;
        validate(&value, false)?;
        Ok((value, hash(&bytes)))
    }
    /// Read Nova independently; lock and recover live storage before snapshots or commits.
    pub fn execute(&self, request: &Value) -> Result<Value> {
        if request.get("op").and_then(Value::as_str) == Some("snapshot")
            && request.get("source").and_then(Value::as_str) == Some("nova")
        {
            let (snapshot, sha256) = self.nova_snapshot()?;
            return Ok(json!({"snapshot":snapshot,"sha256":sha256,"exists":true}));
        }
        let _lock = self.lock()?;
        self.recover()?;
        let (bytes, exists) = self.live_bytes()?;
        let snapshot = if exists {
            parse(&bytes)?
        } else {
            json!({"version":3,"paintings":[]})
        };
        validate(&snapshot, true)?;
        match request.get("op").and_then(Value::as_str) {
            Some("snapshot") => {
                require(
                    request.get("source").and_then(Value::as_str) == Some("live"),
                    "Invalid snapshot source",
                )?;
                Ok(json!({"snapshot":snapshot,"sha256":hash(&bytes),"exists":exists}))
            }
            Some("submit_commit") => self.commit(request, &bytes, exists, &snapshot),
            _ => Err(Error::new("request", "Unknown worker operation")),
        }
    }
    /// Atomically retain the nonempty prior snapshot with its integrity digest.
    fn backup(&self, bytes: &[u8]) -> Result<()> {
        if bytes.is_empty() {
            return Ok(());
        }
        let backup = Backup {
            sha256: hash(bytes),
            bytes: String::from_utf8(bytes.to_vec())
                .map_err(|_| Error::new("json", "Database is not UTF-8"))?,
        };
        atomic(
            &self.private("last-good.json")?,
            &serde_json::to_vec(&backup).unwrap(),
            true,
        )
    }
    /// Remove recovery authorization before discarding sidecars and staged images.
    fn cleanup_journal(&self) -> Result<()> {
        // Journal is removed first. Sidecars without a journal have never authorized image promotion.
        remove(&self.private("journal.json")?)?;
        remove(&self.private("before.json")?)?;
        remove(&self.private("after.json")?)?;
        self.cleanup_staged()
    }
    /// Resolve a transaction-owned image sidecar for a validated painting identity.
    fn staged(&self, id: &str) -> Result<PathBuf> {
        require(hex(id, 32), "Invalid staged image identity")?;
        self.private(&format!("image-{id}.png"))
    }
    /// Remove only recognized image staging files, leaving unrelated store contents alone.
    fn cleanup_staged(&self) -> Result<()> {
        for entry in fs::read_dir(self.private("")?)? {
            let name = entry?.file_name();
            let Some(name) = name.to_str() else {
                continue;
            };
            if let Some(id) = name
                .strip_prefix("image-")
                .and_then(|s| s.strip_suffix(".png"))
            {
                if hex(id, 32) {
                    remove(&self.staged(id)?)?;
                }
            }
        }
        Ok(())
    }
    /// Publish a staged image without overwriting; retain its hardlink to prove recovery ownership.
    fn promote(&self, id: &str) -> Result<()> {
        // Keep a transaction-owned hardlink until cleanup. Recovery checks file identity,
        // not only content, before deleting a partially promoted destination.
        let destination = self.image(id)?;
        fs::hard_link(self.staged(id)?, &destination)?;
        OpenOptions::new()
            .read(true)
            .write(true)
            .open(&destination)?
            .sync_all()?;
        #[cfg(unix)]
        File::open(destination.parent().unwrap())?.sync_all()?;
        Ok(())
    }
    /// Require a matching digest and valid metadata before trusting recovery snapshot bytes.
    fn verified_sidecar(&self, name: &str, digest: &str, empty_allowed: bool) -> Result<Vec<u8>> {
        require(hex(digest, 64), "Invalid recovery digest")?;
        let bytes = read_bounded(&self.private(name)?, MAX_JSON)?;
        require(hash(&bytes) == digest, "Recovery sidecar was changed")?;
        if !empty_allowed || !bytes.is_empty() {
            validate(&parse(&bytes)?, true)?;
        }
        Ok(bytes)
    }
    /// Delete only the journaled image bytes; refuse a destination whose contents changed.
    fn exact_remove_image(&self, image: &ImageRecord) -> Result<()> {
        require(hex(&image.sha256, 64), "Invalid image recovery digest")?;
        let path = self.image(&image.id)?;
        if path.try_exists()? {
            require(
                hash(&read_bounded(&path, MAX_PNG)?) == image.sha256,
                "Recovery image changed; refusing deletion",
            )?;
            remove(&path)?;
        }
        Ok(())
    }
    /// Finish committed cleanup or roll back owned staging; stop on unexplained valid database changes.
    fn recover(&self) -> Result<()> {
        let journal_path = self.private("journal.json")?;
        if !journal_path.try_exists()? {
            return self.cleanup_staged();
        }
        let journal: Journal = serde_json::from_slice(&read_bounded(&journal_path, MAX_JSON)?)
            .map_err(|_| Error::new("recovery", "Invalid recovery journal"))?;
        require(
            journal.api == 1
                && journal.images.len() <= MAX_ROWS
                && journal.deletes.len() <= MAX_ROWS,
            "Invalid recovery journal version",
        )?;
        let before = self.verified_sidecar(
            "before.json",
            &journal.before_sha256,
            !journal.before_exists,
        )?;
        let after = self.verified_sidecar("after.json", &journal.after_sha256, false)?;
        let before_value = if before.is_empty() {
            json!({"version":3,"paintings":[]})
        } else {
            parse(&before)?
        };
        let after_value = parse(&after)?;
        let before_rows = rows(&before_value);
        let after_rows = rows(&after_value);
        for image in &journal.images {
            require(
                !before_rows.contains_key(&image.id) && after_rows.contains_key(&image.id),
                "Journal promotion does not match snapshots",
            )?;
        }
        for image in &journal.deletes {
            require(
                before_rows.contains_key(&image.id) && !after_rows.contains_key(&image.id),
                "Journal deletion does not match snapshots",
            )?;
        }
        let (current, current_exists) = self.live_bytes()?;
        let digest = hash(&current);
        if digest == journal.after_sha256 && current_exists {
            for image in &journal.images {
                require(
                    hash(&read_bounded(&self.staged(&image.id)?, MAX_PNG)?) == image.sha256,
                    "Recovery image stage changed",
                )?;
                if !self.image(&image.id)?.try_exists()? {
                    self.promote(&image.id)?;
                }
                require(
                    hash(&read_bounded(&self.image(&image.id)?, MAX_PNG)?) == image.sha256,
                    "Committed image missing or changed",
                )?;
            }
            for image in &journal.deletes {
                self.exact_remove_image(image)?;
            }
        } else {
            if digest != journal.before_sha256 || current_exists != journal.before_exists {
                // A syntactically valid unexpected file may belong to a non-cooperating writer.
                // Never replace it. Only a torn/missing database can be restored from this journal.
                if current_exists && parse(&current).is_ok_and(|v| validate(&v, true).is_ok()) {
                    return Err(Error::new(
                        "recovery",
                        "Unexplained valid database change; administrator review required",
                    ));
                }
                if journal.before_exists {
                    atomic(&child(&self.live, "paintings.json")?, &before, true)?;
                } else {
                    remove(&child(&self.live, "paintings.json")?)?;
                }
            }
            for image in &journal.images {
                let destination = self.image(&image.id)?;
                if destination.try_exists()? {
                    require(
                        same_file::is_same_file(self.staged(&image.id)?, &destination)?,
                        "Unowned destination image; refusing recovery deletion",
                    )?;
                    self.exact_remove_image(image)?;
                }
            }
        }
        self.cleanup_journal()
    }
    /// Validate the expected snapshot, journal image changes, then atomically replace JSON as the commit point.
    fn commit(
        &self,
        request: &Value,
        before: &[u8],
        before_exists: bool,
        old: &Value,
    ) -> Result<Value> {
        let expected = str_field(request, "expected_sha256")?;
        if !hex(expected, 64) || expected != hash(before) {
            return Err(Error::new(
                "conflict",
                "Database changed since snapshot; refresh and retry",
            ));
        }
        let submitted = request
            .get("candidate")
            .ok_or_else(|| Error::new("request", "Missing candidate"))?;
        validate(submitted, false)?;
        let descriptors = request
            .get("images")
            .and_then(Value::as_array)
            .ok_or_else(|| Error::new("request", "Missing images array"))?;
        let deletions = request
            .get("deletes")
            .and_then(Value::as_array)
            .ok_or_else(|| Error::new("request", "Missing deletes array"))?;
        let changes = request
            .get("changed_fields")
            .and_then(Value::as_array)
            .ok_or_else(|| Error::new("request", "Missing changed_fields array"))?;
        require(
            descriptors.len() <= MAX_ROWS && deletions.len() <= MAX_ROWS,
            "Too many image operations",
        )?;
        let old_rows = rows(old);
        let submitted_rows = rows(submitted);
        let legacy = old.get("version").and_then(Value::as_u64).unwrap_or(0) < 3;
        let actual_removed: HashSet<_> = old_rows
            .keys()
            .filter(|id| !submitted_rows.contains_key(*id))
            .cloned()
            .collect();
        let mut declared_removed = HashSet::new();
        for id in deletions {
            let id = id
                .as_str()
                .ok_or_else(|| Error::new("request", "Invalid deletion identity"))?;
            require(
                hex(id, 32) && declared_removed.insert(id.to_owned()),
                "Invalid or duplicate deletion identity",
            )?;
        }
        require(
            actual_removed == declared_removed,
            "Deletion list does not match candidate",
        )?;
        let mut image_sources = HashMap::new();
        for image in descriptors {
            let id = str_field(image, "id")?;
            require(
                hex(id, 32)
                    && !old_rows.contains_key(id)
                    && submitted_rows.contains_key(id)
                    && image_sources.insert(id.to_owned(), image).is_none(),
                "Invalid or duplicate image addition",
            )?;
        }
        let nova = if descriptors
            .iter()
            .any(|d| d.get("source").and_then(Value::as_str) == Some("nova"))
        {
            let (value, digest) = self.nova_snapshot()?;
            require(
                str_field(request, "nova_sha256")? == digest,
                "Nova source changed since confirmation",
            )?;
            Some(value)
        } else {
            None
        };
        let candidate = reconstruct(old, submitted, changes, &image_sources, nova.as_ref())?;
        validate(&candidate, false)?;
        if &candidate == old {
            require(
                descriptors.is_empty() && deletions.is_empty(),
                "Unchanged database cannot mutate images",
            )?;
            return Ok(json!({"changed":false,"sha256":hash(before),"snapshot":old}));
        }
        let new_rows = rows(&candidate);
        for (id, row) in &old_rows {
            if let Some(next) = new_rows.get(id) {
                if row.get("show_in_webgallery") != next.get("show_in_webgallery") {
                    require(
                        matches!(next.get("show_in_webgallery"),Some(value) if value == &json!(0) || value == &json!(1)),
                        "Changed visibility must be numeric 0 or 1",
                    )?;
                }
                if row.get("width") != next.get("width") || row.get("height") != next.get("height")
                {
                    validate_png(&read_bounded(&self.image(id)?, MAX_PNG)?, next)?;
                }
            }
        }
        let mut image_bytes: Vec<(String, Vec<u8>)> = Vec::new();
        for (id, row) in &new_rows {
            if old_rows.contains_key(id) {
                continue;
            }
            require(
                matches!(row.get("show_in_webgallery"),Some(value) if value == &json!(0) || value == &json!(1)),
                "New visibility must be numeric 0 or 1",
            )?;
            let destination = self.image(id)?;
            if destination.try_exists()? {
                require(
                    legacy && !image_sources.contains_key(id),
                    "Existing destination image must not be overwritten",
                )?;
                validate_png(&read_bounded(&destination, MAX_PNG)?, row)?;
                continue;
            }
            let descriptor = image_sources
                .get(id)
                .ok_or_else(|| Error::new("image", "Missing source for new painting image"))?;
            let source = match str_field(descriptor, "source")? {
                "staged" => {
                    let stage = str_field(descriptor, "stage")?;
                    require(hex(stage, 32), "Invalid staging token")?;
                    child(&self.live, &format!("paintings/staging/{stage}/{id}.png"))?
                }
                "nova" => child(
                    &fs::canonicalize(&self.nova)?,
                    &format!("paintings/images/{id}.png"),
                )?,
                "legacy" => {
                    require(legacy, "Legacy images are only accepted during migration")?;
                    let category = str_field(descriptor, "category")?;
                    require(CATEGORIES.contains(&category), "Invalid legacy category")?;
                    child(&self.live, &format!("paintings/{category}/{id}.png"))?
                }
                _ => return Err(Error::new("source", "Unknown image source")),
            };
            let bytes = read_bounded(&source, MAX_PNG)?;
            validate_png(&bytes, row)?;
            image_bytes.push((id.clone(), bytes));
        }
        let after = serde_json::to_vec(&candidate)
            .map_err(|_| Error::new("json", "Cannot encode candidate"))?;
        require(after.len() <= MAX_JSON, "Candidate database is too large")?;
        let mut journal = Journal {
            api: 1,
            before_sha256: hash(before),
            before_exists,
            after_sha256: hash(&after),
            images: Vec::new(),
            deletes: Vec::new(),
        };
        for (id, bytes) in &image_bytes {
            journal.images.push(ImageRecord {
                id: id.clone(),
                sha256: hash(bytes),
            });
        }
        for id in actual_removed {
            let path = self.image(&id)?;
            if path.try_exists()? {
                journal.deletes.push(ImageRecord {
                    id,
                    sha256: hash(&read_bounded(&path, MAX_PNG)?),
                });
            }
        }
        fs::create_dir_all(child(&self.live, "paintings/images")?)?;
        atomic(&self.private("before.json")?, before, true)?;
        atomic(&self.private("after.json")?, &after, true)?;
        for (id, bytes) in &image_bytes {
            atomic(&self.staged(id)?, bytes, false)?;
        }
        self.backup(before)?;
        atomic(
            &self.private("journal.json")?,
            &serde_json::to_vec(&journal).unwrap(),
            false,
        )?;
        self.failpoint("journal")?;
        for (id, _) in &image_bytes {
            self.promote(id)?;
            self.failpoint("image")?;
        }
        // Detect external writers which ignore our lock before the commit point.
        let (now, now_exists) = self.live_bytes()?;
        require(
            hash(&now) == expected && now_exists == before_exists,
            "Database changed during transaction",
        )?;
        atomic(&child(&self.live, "paintings.json")?, &after, true)?;
        self.failpoint("commit")?;
        for image in &journal.deletes {
            if let Err(error) = self.exact_remove_image(image) {
                return Ok(
                    json!({"changed":true,"sha256":hash(&after),"snapshot":candidate,"cleanup_pending":true,"warning":error.message}),
                );
            }
            self.failpoint("delete")?;
        }
        if let Err(error) = self.cleanup_journal() {
            return Ok(
                json!({"changed":true,"sha256":hash(&after),"snapshot":candidate,"cleanup_pending":true,"warning":error.message}),
            );
        }
        Ok(json!({"changed":true,"sha256":hash(&after),"snapshot":candidate}))
    }
    /// Keep fault-injection checkpoints inert in production builds.
    #[cfg(not(test))]
    fn failpoint(&self, _point: &str) -> Result<()> {
        Ok(())
    }
    /// Simulate interruption at the checkpoint selected by this test thread.
    #[cfg(test)]
    fn failpoint(&self, point: &str) -> Result<()> {
        FAILPOINT.with(|active| {
            if active.borrow().as_deref() == Some(point) {
                Err(Error::new("injected", "Simulated process interruption"))
            } else {
                Ok(())
            }
        })
    }
}

#[cfg(test)]
thread_local! { static FAILPOINT: std::cell::RefCell<Option<String>> = const { std::cell::RefCell::new(None) }; }

#[cfg(test)]
mod tests;
