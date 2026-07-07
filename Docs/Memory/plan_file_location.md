---
name: plan-file-location
description: Where to save plan-mode plan files for CreshSuite work
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a1883b5b-bd94-421c-8ae0-042bc5ccf28f
---

Save all plan-mode plan files into `D:\CreshSuite\Docs\Plans\` (moved here
from the original top-level `D:\CreshSuite\Plans\` by the user), not the
default `C:\Users\casey\.claude\plans\` location. Never leave any file or
folder outside `D:\CreshSuite` at all — the user explicitly said not to
save folders outside of it.

**Use the harness's own auto-generated filename, do not rename it.** Each
plan-mode session gets a random-slug file (e.g. `shimmering-fluttering-river.md`)
at the default external path — copy it into `D:\CreshSuite\Docs\Plans\`
under that *exact same filename*, not a descriptive rename. The user
corrected this once (rejected a `phase3-suite-notifications.md` copy,
asking specifically to move/use `shimmering-fluttering-river.md` as-is).
Existing older entries in that folder (`phase1-creshsuiteui-foundation.md`
etc.) predate this correction and were fine at the time, but the current
standing instruction is: keep the harness's slug name.

**Why:** User wants plans to live inside the repo's own Docs folder
alongside its existing documentation, not scattered in the global Claude
Code plans directory or any other location outside the project, and wants
the file identity kept simple/consistent with what the harness already
generated rather than re-labeled.

**How to apply:** Any time `EnterPlanMode`/`ExitPlanMode` is used in the
`D:\CreshSuite` project, copy the harness's plan file (same slug filename)
into `D:\CreshSuite\Docs\Plans\` before calling `ExitPlanMode`, and don't
leave stray plan folders anywhere else outside the repo.
