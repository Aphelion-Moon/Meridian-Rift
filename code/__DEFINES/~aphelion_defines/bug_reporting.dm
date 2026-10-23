// Player bug reports through the reporting bridge on this machine. See modular_aphelion/modules/bug_reporting.
/// Biggest image BYOND's file prompt may upload for a report
#define BUG_REPORT_UPLOAD_LIMIT (10 * 1024 * 1024)
/// Base64 characters per capture message, sent a topic at a time under the topic limiter
#define BUG_REPORT_CAPTURE_CHUNK 32768
/// Most pictures one report takes, the reporting service's own cap
#define BUG_REPORT_MAX_PICTURES 3
