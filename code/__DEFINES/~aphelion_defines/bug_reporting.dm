// Player bug reports through the reporting bridge on this machine. See modular_aphelion/modules/bug_reporting.
/// Biggest image BYOND's file prompt may upload for a report
#define BUG_REPORT_UPLOAD_LIMIT (10 * 1024 * 1024)
/// Base64 characters per capture message. The page posts these itself, since tgui's Byond.call loses anything over 2 KB on 516
#define BUG_REPORT_CAPTURE_CHUNK 32768
