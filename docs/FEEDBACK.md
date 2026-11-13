# Harborline Private Beta — Tester Feedback Form

Copy these into a Google Form (or ask in a call). ~5 minutes. Scales are 1 (bad) – 5 (great).

**About your session**
1. Device: PC / Mac / phone / tablet / console. Input: keyboard+mouse / touch / controller.
2. Roughly how long did you play? (<10 min / 10–30 / 30–60 / 60+)

**First minute**
3. Within the first minute, did you know what to do? (Yes / Sort of / No) — What confused you?
4. Did the tutorial card and light beam help? (1–5)

**Jobs**
5. Which jobs did you finish? (Courier Run / Harbor Sprint / Vault Job / none)
6. Fun rating per job (1–5 each). Which one would you replay first, and why?
7. Was any job too long, too short, unclear, or frustrating?

**Money and goals**
8. Did rewards feel fair for the effort? (Too low / About right / Too high)
9. What did you buy first? How long did it take to afford?
10. What did you want to buy *next*? Did you feel there was a long-term goal worth chasing?

**Driving and controls**
11. Driving feel (1–5). Too fast / too slow / too twitchy / too floaty?
12. Mobile/controller only: could you reach and tap everything easily? Anything too small or overlapping?

**Performance**
13. Any lag, stutter, long loading, overheating, or crashes? When?

**Saves and bugs**
14. When you rejoined, was all your progress there? (Yes / No — what was missing?)
15. Any bugs? What were you doing just before?

**Overall**
16. Would you play again tomorrow? (Definitely / Maybe / No)
17. One thing to change before more people play?

---

## Beta success signals (owner tracks these)

| Signal | Target | How to measure |
|---|---|---|
| First job completed | ≥ 80% of testers in first session | Q5 + `[Payout]` lines in server logs |
| Time to first job payout | ≤ 3 min median | Tester notes / observation |
| Time to first purchase (Noodle Cart) | ≤ 10 min median | Q9 |
| Repeat-session intent | ≥ 60% "Definitely" or "Maybe" | Q16 |
| Save reliability | 0 lost-progress reports; 0 `[Data] lock-lost`; `save-error` < 1% of saves | Q14 + logs |
| Mobile performance | No "unplayable" reports; steady frame rate on a mid-range phone | Q13, Studio MicroProfiler on device |
| Exploit/abuse | 0 unexplained cash spikes; `[Anticheat]` flags reviewed | Logs |
