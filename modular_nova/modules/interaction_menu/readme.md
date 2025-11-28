## Title: INTERACTION MENU

### Description:

The Ctrl+Shift interaction panel uses `/datum/component/interactable` for the UI and
`/datum/interaction` for configured actions, messages, and effects. The server takes the
actor from the TGUI session and the target from the component parent.

An interaction route supplies access to a participant through another object. A null
route uses ordinary adjacency, unless the interaction permits distance. The portal
module implements two routes:

- `portal_relay` reaches the occupant of an active wall portal through its body relay.
- `portal_device` checks the operator, held device, worn receiver, links, and selected
  parts. It also supports the receiver wearer filling both interaction roles.

Movables that represent a participant can implement `interaction_route_for()`.
The component looks up a remote body relay or, for self interactions, the active item.
Device attacks can also construct a route directly.

### Validation and ownership:

`can_execute()` checks participant state, route authority, preferences, and required
parts. The menu uses it when listing actions, `act()` checks again before sending
messages, and `apply_effects()` checks before deferred effects. Only the deferred and
menu passes ignore the interaction cooldown; successful callers start the shared
cooldown on both participants.

Route preferences apply to ordinary interactions too. Lewd interactions additionally
require both participants' ERP preference. Routes and deferred participants use weak
references, so a dropped, replaced, or deleted endpoint cannot authorize old effects.
Keep these boundary checks when adding a new route.

The panel names a target only while their body is visible. Otherwise it displays their
current relay name, or "Unknown" if no relay remains. Leaving a relay or ending its
session therefore cannot reveal the remote identity; direct actions remain available.

### Message templates:

`act()` gets anonymity from the route. Public messages use the observer perspective;
private messages address their recipient as "you". Known self interactions use
reflexive names and possessions, while anonymity takes precedence over shared identity.
Ordinary direct messages also hide an unseen target, so a distant action cannot recover
their name after a relay ends. An explicit route retains its own identity policy,
including a device configured to reveal its remote participant. Administrative logs
retain the real participants.

Both `USER` and `TARGET` support these tokens:

| Token | Purpose |
| --- | --- |
| `%USER%`, `%USER_CAPITAL%` | Participant name, optionally capitalized |
| `%USER_OBJECT%` | Object form, including "yourself" for known self interactions |
| `%USER%'s` | Possessive, including "your" or "your own" for the recipient |
| `%USER_VERB_S%`, `%USER_VERB_ES%` | Verb ending omitted for a second-person subject |
| `%USER_PRONOUN_THEIR%`, `%USER_PRONOUN_THEIRS%` | Possessive pronouns |
| `%USER_PRONOUN_THEM%`, `%USER_PRONOUN_THEY%`, `%USER_PRONOUN_THEMSELVES%` | Other pronoun forms |

For example, `%USER_CAPITAL% wave%USER_VERB_S% to %TARGET_OBJECT%.` works for both
observer and recipient messages. Existing private templates need explicit verb-ending
tokens when their subject can become "you"; the formatter does not conjugate prose.

Configuration loads from `config/nova/interactions/`, including nested JSON files.
Portal device mappings depend on the external interaction set described in the
[modular items documentation](../modular_items/readme.md).

### Verification:

The portal route tests cover anonymous panel titles, route preferences, and stale
offered sessions. Device and lifecycle tests cover endpoint authority and cleanup.
The ordinary CI deployment does not copy the interaction configuration directory;
runtime routing tests use deterministic fixtures, while deployment-specific JSON
validation requires supplying that configuration.

### TG Proc/File Changes:

- N/A

### Defines:

- N/A

### Master file additions:

- N/A

### Included files that are not contained in this module:

- N/A
