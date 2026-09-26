## Title: More verbs and Subtler

MODULE ID: VERBS

### Description:

Adds player verbs and emotes, including LOOC, Subtle, and Subtler.

Subtler excludes ghosts and can address one nearby participant or a local radius.
Holograms and Dullahan relays retain their existing recipient routing. Target choices
use unique display names and weak references, then recheck the selected target's
range after the prompt. Emote bans and IC mute status are checked before and after
prompts.

An active wall portal adds two outgoing choices: the relay's tile or its one-tile
radius. Incoming messages through a relay name the sender "Unknown"; outgoing
messages use the relay's name. Both participants must allow ERP and portal use.
Messages sent to a relay also log its real owner.

Portal destination choices retain the exact relay offered before the prompt.
`get_portal_output()` and `resolve_portal_output()`, defined by the portal module,
are shared with its other prompted actions. Ending or replacing a session invalidates
the old choice.

Notification sounds require the recipient's Subtler sound preference. Portal and
other lewd notifications also require the ERP sound preference.

### TG Proc Changes:

- N/A

### Defines:

- `CHAT_LOOC`
- `CHAT_LOOC_ADMIN`
- `LOG_SUBTLER`

### Included files that are not contained in this module:

- Portal output helpers in `modular_nova/modules/modular_items/lewd_items/code/lewd_machinery/portal_interaction_routes.dm`

### Credits:

[Original implementation](https://github.com/Skyrat-SS13/Skyrat-tg/pull/872).
Gandalf2k15: porting and refactoring.
