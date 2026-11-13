# Beta Status

## Verdict: **NOT READY FOR PRIVATE BETA** (code-complete; blocked only on owner-run Studio verification)

The full vertical slice is implemented and every check that can run outside Roblox passes. It has **never been run
inside the Roblox engine**: Claude had no Roblox Studio access. Driving physics, DataStore behavior, UI layout on
real screens and the default touch/gamepad vehicle input are therefore unverified. Inviting testers before the
Studio checks below would risk a broken first session, so the honest status is NOT READY.

**To flip to READY:** run manual tests M1–M14 in `docs/BETA_HANDOFF.md` §5 (about 1–2 hours), fix anything they
find, complete the content questionnaire, and tick the release checklist (§9).

## Evidence (automated, cloud container, 2026-11-13)

| Check | Result |
|---|---|
| `stylua --check src tests` | pass |
| Luau compile of all 29 source files | pass, 0 errors |
| Unit tests (`lune run tests/run`) | **40 / 40 pass**: economy & rewards, first-run guarantee, freshness, caps, cooldowns, purchases, business accrual/caps, schema sanitising (NaN/inf/unknown ids/corrupt/newer), request validation, rate limiter, movement guard (lag spike vs micro-steps vs teleport), all 3 job state machines, anti-cheat floors, layout invariants |
| Smoke test vs Roblox reflection DB (`lune run tests/smoke_world`) | pass: world builds (741 parts, 3 prompts), 28 gameplay points clear of solids, 5 vehicle models, HUD + all 4 menu tabs build at phone size |
| `rojo build` | pass → `build/Harborline.rbxlx` |
| Independent code review | 1 blocker + 9 major + ~12 minor found; all fixed or accepted below (`docs/QA_REVIEW.md`) |

## Manual verification (owner fills in)

| # | Test | Result | Notes |
|---|---|---|---|
| M1 | First minute / tutorial | ☐ | |
| M2 | Courier Run end-to-end | ☐ | |
| M3 | Driving feel (tune Config/Progression if needed) | ☐ | |
| M4 | Harbor Sprint | ☐ | |
| M5 | Buy → stop → rejoin → still owned (DEV experience) | ☐ | |
| M6 | Leave mid-job (2 clients) | ☐ | |
| M7 | Death mid-job | ☐ | |
| M8 | 3 clients, isolation | ☐ | |
| M9 | Phone layout (device emulator + one real phone) | ☐ | |
| M10 | Gamepad | ☐ | |
| M11 | Network lag 300 ms | ☐ | |
| M12 | Exploit probes | ☐ | |
| M13 | Shutdown save | ☐ | |
| M14 | Vault Job | ☐ | |

## Known limitations / accepted risks

- **Physics feel is untuned.** The arcade car (velocity constraints on a sliding chassis with ball skids) is
  consistent on paper but needs Studio tuning. Getting out stops the car instantly.
- **Client-owned cars** are needed for responsive driving, so a determined exploiter with noclip could still cut
  corners at about legal speed. Payout floors, the 2 s movement budget and the speed watchdog limit the gain; the
  flags in the logs need review during the beta.
- **No in-world NPCs, police or traffic.** The "Heat" pressure is a timer. This is deliberate for content rating and scope.
- **One district, one business path, no trading, no monetization.** All deliberate for the beta.
- **Text is English only.** There's no player-typed text anywhere, so no filtering is needed.
- **Content label:** the stylized vault-robbery theme may raise the questionnaire result above Minimal/Mild
  (`docs/COMPLIANCE.md`). If that's unacceptable, the Vault Job can be reskinned (for example "Treasure Recovery") by
  editing names and blurbs in `Config/Jobs.luau`, with no logic changes.
- **Minor review items accepted:** next-goal text refreshes only on the next state push. Cooldown display uses
  client time since the last push (±1 s).
- **Tooling gaps:** no Luau type checker (luau-lsp couldn't be installed under the environment policy) and no
  selene lint (its Roblox std download is blocked). The compile check and reflection smoke test cover the most
  common runtime errors instead.
