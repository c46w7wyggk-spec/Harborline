# QA review (report-only reviewer agent, 2026-11-13) — every finding is resolved or accepted in BETA_STATUS.md

Scope: src/server/**, src/shared/**, src/client/**. I read every file. `./scripts/check.sh` passes
(stylua, compile, 34 unit tests, smoke: 731 parts / 3 prompts, rojo build).
Severity: BLOCKER = fix before beta, MAJOR = fix soon / visible to many players, MINOR = polish or a narrow edge case.
Anything that depends on engine behaviour I could not test is marked **[engine: verify in Studio]**.

---

## A. Security / anticheat

### A1. MAJOR: the teleport check lets players move at about 240 studs/s, because it needs both conditions
`src/server/Services/JobService.luau:205`
`if speed > MaxPlausibleSpeed*1.3 and Layout.distance(...) > 25 then`
At 10 Hz, a jump of 24 studs per tick (about 240 studs/s) never trips it, because the distance is under 25. Characters
and cars are both client-owned, so an exploiter can step the CFrame by 24 studs every tick. The
VehicleService watchdog (`VehicleService.luau:311-313`) reads only `AssemblyLinearVelocity`, which
the exploiter controls, so CFrame stepping gets past it too. What still limits them is the per-job floor,
which uses straight-line length / 110 (see A2).
**Fix:** flag on cumulative distance over a sliding window (for example over 1 s, flag when distance > vehMax*1.3*window + slack).
Don't AND the speed check with a fixed per-tick distance. Use the speed of the vehicle actually driven, not the global 110.

### A2. MAJOR: the race floor ignores the car, so an exploiter in the starter Pebble gets gold every run
`src/server/Jobs/Race.luau:105-107`, `src/shared/Config/Jobs.luau:38,104`
The floor is a flat 45 s, measured against straight-line length at 110 studs/s. The real road loop is about 6,200 studs
((0,700)->(800,700)->(800,-800)->(-800,-800)->(-800,700)->(0,700)). At full speed with no corners, a legit Pebble (50 studs/s)
needs about 124 s, and gold is 105 s. An exploiter flying straight between checkpoints at about 110 studs/s finishes in about 49 s.
That clears the floor, pays gold (600, or 1,200 on the first run) every time, and repeats every 10 s cooldown.
**Fix:** check each checkpoint segment against the floor `segmentDistance / (carMaxSpeed * 1.15)`, using the
chassis `MaxSpeed` attribute read on the server from `cars[player]`. Reject the result if any segment beats it. Apply the same idea to courier
(use walk speed 16 on foot or the car's max when driving) instead of the global 110.

### A3. MINOR: an unoccupied car is network-owned by whichever player is closest
`src/server/Services/VehicleService.luau:194` (no `SetNetworkOwner(nil)` after spawning)
Before anyone sits, ownership is automatic, so a nearby exploiter can own and fling someone else's freshly spawned car.
**Fix:** call `chassis:SetNetworkOwner(nil)` right after `model.Parent = carsFolder`.

### A4. MINOR: client-owned cars can fling other players, and a fling can get the victim kicked
`VehicleService.luau:311-318`: the overspeed flag counts planar velocity on the victim's own car. A victim flung for 2 s or more (4 samples)
gets a flag, and three flags kick them (`JobService.luau:63`). Griefers can therefore get other people kicked.
**Fix:** use watchdog flags to void the current job only, not to count toward a kick. Or ignore samples taken right after a collision or while airborne
(for example when the chassis is not grounded, checked with a downward raycast).

### A5. Checked and fine
- `Net.luau` + `Validate.request` take only id-shaped strings (no tables, NaN, Instances or long strings). There is per-player
  token-bucket rate limiting, and the profile must be loaded before any handler runs. Handlers run inside pcall.
- None of the handlers yield, so buy, upgrade and collect are atomic in Luau and can't race each other.
  `finish()` clears `active[player]` before paying, so a job can only pay once.
- Cooldowns are stored as unix times in the profile. Leaving, dying and cancelling all apply the abandon cooldown, and leaving is
  ordered before the release in the same PlayerRemoving handler (`Main.server.luau:33-36`).
  Rejoining or server-hopping doesn't skip cooldowns, because of the session lock.
- ProximityPrompts only open menus. Buy, upgrade and collect each check distance on the server (40 studs).
- Small cooldown inconsistency (MINOR): Vault Job `abandonCooldown` 300 is shorter than the fail `cooldown` 600 (`Jobs.luau:52-53`).
  A player about to fail on Heat can cancel or reset instead, halving the cooldown at a cost of only 5 rep. Make abandon >= fail.

---

## B. Data loss / duplication (DataService)

### B1. MAJOR: an autosave that overlaps a release puts the session lock back after the player has left
`src/server/Services/DataService.luau:209-220, 305-311`
`save()` checks `session.released` only before the `while session.saving do task.wait` loop.
1. The player leaves, and `release` calls `save(s, true)`, which is in UpdateAsync (`saving = true`; `sessions[player]` is still `s`).
2. The 60 s autosave loop runs and calls `task.spawn(save, s, false)`. `released` is still false, so it waits.
3. The release finishes and sets `released = true` and `saving = false`. The waiting autosave carries on and writes
   `lock = {server = SERVER_ID, t = now}`.
The profile now looks locked for 150 s. On the player's next server, `load` retries for about 60 s (2+4+8+15+15+15)
and then kicks them with "still syncing". The chance per leave is small (the release has to overlap an autosave tick), but it gets
much higher when DataStore requests are slow or retrying, because a release with retries can take 6 s or more.
**Fix:** check `if session.released or not session.canSave then return true end` again after the wait loop. Set
a `releasing` flag at the start of `DataService.release` that makes every non-release save a no-op. Optionally, have
`release` remove the session from `sessions` before it yields.

### B2. MAJOR: a quick rejoin to the same server can load stale data, then roll back the last session
`DataService.luau:156` treats `lock.server == SERVER_ID` as "ours". The lock is keyed by server, not by session.
1. The player leaves. The release UpdateAsync fails once and backs off (`task.wait(2^attempt)`, line 246).
2. The player rejoins the same server (a new Player object), and `load` acquires straight away because the lock looks like ours.
   It reads the record from before the leave.
3. The release retry succeeds and writes the newer data with `lock = nil`.
4. The new session's autosave writes the stale in-memory data back. Progress from the previous session is lost, and between steps 3 and 4
   the record also sits unlocked while the player is online.
This needs a DataStore error at just the wrong moment, but it causes silent progress loss. (I'm not sure whether same-key UpdateAsync
calls from one server are processed in FIFO order. Even if they are, the backoff path in step 1 breaks the ordering.)
**Fix:** put a per-session GUID in the lock (`{server, session, t}`). In `load`, if a release for the same `UserId`
is still running on this server, wait for it to finish first, for example with a `releasing[userId]` map.

### B3. MINOR: a server shutdown during a job doesn't save the abandon cooldown
`DataService.luau:315-329`: BindToClose saves and releases before PlayerRemoving runs `JobService.onPlayerLeaving`, so
the cooldown change lands after `released = true` and is dropped. Low impact. Abandon all active jobs at the start of BindToClose
(a hook from Main).

### B4. MINOR: an urgent save is skipped if another save is already running
`DataService.luau:277`: `markDirty(urgent)` schedules nothing when `s.saving` is true. A purchase or payout made during an
autosave then waits up to 60 s, and a crash in that window rolls it back. Schedule the delay anyway; the callback already
checks `s.dirty`.

### B5. MINOR: corrupt (non-table) `data` locks the player out with a misleading message
`DataService.luau:174-180` + `Schema.migrate` returns nil for non-table data **and** for newer versions, so a corrupt record
kicks the player every time with "older version of Harborline". Tell the two cases apart: corrupt data should be logged and
replaced by `Schema.sanitize`'s defaults only after a backup copy is written (or at least it should get its own message).

### B6. MINOR: the load retry window (about 60 s) is shorter than LOCK_STALE_SECONDS (150 s), and the docs say 120
`DataService.luau:26,29,199`. After a server crash, a player who rejoins within 150 s is kicked once or twice before the
lock goes stale. Lower the stale time to about 90 s (autosave runs every 60 s) or make the retry window longer. ARCHITECTURE.md says 120 s; align it.

### B7. Checked and fine
Failed loads never fall back to defaults on live servers. Studio uses its own store and memory mode. A player who leaves during the load gets
`releaseLockOnly`. The `markDirty` delayed save checks `sessions[player] == s and not s.saving`, so it can't fire
after the release. A lost lock sets `canSave = false` and kicks. Handler order in Main (abandon, then release, in one handler) is
correct. Other services' PlayerRemoving handlers don't touch profile data, so connection order doesn't matter.

---

## C. Runtime correctness and Roblox API

### C1. BLOCKER (mobile): a short network stall cancels the job, and three stalls kick the player
`JobService.luau:200-213`. `lastPos`/`lastT` update every 0.1 s tick even when the replicated position hasn't changed.
When a client's physics updates stall (common on phones) and then catch up, the whole movement lands in one 0.1 s tick:
a 0.3 s stall at 95 studs/s is 28 studs in one tick, which is 280 studs/s and more than 25 studs. The check flags it and cancels the job with no pay ("movement
check failed"). Three flags kick the player. With the Pebble it takes about a 0.5 s stall, with the Nightjar about 0.27 s.
**[engine: verify in Studio]** how much the server buffers client-owned physics, but stalls followed by catch-up are normal behaviour.
**Fix:** measure speed against the time since the last *changed* sample, or over a window of 1 s or more (this also fixes A1). Don't cancel
the job on a single flag; only cancel or deny payment when a cumulative budget is exceeded.

### C2. MAJOR: "Walk up and sit to drive" doesn't work by walking
`VehicleService.luau:128-139, 273`. The seat is a 2x1x2 invisible, non-colliding VehicleSeat on the middle of the roof
(about 3 studs in from each side and 3.5 studs off the ground). Seats need the character to *touch* them. Walking into the
chassis side never reaches the seat, so players have to jump onto the roof, and the seat is invisible. Touch and gamepad players won't figure this out.
**Fix:** add a ProximityPrompt ("Drive", E / ButtonX) on the chassis. On the server, `Triggered` checks
owner == player and distance, then calls `seat:Sit(humanoid)`. Keep the seat touchable as well.

### C3. Driving approach: will it drive?
Reading the code, it is internally consistent:
- The seat CFrame comes from the chassis, so the character faces the chassis LookVector (-Z), which is the side the headlights are on.
  Forward = LookVector * speed. The yaw sign is correct (`-steer` with SteerFloat +1 = D turns right).
- `LinearVelocity` (Plane mode, World, X/Z tangents, MaxForce 60k with Magnitude limit mode) plus `AngularVelocity`
  (World, only Attachment0) are valid on their own. The constraint properties are set *on the client*, and that works because the driver
  is the network owner; the server's copies stay zero. Total mass is about 150, and 60k N is plenty.
- The default PlayerModule `VehicleController` writes `ThrottleFloat = -moveVector.Z` and `SteerFloat = moveVector.X`
  whenever the humanoid is seated in a VehicleSeat. That covers keyboard, touch thumbstick/DPad and gamepad stick, plus the R2/L2 throttle on gamepad.
  It does not depend on `VehicleSeat.MaxSpeed`; MaxSpeed/Torque only affect the legacy hinge drive, which isn't used here. I'm
  fairly confident about this, but it is **[engine: verify in Studio]** on a real phone and controller.
- The server calls `SetNetworkOwner(player)` when the owner sits and `nil` when they get out (wrapped in pcall, fine).
Open feel risks (all **[engine: verify]**): the 0.6 plaza and 0.4 lot curbs are climbed only by friction-free welded balls,
with pitch locked by a MaxTorque of 400k. Getting out stops the car dead, because the server owns a LinearVelocity of 0.
`MaxTorque` locks pitch and roll at whatever they currently are; it does not level the car.

### C4. MINOR: analog throttle snaps the speed down
`VehicleController.luau:385`: `speed = math.min(speed + ..., maxSpeed * throttle)`. Easing off a gamepad trigger or touch
stick from 1.0 to 0.5 halves the speed in one frame. Clamp to `maxSpeed` and let the throttle scale the
acceleration only, or decelerate toward `maxSpeed*throttle` at the coast rate.

### C5. MINOR: car models stream non-atomically under StreamingEnabled
`default.project.json` turns on StreamingEnabled. Car Models keep the default ModelStreamingMode, so other players' cars can
appear part by part. The client code handles missing children (`FindFirstChild` guards), so nothing errors. Set
`model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic` in `build()`.
**[engine: verify]** The Land part (1680x1620) and the 1764-stud roads are single huge parts. Make sure they stay streamed
in at the map corners, which are about 1,100 studs from Land's centre with StreamingTargetRadius 768. If streaming is
done per part rather than by bounding box, put Ground and Roads in a Model with `ModelStreamingMode = Persistent`.

### C6. MINOR: menu cooldowns never count down, so expired jobs still look locked
`StateService.luau:26-29` sends *remaining seconds* at push time, and nothing pushes when a cooldown ends.
`Menus.luau:72-81` shows "Cooling down: 10:00" for the Vault Job (and dims the button) until some unrelated push arrives.
`nextGoal` text goes stale in the same way. Send absolute `readyAt` and compute the countdown on the client with
`workspace:GetServerTimeNow()`, plus a 1 s re-render while a cooldown is showing.

### C7. MINOR: menus rebuild on every state push
`Menus.luau:296-298`: every push (including the business tick every 10 s) destroys and recreates all cards, which resets
scroll position and clears `GuiService.SelectedObject` for gamepad users partway through navigation. Update the cards in place,
or re-select the same tab or card after rebuilding.

### C8. MINOR: small HUD logic bugs
- `HUD.luau:469-471`: the 8 s auto-hide from an older result hides a newer result card. Keep a token per result.
- `HUD.luau:438-447`: the order of `GetChildren()` isn't guaranteed, so the oldest toast may not be the one destroyed. Use a counter or LayoutOrder.

### C9. Checked
API names used are real and current: `AddTag`, `VehicleSeat.HeadsUpDisplay`, `ProximityPrompt.RequiresLineOfSight`,
`GetPartBoundsInBox`, `OverlapParams`, `ActuatorRelativeTo`, `VelocityConstraintMode.Plane`, and `PhysicalProperties.new` with 5 args.
No RemoteFunction handler yields. The job state machines can't error on nil indices: deliver/stop indices and checkpoint bounds are guarded,
and Heist `escapeStart` is set before the escape state.

---

## D. UI on an approximately 844x390 phone (landscape)

### D1. MAJOR: on phones the goal/tutorial card overlaps the stats and objective panels
`HUD.luau:302, 309, 316, 330`. On touch, `UIScale` is clamped to at least 1 (`vp.Y/720 = 0.54` becomes 1). The usable height is 390 minus the
topbar inset. **[engine: verify]** the inset value: about 36 px on the old topbar, about 58 px on the current one, which leaves 332-354 px.
- Goal card: anchored at the bottom, at `1, -190`, height 84, so it sits at y = 58-142 (58 inset) or 80-164 (36 inset), x = 12-312.
  - With the 58 inset it covers the stats panel (y 8-82): the Rep text and Rep bar.
  - During a job it covers the left part of the objective panel (x 212-632, y 8-104), including the HEAT and CRACKING bar,
    because it's a later sibling and draws on top.
- The objective panel (x 212-632) also overlaps the stats panel (x 12-242) by 30 px.
**Fix:** on viewports with Y below 500, let touch scale go down to about 0.75 (a 48 px button becomes 36 px; or keep the scale and shrink the panels instead).
Place the goal card under the stats panel (top-left, y = stats bottom + 6), or hide it while a job is active. Narrow the objective panel on
small screens (for example `UDim2.new(0.45, 0, 0, 96)` with a max-size constraint).

### D2. MINOR: job card text overflows
`Menus.luau:33-37`: cards are 104 px tall, and the body area is about 60 px. The Vault Job blurb plus the status line wraps to about 4 lines at 14 px
in about 380 px of width, which spills into the next card. Use `AutomaticSize = Y` on the card, or shorten the blurbs.

---

## E. Gameplay / economy

### E1. MAJOR: the first Courier Run (tutorial step 2) is often impossible on foot
`Jobs.luau:24` (210 s limit), `Tutorial.luau:8-10`, `Courier.luau:15-23` (3 random addresses out of 10, in pick order).
Route length from the Job Board to the Depot and then 3 random stops, measured as Manhattan distance along the road grid: min 1,654, **median 3,334**, p90 4,514,
max 6,240 studs. At the default WalkSpeed of 16, that's median 208 s against a 210 s limit, so **about 49% of runs can't be finished even with perfect
running**, and in practice most first-timers fail. Nothing in the tutorial says to spawn the Pebble before step 5. A fail
sends the tutorial back to "start", so new players lose their first minutes and the 2x first-run bonus in a loop.
In the Pebble (50 studs/s) the worst case is 125 s, so the job itself is fine.
**Fix (any of these):** add a tutorial step "Spawn your Pebble (Phone > Garage)" before the courier step; or make the
first courier pick the 3 stops nearest the Depot in route order; or scale the time limit when the player isn't in a car.

### E2. MAJOR: the tutorial asks for $500 right after a payout that is always under $500
`Tutorial.luau:10`. The first courier pays at most `240 * 1.0 * 2 = 480` (`Economy.courierRaw` + FirstRunMult), and about
$390 at a typical Pebble pace. Step 4 says "Nice pay! Spend $500 on the Noodle Cart", but the player can't
afford it, and the tutorial card hides the "next goal" that would tell them to earn more. **Fix:** set the Noodle Cart to $400, or
bump the courier base, or change the text to "Earn $500 and buy the Noodle Cart" and show progress.

### E3. MINOR: the visible delivery mailboxes are outside the delivery radius
`WorldBuilder.luau:372` puts each mailbox and its name billboard at `+26, +26` from the stop, which is 36.8 studs away, while `stopRadius` is 24
(`Jobs.luau:71`). Players who walk up to the labelled mailbox don't get the delivery. The waypoint beam is correct, but the two
cues disagree. Move the mailbox to within about 12 studs (and keep the "clear of solids" smoke check).

### E4. Checked
No exploitable loops for legit players: there's no resale or trading, the business stash is capped and only fills while the player is active,
freshness has a floor of 0.35 and recovers, and the first-run bonus pays once per job. All job targets are reachable: Mint gate 40 studs wide,
vault pad within the crack radius, Warehouse drop centre outside the building, race checkpoints on roads inside the edge walls.

---

## F. Performance
Nothing significant. 731 anchored parts. Server loops run at 10 Hz over active jobs, 2 Hz over players (tutorial), 0.1 Hz
(business), and 2 Hz over cars. Client per-frame work is a few Vector3/string allocations
(`HUD.luau:481-492`, `Waypoint.luau:224-236`, `VehicleController.luau:365-413`), which is negligible. The race objective
(9 checkpoints) is sent at 4 Hz per racer, which is fine.

---

## Priority list
1. C1 + A1 + A2: rewrite the movement check as a windowed, per-vehicle speed budget, and stop cancelling or kicking on single samples.
2. E1 + E2: fix the first-minute flow (spawn the car first, and make the first purchase affordable).
3. B1 + B2: re-check `released` after waiting, add a releasing flag, and give each session its own lock token.
4. C2: add a "Drive" ProximityPrompt on cars.
5. D1: HUD layout on small touch screens.
