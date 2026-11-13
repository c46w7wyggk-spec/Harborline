> Source: economy design workstream (subagent), 2026-11-13. **Adapted by the lead:** the generated map is larger than assumed here (race lap ≈ 6,200 studs, 3-stop Courier Run ≈ 2–3 min), so per-job cash/time numbers in `src/shared/Config/Jobs.luau` differ; Rep levels, vehicles, business table, freshness and abuse rules are used as written. Config files are the source of truth.

# Economy & Gameplay Design: City Sandbox (Private Beta)

Scope: Cash (integer, spendable), Rep (integer, never spent, sets the level). 3 jobs, 5 vehicles (1 free + 4 buyable), 1 business path (Noodle Cart -> Harbor Kitchen). No monetization. All numbers are server-authoritative and live in one config module.

---

## 1. Core loop & pacing targets

**Loop:** take a job -> earn Cash + Rep -> buy a faster car or a business upgrade -> jobs get faster or pay more -> Rep unlocks the Vault Job and higher tiers -> collect the business stash -> repeat.

| Moment | Target | How it's met |
|---|---|---|
| First job started | < 60 s after spawn | Spawn next to the Courier depot, with a HUD arrow to it |
| First payout | < 2.5 min | Near-tier delivery; the first run of each job pays 2x |
| First purchase | 5-8 min | Noodle Cart (500) |
| First vehicle | 15-25 min | Tern Hatch (1,500, Rep L2) |
| Heist unlocked | 45-60 min | Rep L3 (300 Rep) |
| Mid goals | 2-5 h | Ridgeback, Diner/Night Kitchen, Vireo GT |
| Big goal (Nightjar + Business L4) | ~11 h (range 8-15) | See section 6 |

Session shape: 20-40 min sessions. The business stash fills in ~17-25 min, so collecting it is a natural reason to come back.

---

## 2. Job config (paste into Luau)

**Distance assumptions (tune these):** 1 stud ~ 0.28 m. Race loop 1.2 km ~ **4,300 studs**, 8 checkpoints. Average lap speed ~ **0.8x the car's maxSpeed** (corners, accel). Delivery address tiers: near <= 900 studs, mid <= 1,500, far <= 2,200 (path distance from the depot). Heist drop-offs 2,500-4,500 studs from the vault. Walk speed 16 studs/s.

Expected race lap times: Pebble (50) ~107 s, Tern (60) ~90 s, Ridgeback (70) ~77 s, Vireo (82) ~66 s, Nightjar (95) ~57 s. So the starter car gets bronze, Tern gets silver, and Ridgeback or better gets gold. Gold with Tern takes skill.

```lua
Economy.Jobs = {
  Courier = {          -- "Courier Run"
    baseCash = 100, firstRunMult = 2.0,
    tiers = {          -- address picked at random; weights 40/40/20
      near = { cashMult = 1.0, rep = 6,  timeLimit = 60,  minSeconds = 12 },
      mid  = { cashMult = 1.5, rep = 9,  timeLimit = 90,  minSeconds = 18 },
      far  = { cashMult = 2.0, rep = 12, timeLimit = 120, minSeconds = 25 },
    },
    timeFloorFactor = 0.4,  -- see formula below
    startCooldown = 5,      -- s between job starts (anti start/cancel spam)
    repLevelRequired = 1,
    usesFreshness = true,
  },
  Race = {             -- "Harbor Sprint"
    requiresVehicle = true, checkpoints = 8, loopStuds = 4300,
    medals = {         -- finish time <= seconds
      gold   = { time = 80,  cash = 300, rep = 20 },
      silver = { time = 95,  cash = 200, rep = 14 },
      bronze = { time = 115, cash = 120, rep = 8  },
    },
    timeLimit = 150,    -- DNF after this; pays 0
    minSeconds = 42,    -- 4300 / (95 * 1.08); faster = reject + flag
    segmentSpeedCap = 95 * 1.15, -- per-checkpoint check: segDist / dt must not exceed this
    firstRunMult = 2.0, startCooldown = 10,
    repLevelRequired = 1, usesFreshness = true,
  },
  Heist = {            -- "Vault Job"
    repLevelRequired = 3,
    crackHoldSeconds = 5,
    heatTimer = 120,     -- from crack complete to drop-off
    baseCash = 1500, cashPerRepLevelAbove3 = 0.15, -- L8 = 1500 * 1.75 = 2625
    rep = 50, failRep = 5, failCash = 0,
    minSeconds = 40,     -- crack 5 + 3000 studs / 95 + margin; per-drop: 5 + dist/(95*1.1)
    cooldown = 600,      -- s, starts on success OR fail; persisted as a unix timestamp
    abandonCooldown = 300,
    carrySpeedCap = 12,  -- on-foot walk speed with the bag; cannot sprint
    usesFreshness = false, -- the cooldown does this job's limiting
  },
}

Economy.Freshness = {     -- per job type, 0.35..1.0, saved in player data
  decayOnComplete = 0.15, -- this job's value, applied after payout
  recoverOnOtherJob = 0.25, -- every OTHER fresh-tracked job gains this when any job completes (heist counts)
  recoverPerMinute = 0.03,  -- passive, only while online
  floor = 0.35,
  appliesTo = "cash+rep",
}
```

**Delivery payout:**
```
cash = floor( baseCash * tier.cashMult
              * (0.4 + 0.6 * clamp(tRemaining / tier.timeLimit, 0, 1))
              * freshness.Courier
              * (1 + business.courierBonus)
              * (firstRun and 2 or 1) )
rep  = floor( tier.rep * freshness.Courier )
```
A late delivery (timer hits 0) pays 0 cash and 0 Rep. The average car run is about 110 cash. On foot, a near-tier run pays about 45, which keeps on-foot play possible but clearly worse.

**Freshness in practice:** spamming Courier runs goes 1.0 -> 0.85 -> 0.70 -> ... -> 0.35. Alternating Courier and Race keeps both at about 1.0. The HUD shows a small "fresh / stale" pip on each job marker.

---

## 3. Rep levels

| Level | Total Rep | Unlocks | Approx. time |
|---|---|---|---|
| 1 | 0 | Courier, Race, Pebble | 0 |
| 2 | 100 | Tern Hatch | ~18 min |
| 3 | 300 | **Vault Job**, Business L2 | ~55 min |
| 4 | 700 | Ridgeback | ~1.6 h |
| 5 | 1,300 | Business L3 | ~2.6 h |
| 6 | 2,200 | Vireo GT | ~4 h |
| 7 | 3,500 | Business L4 | ~5.6 h |
| 8 | 5,200 | Nightjar | ~7.9 h |
| 9 | 7,500 | cosmetic title/paint | ~11 h |
| 10 | 10,500 | cosmetic title/paint | ~15 h |
---

## 4. Vehicles

| id | Display name | Price | Rep Lv | maxSpeed (studs/s) | accelMult |
|---|---|---|---|---|---|
| `pebble` | Pebble (starter, owned by all) | 0 | 1 | 50 | 1.00 |
| `tern` | Tern Hatch | 1,500 | 2 | 60 | 1.15 |
| `ridgeback` | Ridgeback | 9,000 | 4 | 70 | 1.30 |
| `vireo` | Vireo GT | 32,000 | 6 | 82 | 1.50 |
| `nightjar` | Nightjar | 95,000 | 8 | 95 | 1.70 |

The server must hard-clamp each vehicle's speed at maxSpeed x 1.05. The anti-cheat floors above assume 95 is the global top speed. If you add a faster car, recompute every `minSeconds`.

---

## 5. Business: "Noodle Cart -> Harbor Kitchen" (bonus applies to Courier)

| Lv | Name | Cost | Rep Lv | Cash/min (online) | Stash cap | Fill time | Courier bonus |
|---|---|---|---|---|---|---|---|
| 1 | Noodle Cart | 500 | 1 | 12 | 200 | ~17 min | +10% |
| 2 | Noodle Stand | 4,000 | 3 | 35 | 700 | 20 min | +20% |
| 3 | Night Diner | 16,000 | 5 | 80 | 1,800 | 22.5 min | +35% |
| 4 | Harbor Kitchen | 50,000 | 7 | 160 | 4,000 | 25 min | +50% |

Rules: the stash fills only while the player is online and **active** (input in the last 120 s, or a job completed in the last 10 min). It stops at the cap. Collecting requires standing at the stall's prompt, which is checked on the server. Nothing accrues offline. Total business cost is 70,500.

---

## 6. Projected earnings (varied play: jobs mixed, heists on cooldown, stash collected)

Model rates: 0-1 h ~4.5k/h; 1-3 h ~10k/h (first heists at ~80% success, Business L1/L2); 3-6 h ~18k/h; 6 h+ ~27k/h (heist ~2.4k x ~4.3/h ≈ 11k, Business L4 ~9.6k, jobs ~6k). Rep: ~330/h early, ~600/h from 1-3 h, ~750/h after.

| Playtime | Cumulative cash earned | Rep (Lv) | Purchase(s) at or before this milestone |
|---|---|---|---|
| 10 min | ~1,000 | ~55 (L1) | Noodle Cart at ~6 min |
| 30 min | ~2,600 | ~165 (L2) | Tern Hatch at ~20 min |
| 1 h | ~4,500 | ~330 (L3) | Vault Job unlocked; saving for the Stand |
| 3 h | ~24,500 | ~1,550 (L5) | Noodle Stand (~1.3 h), Ridgeback (~2 h) |
| 10 h | ~187,000 | ~6,800 (L8) | Night Diner (~3.5 h), Vireo GT (~5.1 h), Harbor Kitchen (~7.3 h); ~74k saved toward the Nightjar |
| **~10.8 h** | **~208,000** | L8 | **Nightjar: big goal done** (vehicles 137.5k + business 70.5k) |

Heist-heavy players will reach the big goal in about 8-9 h. Casual Courier-only players will take about 14-15 h, because freshness limits them.

---

## 7. Abuse cases & mitigations

| Abuse | Mitigation |
|---|---|
| Farming one job | Freshness decays to a 0.35x floor. Recovery comes from other jobs or passive time. Freshness values are saved, so rejoining does not reset them. |
| Rejoin / server-hop to reset the heist cooldown | Store the cooldown as an absolute `os.time()` expiry in the player's DataStore profile, along with freshness and the job-start lockout. Never keep it in memory only. |
| Abandon a heist to re-roll a closer drop-off | Abandoning sets a 300 s cooldown. The drop-off is chosen on the server at crack-complete. |
| AFK farming | No offline income. Business income needs activity (section 5) and has a hard cap. No job pays without a server-validated start, checkpoints, and finish. |
| Teleport / speed exploits | The server checks the per-job `minSeconds` floor, per-segment speed (`dist/dt` must not exceed 95 x 1.15), ordered checkpoints, and that the player is near the prompt for pickup, crack, and drop. On violation: pay 0, log the event, and increment a flag counter. After 3 flags in a session, kick and review. |
| Client-fired payout remotes | Remotes only report intent (for example "I'm at the drop"). The server checks position, job state, and timers, then calculates the payout. The client never sends an amount. |
| Disconnect during payout | Payout is one atomic profile update: cash, rep, freshness, and cooldown together, using a session-locked profile (ProfileService-style) and `UpdateAsync`. Job state is server-only. If the player disconnects mid-job, the job is voided with no payout. If they disconnect after the server confirms completion, the payout is already written. Use an idempotent job id so the same job cannot pay twice. |
| Save duplication (leave and rejoin while a save is pending) | Session locking: a new server waits for or steals the lock before loading. Never trust a stale copy. |
| Alt accounts | There is no trading or gifting of cash, cars, or business, so alts cannot pass wealth to a main account. Each alt has to grind on its own. |
| Collusion / bag passing in heists | Loot bags are tied to the player who cracked the vault. Handing over the bag is not supported in the beta. |
| Start/cancel spam | `startCooldown` of 5-10 s. A cancelled race counts as a completion for freshness decay. |
| Unknown exploits | Server sanity alert if one player earns more than 40k cash per rolling hour. For the beta, log every payout (job, time taken, amount) for tuning. |

---

## 8. "Next goal" HUD logic (one recommendation at a time)

Evaluate this list in order every 5 s and when a job ends. Use the first rule that applies:

1. **Collect stash** if the stash is at 80% or more of its cap.
2. **Buy now:** if any next-tier item (the next vehicle tier or the next business level) is affordable and its Rep level is met, show "Buy <item>". If both qualify, choose the business (it compounds).
3. **First-time hooks:** if the Vault Job is unlocked, off cooldown, and has never been done, show "Try the Vault Job". If a job has never been done, show it with the 2x tag.
4. **Progress goal:** among the next vehicle tier, the next business level, and the next Rep unlock, compute
   `ETA = max(cashShort / cashRate, repShort / repRate)`. The rates are this player's rolling 15-min averages, with the section 6 phase rates as defaults. Show the item with the lowest ETA, with a progress bar for cash and, if needed, Rep.
5. **Job hint (sub-line):** suggest the freshest available job ("Heist ready", or "Race is fresh: 1.0x") whenever the last job's freshness is below 0.7.

**Hysteresis:** keep the current goal shown until it is completed or bought. Only rules 1-3, or a new goal whose ETA is under half the current one, may replace it. This stops the goal from flickering. Clicking the goal places a waypoint to the relevant shop, stall, or job marker.
