# Progress Log

Newest entries at the bottom. "Automated" = ran in the cloud container. "Manual" = needs a human in Roblox Studio or on a device.

## 2026-11-13 — Phase 0: discovery and plan
- Inspected: empty working directory, no git repo, no `.rbxl(x)`, no Rojo/Wally/Aftman config. No Roblox repo in Josh's GitHub.
  Josh's Mac (linked device) has the Roblox player app; Roblox Studio not found in `/Applications`.
- Decision: new Rojo project, map generated in code. Josh created `c46w7wyggk-spec/harborline`; work on branch `claude/private-beta`.
- Tooling: GitHub release downloads blocked by the network policy (403) → installed `rojo 7.7.1`, `stylua`, `selene`,
  `lune 0.11.1` with `cargo install --locked` from crates.io.
  - `selene generate-roblox-std` fails (needs setup.rbxcdn.com, blocked) → selene not used; replaced by a Luau compile
    check plus a smoke test against lune's bundled Roblox reflection database.
  - Building `luau-lsp` from source for type checking was declined by the environment's safety policy (external code) → not used.
- Delegation: Claude Code subagents available. Used for (1) policy/compliance research → `docs/COMPLIANCE.md`,
  (2) economy design → `docs/ECONOMY.md`, (3) quality review (report-only) → findings below. All code written by the
  lead; no two agents edited the same files.
- Wrote `docs/ARCHITECTURE.md` (folder ownership, data contracts, remotes, decisions, risks).

## 2026-11-13 — Phases 1–2: foundation, jobs, economy
- Shared: `Config/WorldLayout|Jobs|Progression`, `Economy`, `Schema`, `Validate`, `RateLimiter`, `Tutorial`.
- Economy numbers adopted from the design doc, adapted to the larger map (race lap ≈ 6.2k studs).
- Jobs as pure state machines (`src/server/Jobs/*`) driven by server position sampling.
- **Automated:** `lune run tests/run` → 32/33 at first: the race anti-cheat floor (55 s) was *above* the fastest legal
  lap (straight-line 5,331 studs / 109 studs/s = 48.8 s), which would have rejected legit Nightjar runs. Fixed (45 s)
  and added per-run path-length floors for Courier and Vault Job. → 33/33.
- Server: DataService (session lock), Net gateway, StateService, TutorialService, VehicleService, JobService,
  ShopService, WorldBuilder, Main. Client: Store, Theme, HUD, Menus, Waypoint, VehicleController, Input.

## 2026-11-13 — Smoke testing outside Studio
- New `tests/smoke_world.luau` runs WorldBuilder, every vehicle build and the full client UI with `@lune/roblox`
  instances (property names/types/enums validated against the reflection DB). Bugs it caught and fixed:
  - `Enum.Material.CorrugatedMetal` doesn't exist (API name is `CorrodedMetal`) → would have errored at server start.
  - `CollectionService:AddTag` replaced with `Instance:AddTag` (works in both).
- Geometry check: all 28 gameplay points (places, addresses, checkpoints) are clear of solid buildings.
- Part count 731 (target < 3000 for mobile).
- `scripts/check.sh` = format + compile + unit + smoke + rojo build. **All pass.**

## 2026-11-13 — Phase 4: independent review and fixes
Reviewer agent (report only) found 1 BLOCKER, 9 MAJOR, ~12 MINOR (`docs/QA_REVIEW.md`). Lead verified each against the
code and fixed:
- **C1 blocker / A1 / A2 / A4 (anti-cheat):** the per-tick teleport check would cancel jobs and kick laggy phone
  players, while letting 24-stud micro-steps through. Replaced with `shared/MovementGuard` (2 s window, budget from
  the vehicle actually driven, on foot 40 studs/s). Lag spikes pass; teleports void the job and flag; borderline
  speed only raises "suspect" (3 per run voids the payout, never kicks). Car overspeed watchdog now only raises
  suspicion, so being flung by another player can't get you kicked. Job time floors use the fastest car driven
  that run (+5%) instead of a global 110 studs/s. 5 new unit tests.
- **B1/B2 (save races):** saves re-check `released`/`releasing` after waiting; release removes the session before
  yielding; same-server rejoin waits for the leave-save; locks carry a per-session token.
  **B3** shutdown voids active jobs before the final save. **B4** urgent saves queue even during an autosave.
  **B5** corrupt records are backed up to `p_<id>_corrupt_<t>` and reset instead of locking the player out.
  **B6** lock stale 90 s, load retries ~100 s.
- **C2:** "Drive" ProximityPrompt seats the owner (server-side `Seat:Sit`). **A3:** empty cars are server-owned.
- **E1/E2 (first minutes):** first Courier Run uses the 3 addresses nearest the Depot, nearest-next order, with a
  walkable time limit; every run's limit and pay scale with route length. First delivery pays at least $400 and the
  Noodle Cart costs $400, so the tutorial promise holds (unit-tested). Tutorial suggests spawning the free car.
- **D1/D2/C6/C7/C8 (UI):** goal card moved under the stats panel; phone UI scale floor 0.8 with 56 px buttons
  (≥ 44 pt); menu cards auto-size; live cooldown countdown; gamepad focus kept on re-render; result-card and toast
  ordering bugs fixed. **C4** analog throttle eases. **C5** cars stream atomically; ground/roads Persistent.
  **E3** mailboxes moved inside the delivery radius, drop markers added. Vault Job abandon cooldown = fail cooldown.
- **Automated:** `./scripts/check.sh` → format OK, 29 files compile, **40/40 unit tests**, smoke OK (741 parts,
  28 gameplay points clear, 5 vehicles, full UI), rojo build OK.
