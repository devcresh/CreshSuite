---
name: achievements-window-row-anchors
description: "Pre-existing row title/progress overlap bug in the standalone Achievements window, fixed during Phase 2"
metadata: 
  node_type: memory
  type: project
  originSessionId: a1883b5b-bd94-421c-8ae0-042bc5ccf28f
---

`addons/CreshCollect/Achievements.lua`'s standalone window (`BuildWindow`)
and drawer panel (`BuildDrawerPanel`) both render one row per achievement
with the same four-label layout (title, detail/description, progress
fraction, reward). The drawer's row correctly reserves 78px on the right for
both the title AND detail lines so neither runs into the progress number.
The standalone window only reserved 78px for the detail line — its title
line was anchored at only -8px from the row's right edge, letting long
titles (worst case: Class Mastery entries, whose title always appends
"· TIER n · Class Mastery") run straight into/over the progress fraction.
Fixed by matching the title's right anchor to -78, same as detail and same
as the drawer's version.

**Why this matters going forward:** the drawer and standalone window in
this file are two independent hand-built layouts sharing the same data and
filter logic ([[creshsuite_ui_service_phase1]] covers the Phase 1 shared
service, but achievement row *rendering* itself is still duplicated code,
not shared). When touching row layout/anchors in either builder, check the
other one for the same field — they can silently drift apart, and this one
had for an unknown amount of time before Class Mastery filtering (Phase 2)
made long titles common enough for a user to actually notice and report it.

**How to apply:** before considering a Phase 2-adjacent Achievements.lua
layout task done, diff the row-building blocks in `BuildWindow` and
`BuildDrawerPanel` side by side for anchor-offset parity.
