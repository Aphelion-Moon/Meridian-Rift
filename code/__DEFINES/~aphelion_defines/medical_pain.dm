/// Ordinary organic human pain capacity, independent of maximum health.
#define MEDICAL_PAIN_CAPACITY 200
/// Maximum combined pain from internal organs.
#define MEDICAL_PAIN_ORGAN_CAP 60
/// Toxin damage contributes less pain than local tissue injury.
#define MEDICAL_PAIN_TOXIN_FACTOR 0.5
/// Minimum interval between escalating symptom stages.
#define MEDICAL_PAIN_STAGE_INTERVAL (2 SECONDS)
/// Recovery crosses five percentage points below a stage's onset threshold.
#define MEDICAL_PAIN_RECOVERY_MARGIN 5
/// Upper bound on pain's contribution to the combined movement modifier.
#define MEDICAL_PAIN_MAX_SLOWDOWN 2
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
