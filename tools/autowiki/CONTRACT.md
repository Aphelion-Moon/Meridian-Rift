# Autowiki data contract

Generated from `contract.json`. Edit the source contract, then run `node tools/autowiki/generate-contract.js`. JSON Schema describes record shape; package integrity, permissions, semantic checks and publication ownership are enforced by the importer.

| Domain | Fields | Relationships |
| --- | ---: | --- |
| entity | 42 | ammo_type, mag_type, projectile_type, armor_type, circuitboard_type, stock_part_base_type, construction_result, construction_components, construction_alternatives |
| research_node | 10 | prerequisite_nodes, unlocked_designs |
| design | 14 | build_path, unlocked_by, make_reagent, materials |
| reagent | 13 | inverse_chem |
| reaction | 19 | results, required_reagents, required_catalysts |
| crafting_recipe | 16 | result, reqs, tool_paths, machinery, structures |
| supply_pack | 13 | contains, crate_type |
| job | 13 | outfit |
| outfit | 23 | uniform, suit, back, belt, gloves, shoes, head, mask, neck, ears, glasses, l_pocket, r_pocket, suit_store, l_hand, r_hand, backpack_contents, belt_contents, implants |
| vending | 12 | products, contraband, premium |
| species | 11 | mutant_organs |
| projectile | 10 |  |
| material | 5 |  |
| surgery | 8 | implements |
| armor | 4 |  |
| scenario | 7 | subject |
| dictionary | 4 |  |

Every record carries a source identity and typed values. DM lists preserve explicit key/value pairs. Null remains distinct from zero. `deferred_fields` identifies unevaluated initialization; `dynamic_fields` identifies runtime-variable reaction values. `scope` and `appearance_scope` describe conditions, not gameplay promises.

Stable `documentation_id` values survive type moves. `documentation_family` groups explicit variants; matching names and identical image bytes do not establish a shared identity. Visibility is explicit: unknown records stay in the workshop until reviewed.

## API

`action=autowikidata&view=records` returns a bounded page of records. Registered reviewers may select an imported `build`, `kind`, `query`, `key` and `offset`. Anonymous readers can access only the active public projection. Review-only views are `status`, `issues`, `decisions`, and `guides`.

`action=autowikidecision` requires POST, CSRF, human review rights and a current base revision. Operations are `save`, `bulk` (at most 20 reviewed rows), `prepare`, `activate`, and `retry`. Publication operations additionally require `autowiki-publish`. Bot-group accounts cannot edit human decisions.

Decision records retain a target, type, value, reason, source fields, fingerprint, state and evidence build. Their wiki revision provides author and history. The importer has no operation for rewriting these records.
