# symphony

Discord-role whitelist gate for the server, paired with the **SSymphony** bridge (separate repo). Players must link their Discord and hold a configured role to enter a round, and are returned to the lobby (after a grace period) if they lose it.

**Off by default.** With `SYMPHONY_ENABLED` unset, players can enter normally, while whitelist-role perks and Discord admin synchronization are disabled. Authenticated bridge topics, including moderation and status, remain available. Discord admin synchronization additionally requires `SYMPHONY_DISCORD_ADMIN_SYNC`.

## How it works

- Un-whitelisted players can't ready up or late-join. Ready actions, round-start admission, and `AttemptLateSpawn` are gated, fail-closed. They use the **Get Whitelisted** verb (OOC tab), which opens SSymphony's OAuth flow using a one-time `discord_links` token.
- The whitelist check reads the shared MySQL: a ckey is whitelisted iff its linked `discord_id` holds a role mapped to the in-game `whitelist` role in `symphony_role_grants` (kept current by SSymphony). The generic helper `symphony_has_ingame_role(ckey, key)` supports other in-game roles too (e.g. `staff`, `donator`). The Discord-role to in-game-role mapping is managed in SSymphony's panel, not in game config.
- SSymphony pushes `whitelist_revoke` / `whitelist_grant` world topics; on revoke, the player gets a grace period then is returned to the lobby. `SSsymphony` re-checks connected players periodically as a safety net.
- **Symphony Status** (admin verb, Server tab) reports this module's version, what SSymphony last said about itself and when, and which of the two is behind if they disagree. The panel shows the same thing per server under Server settings. Bump `SYMPHONY_MODULE_VERSION` in `_version.dm` and `EXPECTED_GAME_MODULE` in SSymphony together.

## Config (add to your config to enable)

| Key | Meaning |
|-----|---------|
| `SYMPHONY_ENABLED` | Enables whitelist enforcement and role-based perks; also required for Discord admin synchronization. Panel changes apply to the running server; restart values come from the config file. |
| `SYMPHONY_URL` | SSymphony base URL, e.g. `https://symphony.example.com`. |
| `SYMPHONY_GRACE_SECONDS` | Seconds between losing the role and lobby return (default 30). |
| `SYMPHONY_TOPICS_LOCAL_ONLY` | Flag, off by default. On, Symphony world topics are only answered for local senders plus the addresses below; anything else gets `Bad Address`. |
| `SYMPHONY_TOPICS_ALLOWED_ADDRESSES` | One address per line, only read when the flag above is on. For a panel that isn't on the game's machine. |

Which Discord roles grant the whitelist (or any in-game role) is configured in **SSymphony's panel** → In-game roles, not in game config. Requires the SQL backend enabled and SSymphony running against the **same** database, with matching table prefix. See the SSymphony repo for the bridge setup.
