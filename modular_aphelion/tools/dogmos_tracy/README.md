# Windows capture

## One-click developer checkout capture

`START_CAPTURE.cmd` / `Start-DogmosCapture.ps1` require a complete developer
checkout containing `tgstation.dme`, the compiled `tgstation.dmb`, `data`,
`tools/dogmos/verify_contract.py`, both generated DM contract files and the
installed native lock/library. A normal TGS/production deployment omits part of
this closure and is rejected. Do not copy missing source files into a deployment
to make this admission check pass. Use the portable collector below for deployments.

Keep the complete prepared profiler bundle (`bin`, `licenses`, `provenance`,
`bundle.json`) together. Run `START_CAPTURE.cmd` as administrator and select the
developer checkout and supported DreamDaemon executable. Paths are saved in
`capture-settings.json`; update them when the checkout or engine changes.

```powershell
.\Start-DogmosCapture.ps1 -CheckOnly -GameDirectory 'D:\Development\Meridian-Rift'
```

The launcher verifies bundle startup and installed Dogmos identity, rejects an
existing marker/listener and checks output access. When Ready, start a new local
world from that checkout using the selected engine. The launcher does not restart
a game. It waits up to ten minutes and records five 120-second windows by default.
Keep `launch.json`, `capture.json`, traces, round logs and workload details together.
Both completion flags and unchanged game/native hashes are required; traces still
need review. `CheckOnly` does not certify a live connection or workload.

The launcher removes only its own unchanged, unconsumed empty marker on completion
or handled failure. A replaced or pre-existing marker is preserved. Abrupt process
termination can bypass cleanup; inspect the marker before another unprofiled round.
Partial evidence and cleanup errors remain in the launch record.

`RUN_SERVER_PROFILE.cmd` similarly scopes the marker to its local RIFT run. It
preserves pre-existing markers and removes its own unchanged marker in `finally`.
It does not alter `AUTO_PROFILE` or production configuration defaults.

## Collector prerequisites and manual modes

Run the portable bundle from a local administrator PowerShell session alongside TGS. The script targets Windows PowerShell 5.1 or PowerShell 7 on Windows Server 2022. Its pinned x86 hook supports BYOND **516.1685–516.1687**; the collector is x64 and uses Tracy v0.14.0/protocol 82. It does not require Codex or Meridian-MCP on the server.

The collector requires the **x64 Microsoft Visual C++ v14 Redistributable**, at least as recent as its MSVC 14.44 build tools. Install the signed package directly from [Microsoft's supported downloads](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist). Microsoft lists Windows Server 2022 as supported. The bundle does not redistribute Microsoft runtime DLLs or the BYOND installation. The hook itself imports only Windows system libraries.

Set `$game` to the actual TGS game directory containing `tgstation.dmb` and `data`. TGS deployments can change this directory or replace native files: verify the path again after any deployment. Do not aim the script at a repository clone while TGS is running a different deployment directory.

```powershell
$game = 'D:\TGS\Instance\Game'
.\Capture-Dogmos.ps1 -Mode Check -GameDirectory $game
.\Capture-Dogmos.ps1 -Mode ArmNextRound -GameDirectory $game `
    -DreamDaemonPath 'D:\TGS\Byond\516.1687\byond\bin\DreamDaemon.exe'
.\Capture-Dogmos.ps1 -Mode Capture -GameDirectory $game `
    -OutputDirectory 'D:\Captures\dogmos-startup-01' -WindowSeconds 120 -Windows 5
```

`Check` validates bundle hashes and starts an empty collector session to verify its runtime dependencies without connecting to the game. This startup check also runs before arming profiling. Set `DreamDaemonPath` to the executable for the BYOND version selected in TGS; `ArmNextRound` rejects unsupported versions before installing or arming the hook. It copies `prof.dll` only if absent, rejects a different installed binary, and creates the existing one-shot `data/enable_tracy` marker. It does not change TGS settings or reboot the server. Start `Capture` before the normal TGS reboot; it waits up to ten minutes for the profiled DreamDaemon. This captures ten minutes in five windows, covering initialization and shift-start. If startup is longer, increase `Windows` up to eight. Total requested duration is limited to 25 minutes and each individual window to five minutes.

The hook defaults to `127.0.0.1:8086`. If TGS inherits `UTRACY_BIND_ADDRESS` or `UTRACY_BIND_PORT`, ensure those select loopback and the chosen profiler port. Changing variables in an administrator shell does not change an already-running TGS service's environment. The script rejects non-loopback listeners and listeners whose loaded hook comes from another game directory. No firewall opening is needed.

`capture.json` records validation, window hashes and completion/failure. `response-*.json` retains collector responses, including capture failures. `processes.csv` samples DreamDaemon and the collector separately at a nominal 250 ms interval; process discovery occurs once per second. Actual sample timestamps capture scheduling delays. Private bytes, working set, virtual bytes and cumulative CPU seconds are reported separately for each process. These are not address-space region maps or native procedure timings. Keep the round logs and add the map, seed, exact deployed merge SHA, hardware description, scenario and timestamps of actions alongside the capture.

Windows have short attachment gaps and omit early startup before the first capture window. Do not sum overlapping inclusive procedure costs. Profiling itself adds overhead: compare repeated runs using the same instrumented setup and workload. The BYOND hook profiles DM procedure execution; it cannot split a synchronous Dogmos call into native Rust procedures. Separate native instrumentation would need a reviewed native release.

The capture stops only its own collector. It never stops DreamDaemon or TGS. The hook drains/discards events when no collector is connected. Its instrumentation remains loaded until the next hard restart. The existing game consumes the one-shot marker at startup; verify it is gone before the next round. If abandoning an armed capture before startup, remove only the `data/enable_tracy` marker you created. Do not replace or delete a loaded `prof.dll`; stop the profiled game normally before removing it.

Redistribution is permitted under the included licenses: [Tracy BSD-3-Clause](https://github.com/wolfpld/tracy/blob/099df3de3dc37eca4712c06b8320fb9c53596edd/LICENSE), [byond-tracy and its LZ4 BSD-2-Clause notices](https://github.com/spacestation13/byond-tracy/blob/d1ec404737b04b1ea73d6df4a1b477deacdb1900/LICENSE), and the bundled Meridian helper and dependency notices. Keep `licenses` and `provenance` with the binaries. Do not claim upstream endorsement. The hook includes the Meridian empty-queue and health patches; the collector includes the Meridian clock-access patch and fixed-command wrapper. Exact hashes are recorded in `bundle.json` and the original helper manifest.

The PowerShell script is supplied as source under Meridian-Rift's AGPL-3.0 license, included in `licenses`; the separately launched collector and hook retain their own licenses. Preserve the source script and these notices when sharing the bundle.

The script and bundle need a real server capture before Windows Server 2022 deployment acceptance can be claimed. Local fixture and repository validation results are recorded in the repair handoff.
