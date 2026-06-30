# Active Boss Remaster Roster

This pass targets the 20 active bosses referenced directly by `DungeonCrawlerContent.lua` under `Media/Games/DungeonDwellers/Bosses/`. The separate legacy/asset-set bosses under `Sets/04_Boss_Icons_Set_A` through `Sets/07_Boss_FullBody_Set_B` are not part of this active-roster pass.

## Batch 15 complete

Each boss has one 1024x1024 RGBA source master, one 256x256 portrait candidate and one 256x512 full-body candidate. Portrait and full-body exports share the same generated master.

- King Candlewick
- Gnarlfang Packlord
- Murkfin Tide King
- Zariss Coil Queen
- Grumbar Earthbreaker

Runtime candidates are under:

- `Batch15/RuntimeCandidate/Icons/`
- `Batch15/RuntimeCandidate/FullBody/`

Comparison sheets:

- `Batch15/Preview/Batch15_BossIcons_Existing_vs_Candidate.png`
- `Batch15/Preview/Batch15_BossFullBody_Existing_vs_Candidate.png`

## Batches 22 and 23 complete

- Akoru Soulkeeper
- Astralax Devourer
- Azarak Web Tyrant
- CATS Master Base
- Drowned Ancient
- Emperor Blackfuse
- Gorvak Unchained
- High Seer Skyrend
- Lord Coldgrave
- Nexus Lord Vaelrix

## Batch 24 partial

- Omega Reaver
- Xavros Felwhisper

## Remaining active bosses

1. Stormtalon Matriarch
2. Sunblade Grand Magister
3. ZLR Arena Overlord

## Runtime and review state

- Portrait contract: 256x256 uncompressed 32-bit RGBA TGA.
- Full-body contract: 256x512 uncompressed 32-bit RGBA TGA.
- Full-body exports preserve source proportions and fit inside a transparent 236x440 area; they are not horizontally stretched.
- Portraits are upper-body crops of the same masters with a thin rust-copper rim.
- Batches 15, 22, 23 and the completed Batch 24 assets are connected through the existing unchanged live paths.
- Offline visual review is complete for all generated bosses; in-game rendering has not been tested.
