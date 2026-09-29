## Partial language understanding

Module ID: LANGUAGE_UNDERSTANDING

### Description:

A language a character can only understand can be followed in part. On the Languages page, every language set to
"Can only understand" gets a **Follows** slider, from 25% to all of it in steps of 5%, with a word for how much gets
through ("most of it", "a few words") and a line in the language as the character would hear it. A language the
character speaks is always followed in full.

- **tg's own partial understanding.** The level is granted to the body as its language holder's partial
  understanding (`grant_partial_language()`, from `LANGUAGE_MIND`), the system the Common Second Language quirk
  uses: each word gets through with that chance, common words more often. 25% is that quirk's lowest setting.
  Applying preferences clears the old levels first, so a level never outlives a change.
- **Checked on the server.** `set_language_understanding` takes a level only for a language the character has
  picked and only understands, and only a number, which it snaps to a step. It never adds a language.
- **Saves stay small and compatible.** Only understood-only languages set below 100% are saved, under
  `language_understanding`, keyed by their type. A save without the key loads with every language followed in full,
  as before. Loading drops unknown languages and anything that isn't a number, and snaps the rest into range. Code
  without this module ignores the key.
- **Samples are kept.** Each language's sample line is scrambled once per level and kept.

### TG Proc/File Changes:

Existing-file edits use `APHELION EDIT` markers with their original code retained; Nova files are edited directly.
New UI files start with `// THIS IS AN APHELION UI FILE`.

| File | Procs or declarations changed |
| --- | --- |
| `code/modules/client/preferences_savefile.dm` | `/datum/preferences/proc/switch_to_slot()`: a slot that fails to load also clears the levels. |
| `modular_nova/master_files/code/modules/client/preferences_savefile.dm` | `load_character_nova()` and `save_character_nova()` read and write `language_understanding`. |
| `modular_nova/master_files/code/modules/language/language_holder.dm` | `/datum/language_holder/proc/adjust_languages_to_prefs()` clears the levels it granted, then grants each understood-only language set below full as partial understanding. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LanguagesMenu.tsx` | `KnownLanguage` shows the slider for a language only understood; `LanguagesPage` says what it does. |
| `tgui/packages/tgui/interfaces/PreferencesMenu/types.ts` | Adds `PreferencesMenuData`'s `language_understanding` and `language_understanding_samples`. |

### Modular Overrides:

- `code/language_understanding.dm`: adds `/datum/preferences/var/language_understanding` with
  `language_understanding_level()` and `saved_language_understanding()`, and the
  `/datum/preference_middleware/language_understanding` middleware.

### Defines:

- `code/language_understanding.dm`: `LANGUAGE_UNDERSTANDING_MIN`, `LANGUAGE_UNDERSTANDING_STEP` and
  `LANGUAGE_UNDERSTANDING_SAMPLE`. File-local.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/LanguageUnderstanding.tsx`: the slider, its
  label and the sample line, with `LanguageUnderstanding.test.tsx`.
- `tgui/packages/tgui/styles/meridianos/_preferences.scss`: the label's and the sample's styles.
- `code/modules/unit_tests/~nova/language_understanding.dm`, included from `code/modules/unit_tests/_unit_tests.dm`.
- `tgstation.dme`

### Credits:

- mal
