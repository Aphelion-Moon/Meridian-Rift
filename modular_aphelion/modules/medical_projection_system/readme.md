## Medical Projection System

Module ID: MEDICAL_PROJECTION_SYSTEM

### Description

Adds a station-wide, manually maintained emergency-care network.

- Medical staff fulfill a rotating reagent or organ request at the Lifeline synthesis reservoir.
- Existing DeForest first aid stations use the shared reservoir to refill Lifeline field sprayers.
- A full sprayer is available in the character loadout under Other, Gear, and spawns in the backpack.
- Sprayers heal 8 damage from the higher of brute and burn (brute wins ties), and add 4 recovery progress to one random wound. Toxin and oxygen damage are not treated.
- Sprayers can temporarily stabilize a living critical patient for transport without healing the patient or allowing hand use. Conscious patients can click the status alert to dismiss the field.
- Calibration locks the sprayer against overlapping treatments and mode changes, and rechecks patient eligibility and fuel before applying treatment.
- Sprayers can project a temporary stasis cocoon with an audible recovery beacon; the projection dissolves when opened.
- The reservoir does not support plumbing or unattended reagent transfer.

### TG Proc/File Changes

- `code/game/machinery/wall_healer.dm`: Extends `/obj/machinery/wall_healer/add_context()` and `/obj/machinery/wall_healer/item_interaction()` with field sprayer refills.
- `code/modules/unit_tests/_unit_tests.dm`: Includes the module's focused regression tests.

### Modular Overrides

- N/A

### Defines

- `LIFELINE_MODE_HEAL`, `LIFELINE_MODE_STABILIZE`, and `LIFELINE_MODE_STASIS` are local to `medical_projection_system.dm`.

### Included files that are not contained in this module

- `tgstation.dme`: Includes the module code.

### Credits

- Original implementation for Meridian Rift.
