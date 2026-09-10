https://github.com/AphelionDevelopment/Meridian-Rift/pull/

## Departmental OOC channels

Module ID: DEPARTMENT_OOC

### Description:

Staff need to be able to talk to a department directly, and a department should be able to talk
policy or its own problems over OOCly amongst itself and staff. This replaces Nova's two hand-rolled
OOC channels, SOOC and AOOC, with one channel table that covers every department.

A single "Department OOC" verb under the OOC tab asks which of the channels you have access to you
want to speak on, then what you want to say. Access comes from your job's department bitflags, so a
role joining or leaving a department carries its OOC access with it and no job list needs
maintaining. Channels shipped: security, medical, engineering, research, service, command, supply,
silicon, central command, antagonist, and a "Backstage" channel that puts command, security and
antagonists in one room together.

Speakers are given a stable per-channel codename ("Deputy Foxtrot 12") rather than their ckey, which
players can turn off in game preferences. Admins see the ckey behind the codename either way, hear
every channel, and can speak on any of them. Deadminned admins are anonymised alongside players.

Adding, removing or recolouring a channel is one entry in `GLOB.department_ooc_channels`.

Admins toggle individual channels off through "Toggle Department OOC" under the Server category,
which replaces the separate Toggle Security OOC and Toggle Antag OOC verbs.

### TG Proc/File Changes:

- N/A

### Modular Overrides:

- `modular_nova/modules/admin/code/sooc.dm` - removed, superseded by this module's security channel
- `modular_nova/modules/admin/code/aooc.dm` - removed, superseded by this module's antagonist channel

### Defines:

- N/A

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/PreferencesMenu/preferences/features/game_preferences/aphelion/department_ooc_anon.tsx`

### Credits:

- Moonridden
- Ported from https://github.com/NovaSector/NovaSector/pull/7242
