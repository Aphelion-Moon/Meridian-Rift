/// Ordinary organic human pain capacity, independent of maximum health.
#define MEDICAL_PAIN_CAPACITY 200
/// Maximum combined pain from internal organs.
#define MEDICAL_PAIN_ORGAN_CAP 60
/// Toxin damage contributes less pain than local tissue injury.
#define MEDICAL_PAIN_TOXIN_FACTOR 0.5
/// Minimum interval between escalating symptom stages.
#define MEDICAL_PAIN_STAGE_INTERVAL (2 SECONDS)
/// Maximum symptom stages advanced in one permitted life update.
#define MEDICAL_PAIN_MAX_STAGE_ADVANCE 2
/// Recovery crosses five percentage points below a stage's onset threshold.
#define MEDICAL_PAIN_RECOVERY_MARGIN 5
/// Upper bound on pain's contribution to the combined movement modifier.
#define MEDICAL_PAIN_MAX_SLOWDOWN 3
/// Minimum movement slowdown at hardcrit-range health, independent of analgesia.
#define MEDICAL_PAIN_HARDCRIT_SLOWDOWN 1.5
/// Existing physiological/stamina threshold for general damage slowdown.
#define MEDICAL_PAIN_DAMAGE_SLOW_THRESHOLD 40
/// Existing conversion from damage deficiency to movement slowdown.
#define MEDICAL_PAIN_DAMAGE_SLOW_DIVISOR 75
/// Mild finite analgesic strength.
#define MEDICAL_PAIN_RELIEF_MILD 25
/// Moderate finite analgesic strength.
#define MEDICAL_PAIN_RELIEF_MODERATE 40
/// Strong finite analgesic strength.
#define MEDICAL_PAIN_RELIEF_STRONG 80
/// Surgical local anesthetic strength.
#define MEDICAL_PAIN_RELIEF_SURGICAL 100
/// Temporary relief from the existing determination response.
#define MEDICAL_PAIN_RELIEF_DETERMINATION 60
/// Maximum determination withdrawal stamina damage alongside returning pain.
#define MEDICAL_PAIN_DETERMINATION_CRASH_CAP 20
/// Effective pain percent of capacity at which stock injury crit resumes.
#define MEDICAL_PAIN_CRIT_PERCENT 100
/// Share of post-mitigation brute plus burn overflowing to one head or chest organ at or below softcrit health.
#define MEDICAL_PAIN_OVERFLOW_SOFT_SHARE 0.25
/// Share of post-mitigation brute plus burn overflowing to one head or chest organ at or below hardcrit health.
#define MEDICAL_PAIN_OVERFLOW_HARD_SHARE 0.5
