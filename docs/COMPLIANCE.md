> Source: policy research workstream (subagent), 2026-11-13, from live official Roblox docs. Re-verify before release; policies change.

# Policy & Platform Research: Crime-and-Driving City Sandbox (Private Beta)

Researched 2026-11-13 from live official pages (create.roblox.com/docs, about.roblox.com, devforum.roblox.com announcements) using WebSearch and WebFetch. Web access worked. Page text was read through a summarizing fetch tool, so short quotes are close but may be paraphrased. Re-check the exact wording on the source page before you rely on it legally. Claims marked **[prior knowledge]** were not confirmed on a live page.

## Key platform change to know first (2025–2026)

Roblox now has **account tiers**: **Roblox Kids** (5–8), **Roblox Select** (9–15, or self-declared 9+ users who have not done an age check), and **Roblox** (age-checked 16+). The maturity labels map onto these tiers. A game that skips the full questionnaire (it answers "No" to the first age-restricted-content question) gets a **"Content May Vary"** rating and releases **only to age-checked users 16+**. Reaching under-16 users needs a full questionnaire, a Minimal/Mild/Moderate rating, an age-verified creator with 2FA, a fee or a Plus/Premium subscription, and an evaluation (250 unique plays from highly engaged players within 60 days).
- https://create.roblox.com/docs/production/publishing/kids-and-select
- https://create.roblox.com/docs/production/publishing/publish-experiences-and-places
- https://create.roblox.com/docs/production/promotion/content-maturity

**What this means for us:** a 16+ audience is now the *easy default*, not something we have to earn. The "must NOT assume 16+" constraint now applies the other way round. If we ever want 13–15 players, we must design to **Mild or Moderate (9+)**, which is reachable with our current feature set (see below).

---

## (a) Compliance checklist and likely questionnaire answers

Questionnaire location: **Creator Dashboard → [game] → Publish settings → Content rating** (https://create.roblox.com/docs/production/promotion/content-maturity). Before you start it, the game needs a name, a description and a genre. It takes 15–60 minutes. Answer for the *most extreme content a player can encounter*. **Resubmit whenever an update changes an answer.** A game without ratings has its "playability restricted for all players." Inaccurate ratings can lead to moderation of the game or the account.

### Likely answers for THIS game (uncertainty flagged)

| Questionnaire area | Our content | Likely answer / effect | Confidence |
|---|---|---|---|
| First gate: age-restricted content? | None | "No" gives Content May Vary (16+ only). To reach 9–15, answer the full questionnaire instead. | High |
| Violence | No weapons, no NPC harm. Car collisions and ragdoll possible. | At most "mild: implied/unrealistic," occasional. That maps to **Minimal**. If vehicles can knock down players or NPCs with ragdoll, it may count as "repeated mild," which is **Mild**. | Medium |
| Blood/gore | None | None | High |
| Crime | Stylized fictional heist (grab a cash bag, drive to a drop-off). Police "heat" timer. | The IARC questionnaire asks about "realistic descriptions of crimes (e.g., robbery, kidnapping)". Our heist is stylized, with no techniques and no violence, so the answer is probably "no realistic depiction". **Not verified** how IARC treats a stylized robbery as a core loop. It could add a descriptor or raise the label to Moderate. Never include real-world techniques: "detailed descriptions of techniques that could be used in criminal offenses are not allowed." | **Low–Medium** |
| Fear | None | None | High |
| Gambling | None. **Do not add** casinos, slot-like reward spins or betting on races. | None. Note: even *unplayable* gambling imagery (a casino set) makes the game **13+ only**. | High |
| Language | Scripted text clean | None. Chat is platform-moderated and handled separately. | High |
| Controlled substances | None. **Avoid** bars, beer signs, "drug-run" deliveries and fantasy drugs. Tobacco and drug references are prohibited. Alcohol is allowed only at the strictest age tier. | None | High |
| Crude humor / romance | None | None | High |
| Purchases | No Robux, no dev products or passes | "No." In-game soft cash only. No cash-convertible rewards. | High |
| Misc: chat moderation | TextChatService | "Yes" (Roblox provides built-in moderation). | High |
| Misc: private servers / invite-only | Only if we enable private servers | "Yes" if private servers are enabled. | High |
| Misc: social hangout with private spaces | The business interior must not be a lockable private room | Avoid. "Social hangout with private spaces" requires **age-verified 18+**. | Medium |
| Misc: free-form user creation / media sharing | Not planned (business naming is text only) | Avoid. Both require 16+. | High |

**Expected result:** Minimal or Mild if the heist is treated as fictional and non-realistic; Moderate in the worst case. That is eligible for 9–15 (Select) and 16+, but the 9–15 path still requires the extra publishing requirements.

### Checklist
- [ ] Game has a name, description and genre. Questionnaire completed in full (not only the first gate), or the first gate answered with an informed choice that accepts 16+ only.
- [ ] Questionnaire re-checked whenever we add content that could change an answer (weapons, NPC knockdowns, casinos, alcohol).
- [ ] No weapons, blood, realistic injury or NPC violence. Vehicle impacts on characters stay unrealistic (no injury states). Source: https://create.roblox.com/docs/production/promotion/content-maturity
- [ ] Heist has no real-world methods (no lock-picking steps, no hacking tutorials, no realistic alarm-bypass instructions). The "bank" is fictional, with no real bank names or logos.
- [ ] No real-world brands, car makes or logos, and no real city or police insignia. Community Standards: "respect the intellectual property rights of others"; Roblox may proactively remove suspected infringing assets. https://about.roblox.com/community-standards
- [ ] No Roblox name or logo misuse (https://en.help.roblox.com/hc/en-us/articles/115001708126).
- [ ] In-game cash is clearly fictional (stylized bills, no real currency symbols in a "$X = real money" sense). It is never tied to Robux, real money or off-platform rewards. "Roblox systems don't support or facilitate cash convertible rewards or NFTs." Community Standards forbid "misleading content or schemes" and "deceptive... content or metadata". UI must not imply players earn Robux or real money.
- [ ] No gambling, even simulated: "we prohibit both simulated and actual gambling activities". No random paid items. If free random rewards are added later, they must not involve anything of value bought with Robux.
- [ ] Chat uses TextChatService (Community Standards require TextChatService APIs for declaring text chat). No off-platform links anywhere in UI or signage.
- [ ] **All player-entered text is filtered**, for example a business or garage name or a license plate. Use `TextService:FilterStringAsync` + `GetNonChatStringForBroadcastAsync`, and **filter again when the stored name is read back from DataStore**. A game found without filtering "is removed until you add filtering." https://create.roblox.com/docs/ui/text-filtering
- [ ] No location features. No terrorism or extremist imagery in graffiti or decals.
- [ ] Creator account: age check done. It is needed for 16+ release *and* for collaborators to join Team Create (https://create.roblox.com/docs/projects/collaboration). Account at least 2 days old and in good standing. 2FA on, which is required for some group-role permissions.

---

## (b) Private beta access steps (as currently documented)

**Note:** two current official sources describe the access UI differently, so expect the UI to differ from either. The menu names below may not match exactly.

**1. Publish (stays private by default).** In Studio: **File → Publish** (older wording is "Publish to Roblox"). Fill in the name, genre and description, then **Save**. "New games are only accessible to you as the creator, users with Edit access" and group roles that allow it. https://create.roblox.com/docs/production/publishing/publish-experiences-and-places

**2a. Invite testers, user-owned game.** In Studio, click **Collaborate** (right side of the mezzanine bar), search for the user, choose **Play** ("permission to play the game privately") or **Edit**, then click **Save**. Edit can only go to Roblox friends. Play can go to any user or group. https://create.roblox.com/docs/projects/collaboration

**2b. Invite testers, group-owned game (recommended for a beta team).** Creator Dashboard → account switcher → select the group → **Roles**. Create a "Tester" role → **Permissions** tab → enable **Playtest experiences** ("can play all games owned by the group, even if they aren't released") → **Save**. Then go to **Members** → **+** to add testers to that role. **Do not** grant Edit, Publish or Data Stores permissions to testers. Data Stores View/Edit/Delete are separate role permissions. https://create.roblox.com/docs/en-us/projects/groups
The Dec 2025 Experience Betas post also names a default "Tester" role and the permission "Playtest all group experiences". https://devforum.roblox.com/t/a-new-way-to-test-before-launch-experience-betas/4144485

**2c. Early testers (Studio).** **File → Invite early testers**, up to **10** friends of a similar age or Trusted Friends. They see a preview watermark. Manage them via **Manage Collaborators**. The audience controls are at **Creator Dashboard → [game] → Publish settings → Manage Audience → Manage access**. The **Playtest tab** has "Early testers" (always on) and "Playtesters" (Edit or Playtest access). **Leave the Public tab off.** https://create.roblox.com/docs/production/publishing/publish-experiences-and-places

**3. Do NOT use "beta mode" for a private beta.** Experience Betas set Privacy to **Public** with "Enable beta mode", which keeps the game out of recommendations but leaves it *searchable and linkable*. That mode **requires the questionnaire**. Keep the game private and use invite-only roles instead. (The same devforum post.)

**4. Studio collaboration:** Team Create sessions require the owner's age check, and age rules may block some collaborators. Edit collaborators open the game via Creator Dashboard → hover the tile → **Edit in Studio**.

**5. Private servers:** **[prior knowledge]** enabled via Creator Dashboard → game → Monetization/Private Servers. Devforum reports say Play-access users have had trouble joining private servers on a private game (https://devforum.roblox.com/t/2474421). Not needed for a private beta, so skip them.

**6. Questionnaire before testers?** For a *private* game played only by Edit or Playtest users, docs do not explicitly require it. However, "If a game does not have content ratings, Roblox restricts the playability of the game ... for all players." **Recommendation: complete the questionnaire before inviting testers** to avoid surprise access blocks. (Unverified whether this blocks Playtest-role access.)

---

## (c) Data store and test-place separation

**Studio access:** **File → Experience Settings → Security → Enable Studio Access to API Services → Save**. Docs: "Accessing data stores in Studio can be dangerous for live games". Studio uses the *same* data stores as live servers. Enable it **only on a separate test copy**. https://create.roblox.com/docs/cloud-services/data-stores

**Separation plan:**
- Make two **separate experiences (universes)**: `Game-DEV` (Studio API access ON, used for Team Test) and `Game-BETA` (testers, Studio API access **OFF**). Data stores are scoped per experience, so this isolates the data. A separate *place* inside the same universe does **not** isolate data stores **[prior knowledge, standard platform behavior]**.
- Also prefix data store names with a version, e.g. `PlayerData_v1`, so schema changes can migrate cleanly.
- Use the `RunService:IsStudio()` guard in BindToClose. The official sample comments: "Avoid writing studio data to production and stalling test session closing". https://create.roblox.com/docs/reference/engine/classes/DataModel
- Delete test data when testing ends. Deleted stores can be restored for 30 days and count toward storage until purged. https://create.roblox.com/docs/cloud-services/data-stores/best-practices

**Limits** (https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits):
- Per-server budget per minute: Get/Set/Remove each 60 + 40×players. List 5 + 2×players. Ordered write 30 + 5×players. There is a startup burst.
- Experience-wide budget per minute: read 300 + 40×CCU, write 300 + 20×CCU.
- Value size is 4,194,304 characters (serialized JSON). Data store, key and scope names are 50 characters each. Metadata: 300 characters total.
- Per key: 25 MB/min read, 4 MB/min write. The queue holds 30 requests per type; beyond that you get errors 301–306.
- Storage = 500 MB + 1 MB × lifetime users.
- The current page lists no 6-second per-key write cooldown. That was older guidance **[prior knowledge]**, so still avoid rapid same-key writes.

**Practices** (best-practices page and https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing):
- [ ] **UpdateAsync** for player data. Use SetAsync only for new or independent values ("can cause inconsistency if two servers write at the same time").
- [ ] One key per player. Use a small fixed set of data stores. Cache in memory and save periodically, not on every cash change.
- [ ] **Session locking** (official pattern): store a `LockId` GUID in the **key metadata**, written atomically in the same UpdateAsync. Other servers abort if a lock is present and unexpired. Refresh the lock in the auto-save loop (sample interval **180 s**, with the first save randomly offset). The save interval must be shorter than the lock expiry. Release the lock on PlayerRemoving and BindToClose. Docs warn "you can't assume that data from one session is always saved before the next session starts" (rapid rejoin or teleport). MemoryStore is *not* the documented lock mechanism.
- [ ] **BindToClose**: "The experience server waits 30 seconds for all bound functions to stop running." Save all players **in parallel**.
- [ ] pcall plus exponential backoff with jitter. Cap the retries. Process retries in order per key, because a stale retry can overwrite newer data. Writes with an unknown outcome may have succeeded.
- [ ] Economy is server-authoritative: the server grants cash or rep only after it validates job completion (time, checkpoints, distance). The client never sends amounts.

---

## (d) Beta test matrix

Platforms: **PC** (keyboard and mouse), **Mobile** (low-end Android with 2–4 GB RAM as the baseline, plus one iPhone), **Console/Gamepad** (Xbox or PS, or a PC with a controller). **Studio** = Server & Clients (2–3 clients) + Device Simulator + Network Simulator. **Live** = the private BETA universe.

| # | Scenario | PC | Mobile | Console/Gamepad | Studio | Live | Pass criteria |
|---|---|---|---|---|---|---|---|
| 1 | First join → spawn → tutorial prompt | ✓ | ✓ | ✓ | ✓ | ✓ | On the low-end phone, join-to-control is ≤ ~10–15 s. Tutorial readable. No UI clipped by the notch or Roblox top bar. Every prompt works by touch and by gamepad. |
| 2 | Tutorial → first delivery job | ✓ | ✓ | ✓ | ✓ | ✓ | Job accepts, waypoint and timer visible, completes. Gamepad can navigate all menus (selection focus is visible). |
| 3 | Street race (checkpoints vs clock) | ✓ | ✓ | ✓ | ✓ | ✓ | Every checkpoint registers at high speed. Skipping a checkpoint does not finish the race. Time is computed on the server. |
| 4 | Heist (vault bag → drop-off, heat timer) | ✓ | ✓ | ✓ | ✓ | ✓ | Bag pickup, carry and drop-off work. Timer failure state is handled. Content contains no weapons or violence. |
| 5 | Reward → cash and rep update | ✓ | ✓ | ✓ | ✓ | ✓ | Correct amounts, granted once. HUD matches server value. |
| 6 | Spend: buy vehicle, buy and upgrade business | ✓ | ✓ | ✓ | ✓ | ✓ | Insufficient funds is rejected by the server. Purchase is atomic. Business name is text-filtered. |
| 7 | Leave → rejoin same server / new server | ✓ | ✓ | – | ✓ (API on, DEV only) | ✓ | Cash, rep, vehicles and business persist. No rollback. |
| 8 | Fast rejoin (< 5 s) and server hop | ✓ | ✓ | – | – | ✓ | Session lock holds: no duplication and no stale load. Player sees a "loading data" state instead of fresh data. |
| 9 | Server shutdown (Shut Down All Servers) mid-job | – | – | – | – | ✓ | Every player's data is saved within 30 s, as confirmed by data store logs or the Data Stores Manager. |
| 10 | Exploit: fire remotes with forged args (cash, job complete, teleport-to-checkpoint) | ✓ | – | – | ✓ (exploit-harness client script) | – | Server rejects them all. Rate limits on remotes. No cash change. |
| 11 | Exploit: speed or teleport through the race and drop-off | ✓ | – | – | ✓ | – | Server distance and time sanity checks fail the job. Bad actions are logged. |
| 12 | Exploit: claim the reward twice / spam the buy button | ✓ | ✓ | – | ✓ | ✓ | Debounced on the server. One purchase only. |
| 13 | Network sim: 4G preset and 3G "Bad Connection" | ✓ | – | – | ✓ (Network Simulator) | – | Jobs still complete. Vehicle control is acceptable. No double rewards on retries. |
| 14 | Real cellular / weak Wi-Fi | – | ✓ | – | – | ✓ | No desync on checkpoints. Graceful reconnect. |
| 15 | Device sim: small phone, tablet, 1080p, 4K TV | – | – | – | ✓ (Device Simulator) | – | UI uses Scale and text constraints. No overlap with thumbstick or jump. Text readable on a TV. |
| 16 | 10–15 min drive session (thermal and memory) | – | ✓ | ✓ | – | ✓ | No steady FPS decline. F9 Memory tab stable. No OS kill. StreamingEnabled with no visible holes at driving speed. |
| 17 | Data store budget under load (8+ players) | – | – | – | ✓ | ✓ | No 301–306 queue errors. Saves throttled to a sensible interval. |
| 18 | Text filter on business name (including rejoin readback) | ✓ | ✓ | ✓ | – (filtering is limited in Studio) | ✓ | Filtered text shows hashtags. It is re-filtered when loaded. |

**Tools and paths:**
- **Server & Clients** from the testing-mode dropdown (up to 8 clients, F7) (https://create.roblox.com/docs/studio/testing-modes).
- **Network Simulator** (beta): File → Beta Features → *New Device Simulator* → restart → **Test → Device Simulator** → **Network** pill → preset → **Apply**. Packet loss is capped at 0.5% and it works in Studio only (https://create.roblox.com/docs/studio/network-simulator).
- On-device checks: F9 Developer Console, MicroProfiler (Ctrl+Alt+F6), and the Performance Stats overlay (https://create.roblox.com/docs/performance-optimization/test-on-hardware).

**Streaming guidance** (https://create.roblox.com/docs/workspace/streaming):
- StreamingEnabled is the default for new places.
- `ModelStreamingMode` options: Nonatomic (default), Atomic, Persistent ("intended for very rare circumstances"), PersistentPerPlayer.
- Recommended: `StreamingIntegrityMode = PauseOutsideLoadedArea` and `StreamOutBehavior = Opportunistic`. Keep MinRadius at 64 and TargetRadius at 1024 (the defaults).
- Client scripts must WaitForChild on Atomic models. For Persistent models, wait for `PersistentLoaded`.
- For drop-offs or checkpoints far away, use `Player:RequestStreamAroundAsync` before a teleport or when a waypoint is set.

**Cross-platform UI** (https://create.roblox.com/docs/projects/cross-platform, https://create.roblox.com/docs/en-us/production/publishing/adaptive-design.md):
- Use Scale-based sizing. Controls must not be "blocked or obscured" by device cutouts or Roblox UI.
- Move less-important buttons into a menu on small screens. Every action must work by touch.
- Show gamepad glyph hints. Constrain sizes for 4K TVs.

---

## (e) Could not verify / open questions

1. **Exact IARC treatment of a stylized robbery as a core loop.** The questionnaire asks about "realistic descriptions of crimes (e.g., robbery...)". A stylized heist with no violence probably adds nothing, but it is not confirmed. Mitigation: if we want to stay safely Minimal or Mild, rename it to something softer (e.g., "Vault Run" or "Cash Courier"). It may come out Moderate (still OK for 9–15 Select and 16+).
2. **No official numeric touch-target minimum** in current Roblox docs. The cross-platform, adaptive-design and mobile-input pages give no pixel or dp size. Use the industry norm of ≥44–48 dp (Apple 44 pt, Android 48 dp) **[prior knowledge, not Roblox policy]**. The `GuiService` safe-area insets API (`GetGuiInset` / `ScreenInsets`) is also **[prior knowledge]**.
3. **Two access UIs documented:** "Manage Audience / Playtest tab / Early testers" (publish docs) versus "Settings → Privacy → beta mode" (Dec 2025 devforum). Check which one the live Creator Dashboard shows.
4. **Whether an unrated *private* game blocks Playtest-role testers.** Not stated anywhere. Complete the questionnaire up front to be safe.
5. **No specific policy on "fake money" imagery** beyond the bans on cash-convertible rewards, Robux trading off-platform, misleading content and gambling. A fictional cash HUD is common and appears allowed **[inference]**.
6. **Session lock expiry duration:** the official sample page gives none, only "shorter than lock expiry" with a 180 s autosave. Choose ~5–10 minutes **[inference]**.
7. **Private-server menu path** and its interaction with Play-access testers: from **[prior knowledge]** and a devforum report only.
8. **The questionnaire's exact question wording** was not viewable without a logged-in Creator Dashboard. Answers in (a) are mapped from the documented descriptor categories, not the live form.
9. Age checks for **creators** are expanding to Studio collaboration (Jan 2026 newsroom: https://about.roblox.com/newsroom/2026/01/roblox-age-checks-required-to-chat). All beta collaborators should finish an age check early. Chat between users is age-grouped (under 9, 9–12, 13–15, 16+…), which limits who can chat in our servers by default.
