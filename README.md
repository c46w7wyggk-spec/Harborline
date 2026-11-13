# Harborline

An original, stylized open-world driving and "hustle" sandbox for Roblox: one compact harbor district, three
replayable 1–4 minute jobs (Courier Run, Harbor Sprint, Vault Job), and long-term goals through cars and a noodle
business. Server-authoritative economy, session-locked saves, no monetization.

**Status:** private-beta candidate. See [docs/BETA_STATUS.md](docs/BETA_STATUS.md) for what is verified and what still needs Roblox Studio.

| Doc | What it covers |
|---|---|
| [docs/BETA_HANDOFF.md](docs/BETA_HANDOFF.md) | Setup, controls, Studio steps, manual test script, data setup, inviting testers, release checklist |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Plan, module boundaries, data contracts, decisions, risks |
| [docs/ECONOMY.md](docs/ECONOMY.md) | Reward pacing, progression, abuse cases |
| [docs/COMPLIANCE.md](docs/COMPLIANCE.md) | Roblox policy research, questionnaire guidance, test matrix |
| [docs/FEEDBACK.md](docs/FEEDBACK.md) | Tester questions and beta success signals |
| [docs/PROGRESS.md](docs/PROGRESS.md) | Decisions, commands, test results, failures |
| [docs/QA_REVIEW.md](docs/QA_REVIEW.md) | Independent review findings |

```bash
cargo install --locked rojo stylua lune   # one-time
./scripts/check.sh                        # all automated checks + builds build/Harborline.rbxlx
rojo serve                                # live-sync into Studio (Rojo plugin)
```

Layout: `src/shared` → ReplicatedStorage.Shared (config + pure rules), `src/server` → ServerScriptService.Server,
`src/client` → StarterPlayerScripts.Client, `tests/` → Lune tests.
