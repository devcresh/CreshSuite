# CreshChat v0.2 — Final UI and Settings Audit

## Settings coverage added

- Default composer destination.
- Start with the social roster collapsed.
- Chat and Combat history limits.
- Optional console build badge.
- Notification card accent thickness.
- Compact-card width and height ratios.
- Dock whisper-preview width and duration.
- Manual Friends/Guild roster refresh.

Legacy migration-only fields and disabled prototype features were intentionally not exposed.

## Layout corrections

- Main-header controls now re-anchor based on visibility.
- Hidden Whisper/Friend/Party/Voice buttons no longer consume header width.
- Title and subtitle are constrained between the logo and the leftmost visible control.
- The build badge hides automatically when there is insufficient width.
- Existing screen clamping and safe scaling remain active for the console, settings, Games drawer, pop-outs, cards, composer, Combat panel and game windows.

## Validation target sizes

The static layout checks cover the addon minimum console width, minimum settings size and common 16:9/16:10 screen bounds. WoW must still be used for final pixel-level visual confirmation because FontString metrics and protected frames are client-rendered.
