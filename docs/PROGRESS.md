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
