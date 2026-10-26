//! Narrow BYOND call_ext boundary. Filesystem work only runs on the worker thread.
mod store;

use serde_json::{json, Value};
use std::cell::RefCell;
use std::collections::{HashMap, VecDeque};
use std::ffi::{c_char, c_int, CStr, CString};
use std::sync::{mpsc, Mutex, OnceLock};
use std::time::{Duration, Instant};

const MAX_JOBS: usize = 4;
const JOB_IDLE_TIMEOUT: Duration = Duration::from_secs(60);
const RESULT_TIMEOUT: Duration = Duration::from_secs(300);

struct Jobs {
    next: u64,
    /// Pending leases renewed by polling; completed results occupy no active slot.
    active: HashMap<String, Instant>,
    /// Bounded responses retained briefly for collection, including expired jobs.
    results: VecDeque<(String, Instant, Value)>,
    sender: mpsc::SyncSender<(String, Value)>,
}

/// Tell a caller to refresh its snapshot because an abandoned job may have committed.
fn expired() -> Value {
    store::Error::new(
        "expired",
        "Painting job expired or was already collected; its transaction may have completed. Take a fresh snapshot before retrying.",
    )
    .value()
}

impl Jobs {
    /// Release idle submission slots and discard results past their collection deadline.
    fn expire(&mut self, now: Instant) {
        self.active
            .retain(|_, last_poll| now.duration_since(*last_poll) < JOB_IDLE_TIMEOUT);
        self.results
            .retain(|(_, completed, _)| now.duration_since(*completed) < RESULT_TIMEOUT);
    }

    /// Queue work without blocking BYOND; failed sends release their reserved active slot.
    fn submit(&mut self, value: Value, now: Instant) -> Value {
        self.expire(now);
        if self.active.len() >= MAX_JOBS {
            return store::Error::new("busy", "Collect pending jobs before submitting more")
                .value();
        }
        self.next += 1;
        let id = self.next.to_string();
        self.active.insert(id.clone(), now);
        if self.sender.try_send((id.clone(), value)).is_err() {
            self.active.remove(&id);
            return store::Error::new("busy", "Worker queue is full").value();
        }
        json!({"ok":true,"job":id})
    }

    /// Collect a completed response once, or renew the lease of an active job.
    fn poll(&mut self, id: &str, now: Instant) -> Value {
        self.expire(now);
        if let Some(index) = self.results.iter().position(|(job, _, _)| job == id) {
            return self.results.remove(index).unwrap().2;
        }
        if let Some(last_poll) = self.active.get_mut(id) {
            *last_poll = now;
            return json!({"ok":true,"pending":true});
        }
        self.missing(id)
    }

    /// Release caller state without interrupting a transaction already writing to disk.
    fn cancel(&mut self, id: &str, now: Instant) -> Value {
        self.expire(now);
        self.active.remove(id);
        self.results.retain(|(job, _, _)| job != id);
        self.missing(id)
    }

    /// Distinguish previously issued, now expired jobs from unknown identifiers.
    fn missing(&self, id: &str) -> Value {
        if id.parse::<u64>().is_ok_and(|id| id > 0 && id <= self.next) {
            expired()
        } else {
            store::Error::new("job", "Unknown job identifier").value()
        }
    }

    /// Allow only jobs with a live caller lease to begin filesystem work.
    fn start(&mut self, id: &str, now: Instant) -> bool {
        self.expire(now);
        if self.active.contains_key(id) {
            return true;
        }
        self.complete(id.to_owned(), expired(), now);
        false
    }

    /// Release the active slot and retain a bounded result; abandoned jobs stay expired.
    fn complete(&mut self, id: String, value: Value, now: Instant) {
        self.expire(now);
        // A lost caller never resurrects a job or reports an unobserved commit as success.
        let value = if self.active.remove(&id).is_some() {
            value
        } else {
            expired()
        };
        self.results.push_back((id, now, value));
        while self.results.len() > MAX_JOBS {
            self.results.pop_front();
        }
    }
}

static JOBS: OnceLock<Mutex<Jobs>> = OnceLock::new();

/// Initialize the shared job registry and its single filesystem worker on first use.
fn jobs() -> &'static Mutex<Jobs> {
    JOBS.get_or_init(|| {
        let (sender, receiver) = mpsc::sync_channel::<(String, Value)>(MAX_JOBS);
        std::thread::Builder::new()
            .name("painting-store".into())
            .spawn(move || {
                // Resolve the trusted game working directory once, never from a request.
                let store = store::Store::production();
                for (id, request) in receiver {
                    if !jobs()
                        .lock()
                        .is_ok_and(|mut jobs| jobs.start(&id, Instant::now()))
                    {
                        continue;
                    }
                    let result = std::panic::catch_unwind(|| match &store {
                        Ok(store) => store.execute(&request),
                        Err(error) => Err(error.clone()),
                    });
                    let value = match result {
                        Ok(Ok(mut value)) => {
                            value["ok"] = json!(true);
                            value["pending"] = json!(false);
                            value
                        }
                        Ok(Err(error)) => error.value(),
                        Err(_) => store::Error::new(
                            "panic",
                            "Painting worker failed; no unsafe fallback is available",
                        )
                        .value(),
                    };
                    if let Ok(mut jobs) = jobs().lock() {
                        jobs.complete(id, value, Instant::now());
                    }
                }
            })
            .expect("painting worker thread");
        Mutex::new(Jobs {
            next: 0,
            active: HashMap::new(),
            results: VecDeque::new(),
            sender,
        })
    })
}

/// Validate the API version and dispatch synchronous control or asynchronous store work.
fn request(value: Value) -> Value {
    if value.get("api").and_then(Value::as_u64) != Some(1) {
        return store::Error::new("api", "Expected painting store API 1").value();
    }
    match value.get("op").and_then(Value::as_str) {
        Some("info") => json!({"ok":true,"api":1,"version":env!("CARGO_PKG_VERSION")}),
        Some("poll" | "cancel") => {
            let Some(id) = value.get("job").and_then(Value::as_str) else {
                return store::Error::new("request", "Missing job identifier").value();
            };
            let Ok(mut jobs) = jobs().lock() else {
                return store::Error::new("worker", "Worker state unavailable").value();
            };
            if value["op"] == "cancel" {
                jobs.cancel(id, Instant::now())
            } else {
                jobs.poll(id, Instant::now())
            }
        }
        Some("snapshot" | "submit_commit") => {
            let Ok(mut jobs) = jobs().lock() else {
                return store::Error::new("worker", "Worker state unavailable").value();
            };
            jobs.submit(value, Instant::now())
        }
        _ => store::Error::new("request", "Unknown operation").value(),
    }
}

thread_local! { static RETURN: RefCell<CString> = RefCell::new(CString::new("").unwrap()); }

/// BYOND owns argument memory and copies the returned NUL-terminated string.
/// The returned allocation remains valid until the next call on this thread.
///
/// # Safety
/// Called only by BYOND with argc valid argv pointers to NUL-terminated strings.
#[no_mangle]
pub unsafe extern "C" fn painting_store_call(
    argc: c_int,
    argv: *const *const c_char,
) -> *const c_char {
    let result = std::panic::catch_unwind(|| {
        if argc != 1 || argv.is_null() || (*argv).is_null() {
            return store::Error::new("request", "Expected one JSON argument").value();
        }
        let bytes = CStr::from_ptr(*argv).to_bytes();
        if bytes.len() > store::MAX_JSON * 2 {
            return store::Error::new("bounds", "Request is too large").value();
        }
        match serde_json::from_slice(bytes) {
            Ok(value) => request(value),
            Err(_) => store::Error::new("json", "Invalid request JSON").value(),
        }
    })
    .unwrap_or_else(|_| store::Error::new("panic", "Invalid native call").value());
    RETURN.with(|cell| {
        *cell.borrow_mut() = CString::new(result.to_string()).unwrap();
        cell.borrow().as_ptr()
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Create an isolated job registry whose queue the test can drain explicitly.
    fn fixture() -> (Jobs, mpsc::Receiver<(String, Value)>) {
        let (sender, receiver) = mpsc::sync_channel(MAX_JOBS);
        (
            Jobs {
                next: 0,
                active: HashMap::new(),
                results: VecDeque::new(),
                sender,
            },
            receiver,
        )
    }

    /// Submit and dequeue one test job, checking that the caller receives its identifier.
    fn submit(jobs: &mut Jobs, receiver: &mpsc::Receiver<(String, Value)>, now: Instant) -> String {
        let response = jobs.submit(json!({"op":"snapshot","source":"live"}), now);
        assert_eq!(response["ok"], true);
        let (id, _) = receiver.try_recv().unwrap();
        assert_eq!(response["job"], id);
        id
    }

    /// Check that retained results consume no active capacity and cannot be collected twice.
    #[test]
    fn completed_jobs_do_not_block_submissions_and_are_collected_once() {
        let (mut jobs, receiver) = fixture();
        let now = Instant::now();
        let mut completed = Vec::new();
        for _ in 0..MAX_JOBS {
            let id = submit(&mut jobs, &receiver, now);
            jobs.complete(id.clone(), json!({"ok":true,"pending":false}), now);
            completed.push(id);
        }
        let pending = submit(&mut jobs, &receiver, now);
        assert_eq!(jobs.active.len(), 1);
        assert_eq!(jobs.results.len(), MAX_JOBS);
        assert_eq!(jobs.poll(&completed[0], now)["ok"], true);
        assert_eq!(jobs.results.len(), MAX_JOBS - 1);
        assert_eq!(jobs.poll(&completed[0], now)["error"]["code"], "expired");
        assert_eq!(jobs.poll(&pending, now)["pending"], true);
        assert_eq!(jobs.poll("unknown", now)["error"]["code"], "job");
    }

    /// Check that expired callers free capacity even if their worker later reports success.
    #[test]
    fn abandoned_jobs_expire_and_late_completion_does_not_resurrect_them() {
        let (mut jobs, receiver) = fixture();
        let now = Instant::now();
        let ids: Vec<_> = (0..MAX_JOBS)
            .map(|_| submit(&mut jobs, &receiver, now))
            .collect();
        assert_eq!(jobs.submit(json!({}), now)["error"]["code"], "busy");
        let later = now + JOB_IDLE_TIMEOUT;
        let pending = submit(&mut jobs, &receiver, later);
        assert_eq!(jobs.active.len(), 1);
        jobs.complete(ids[0].clone(), json!({"ok":true,"changed":true}), later);
        assert_eq!(jobs.poll(&ids[0], later)["error"]["code"], "expired");
        assert_eq!(jobs.poll(&ids[1], later)["error"]["code"], "expired");
        assert_eq!(jobs.poll(&pending, later)["pending"], true);
    }

    /// Check that regular polls preserve a result beyond the original submission lease.
    #[test]
    fn polling_keeps_a_long_running_transaction_collectible() {
        let (mut jobs, receiver) = fixture();
        let now = Instant::now();
        let id = submit(&mut jobs, &receiver, now);
        assert!(jobs.start(&id, now));
        let before_expiry = now + JOB_IDLE_TIMEOUT - Duration::from_secs(1);
        assert_eq!(jobs.poll(&id, before_expiry)["pending"], true);
        let completion = now + JOB_IDLE_TIMEOUT + Duration::from_secs(1);
        jobs.complete(id.clone(), json!({"ok":true,"changed":true}), completion);
        assert_eq!(jobs.poll(&id, completion)["changed"], true);
    }

    /// Check that cancellation prevents work which has not started from executing.
    #[test]
    fn cancelling_a_queued_job_skips_its_transaction() {
        let (mut jobs, receiver) = fixture();
        let now = Instant::now();
        let id = submit(&mut jobs, &receiver, now);
        assert_eq!(jobs.cancel(&id, now)["error"]["code"], "expired");
        assert!(jobs.active.is_empty());
        assert!(!jobs.start(&id, now));
        assert_eq!(jobs.poll(&id, now)["error"]["code"], "expired");
    }

    /// Check that finishing an authorized write cannot restore a cancelled caller lease.
    #[test]
    fn cancelling_a_running_job_keeps_late_completion_expired() {
        let (mut jobs, receiver) = fixture();
        let now = Instant::now();
        let id = submit(&mut jobs, &receiver, now);
        assert!(jobs.start(&id, now));
        jobs.cancel(&id, now);
        jobs.complete(id.clone(), json!({"ok":true,"changed":true}), now);
        assert!(jobs.active.is_empty());
        assert_eq!(jobs.poll(&id, now)["error"]["code"], "expired");
    }

    /// Check both count and age bounds on results whose callers never collect them.
    #[test]
    fn uncollected_results_are_bounded_and_expire() {
        let (mut jobs, receiver) = fixture();
        let now = Instant::now();
        let mut ids = Vec::new();
        for _ in 0..MAX_JOBS + 1 {
            let id = submit(&mut jobs, &receiver, now);
            jobs.complete(id.clone(), json!({"ok":true}), now);
            ids.push(id);
        }
        assert_eq!(jobs.results.len(), MAX_JOBS);
        assert_eq!(jobs.poll(&ids[0], now)["error"]["code"], "expired");
        assert_eq!(
            jobs.poll(&ids[1], now + RESULT_TIMEOUT)["error"]["code"],
            "expired"
        );
        assert!(jobs.results.is_empty());
        assert!(jobs.active.is_empty());
    }

    /// Check that a saturated worker queue releases rejected submissions for later retry.
    #[test]
    fn full_worker_queue_does_not_leak_active_slots() {
        let (mut jobs, receiver) = fixture();
        let now = Instant::now();
        for _ in 0..MAX_JOBS {
            let response = jobs.submit(json!({}), now);
            assert_eq!(response["ok"], true);
            jobs.cancel(response["job"].as_str().unwrap(), now);
        }
        assert_eq!(jobs.submit(json!({}), now)["error"]["code"], "busy");
        assert!(jobs.active.is_empty());
        while receiver.try_recv().is_ok() {}
        submit(&mut jobs, &receiver, now);
    }
}
