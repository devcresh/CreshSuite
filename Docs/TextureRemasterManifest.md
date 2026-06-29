# CreshChat Dungeon Dwellers Texture Remaster Manifest

Audit baseline: Git `cf6b19f` on branch `fix/chat-capture-fallback-notice`, before Batch 01 candidates were added. This is a Dungeon Dwellers-only audit. The repository's 50 class armour skins are explicitly excluded: all 100 icon/full-body textures under `Media/Games/DungeonDwellers/ClassArmor/**` and `Media/Games/DungeonDwellers/ArmourSets/**`.

## A. Summary

| Finding | Count | Notes |
|---|---:|---|
| Total Dungeon Dwellers texture files | 292 | Entire library before exclusions |
| Excluded class-skin texture files | 100 | 50 icon/full-body pairs under `ClassArmor` and `ArmourSets` |
| Total in-scope texture files | 192 | All are TGA runtime assets |
| Code-referenced in-scope textures | 192 | 84 manifest paths, 99 `DungeonCrawlerContent` root-relative paths, and 9 dynamic dice paths |
| Missing texture references | 0 | Every in-scope static/dynamic path resolves |
| Apparently unused textures | 0 | Every in-scope file is reachable through loaded content tables or dynamic dice lookup |
| Duplicate or near-duplicate files | 0 within scope | One in-scope Satyr icon is byte-identical to one excluded Warlock class-skin icon; the Satyr image visually fits its in-scope role |
| Placeholder textures | 0 in scope | The 20 explicit Druid/Shaman placeholders are class skins and therefore excluded |
| Textures needing urgent replacement | 1 | `Dice_Web.tga` is a flat pixel/web tile that conflicts with Dice_1-Dice_8 and the painted library |
| Textures recommended to remain unchanged | 168 | Character, enemy, boss and display art with coherent roles/aspects |

### Missing or broken references

None. `DungeonDwellersAssetSets.lua`, `DungeonCrawlerContent.lua`, and the `DUNGEON_DICE_ROOT` constructor in `SoloGames.lua` collectively address every in-scope texture. The built-in question-mark icon is only a nil-path fallback and is outside this repository.

### Unused and duplicate findings

- No in-scope file appears unused.
- No two in-scope files share the same bytes or decoded-pixel signature.
- `Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_SatyrFelwhisper_XavrostheTwisted.tga` is byte-for-byte identical to the excluded `ClassArmor/Icons/Warlock/ClassArmor_Warlock_L100_LordoftheBurningRift.tga` (SHA-256 `6C1D5B7D4ADD6FF6F43FFD95C1CB831766A78473EC217D519834D4D82B3E5081`). Visual inspection shows a Satyr, so the in-scope file is likely correct and the excluded class-skin copy is likely wrong. This is an inference, not a live-game proof.

### Visual and technical findings

- Dimensions: 95 at 128x128, 68 at 256x512, 24 at 256x256, and 5 at 512x512. Every dimension is power-of-two.
- Alpha: all 192 files carry 32-bit RGBA channels; 147 contain visible transparency and 45 are fully opaque.
- Format: all 192 decode as uncompressed TGA. No PNG, BLP, JPEG, WebP or atlas is used by this runtime family.
- Cropping/stretch: the Dungeon renderer uses `SetAllPoints` and no Dungeon texture coordinates. Square icons remain square; full-body 1:2 art is shown in 110x160 or 110x196 holders, causing modest aspect compression for player bodies and modest expansion for enemy bodies. Existing art is composed to tolerate those holders, but future layout integration must re-check proportions.
- Tint/desaturation: most artwork is reset to white vertex colour. The foe die is tinted `(1.00, 0.82, 0.82)`, locked collection art can be desaturated and vertex-coloured to 50%, and defeated enemies are desaturated. Batch 01 reward icons otherwise require fixed colours.
- Opacity layers: the renderer duplicates several texture regions one or two times in `BLEND` mode to strengthen translucent art. Opaque reward icons are unaffected visually, but alpha-edge candidates must be tested in this stacked renderer.
- Visual consistency: the core player/minion/boss sets deliberately use a compact pixel-painted style; expansion enemies, milestone bosses, crates and rewards are higher-detail painted art. Preserve each family instead of forcing the whole library into one rendering style.

## B. Texture table

`Format` includes alpha-channel presence and file size. “Code-referenced” means reachable by the loaded Lua tables; WoW still decodes images on demand when `SetTexture` reaches them.

| Priority | Texture path | Dimensions | Format | Used by | Status | Recommended action |
|---|---|---:|---|---|---|---|
| P0 | `Media/Games/DungeonDwellers/Dice/Dice_Web.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | SoloGames player/foe dice; 28x28 visible area; foe variant vertex-tinted | Replace | Remaster with the full dice family; current flat web tile conflicts with Dice_1-Dice_8 |
| P0 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_SatyrFelwhisper_XavrostheTwisted.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Possible duplicate | Keep this Satyr art; it exactly matches an excluded Warlock class-skin icon that likely needs correction |
| P1 | `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_ArmourChoiceToken.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent rewards; SoloGames 36x36 reward card and collection icon | Remaster | Batch 01 candidate prepared as CreshChat_DungeonReward_ArmourChoiceToken_128.tga |
| P1 | `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_CreshCoinCache.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent rewards; SoloGames 36x36 reward card and collection icon | Remaster | Batch 01 candidate prepared as CreshChat_DungeonReward_CreshCoinCache_128.tga |
| P1 | `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_DamageRelic.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent rewards; SoloGames 36x36 reward card and collection icon | Remaster | Batch 01 candidate prepared as CreshChat_DungeonReward_DamageRelic_128.tga |
| P1 | `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_FullBodyToken.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent rewards; SoloGames 36x36 reward card and collection icon | Remaster | Batch 01 candidate prepared as CreshChat_DungeonReward_FullBodyToken_128.tga |
| P1 | `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_PortraitToken.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent rewards; SoloGames 36x36 reward card and collection icon | Remaster | Batch 01 candidate prepared as CreshChat_DungeonReward_PortraitToken_128.tga |
| P2 | `Media/Games/DungeonDwellers/Dice/Dice_1.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | SoloGames player/foe dice; 28x28 visible area; foe variant vertex-tinted | Remaster | Remaster as one coherent dice family before any live integration |
| P2 | `Media/Games/DungeonDwellers/Dice/Dice_2.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | SoloGames player/foe dice; 28x28 visible area; foe variant vertex-tinted | Remaster | Remaster as one coherent dice family before any live integration |
| P2 | `Media/Games/DungeonDwellers/Dice/Dice_3.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | SoloGames player/foe dice; 28x28 visible area; foe variant vertex-tinted | Remaster | Remaster as one coherent dice family before any live integration |
| P2 | `Media/Games/DungeonDwellers/Dice/Dice_4.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | SoloGames player/foe dice; 28x28 visible area; foe variant vertex-tinted | Remaster | Remaster as one coherent dice family before any live integration |
| P2 | `Media/Games/DungeonDwellers/Dice/Dice_5.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | SoloGames player/foe dice; 28x28 visible area; foe variant vertex-tinted | Remaster | Remaster as one coherent dice family before any live integration |
| P2 | `Media/Games/DungeonDwellers/Dice/Dice_6.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | SoloGames player/foe dice; 28x28 visible area; foe variant vertex-tinted | Remaster | Remaster as one coherent dice family before any live integration |
| P2 | `Media/Games/DungeonDwellers/Dice/Dice_7.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | SoloGames player/foe dice; 28x28 visible area; foe variant vertex-tinted | Remaster | Remaster as one coherent dice family before any live integration |
| P2 | `Media/Games/DungeonDwellers/Dice/Dice_8.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | SoloGames player/foe dice; 28x28 visible area; foe variant vertex-tinted | Remaster | Remaster as one coherent dice family before any live integration |
| P3 | `Media/Games/DungeonDwellers/Chests/Icons/Chest_L100_Level100MilestoneChest.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent milestone chest; SoloGames 40x40 badge and collection icon | Needs manual review | Consider a simplified small-icon companion to the existing display art |
| P3 | `Media/Games/DungeonDwellers/Chests/Icons/Chest_L20_Level20MilestoneChest.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent milestone chest; SoloGames 40x40 badge and collection icon | Needs manual review | Consider a simplified small-icon companion to the existing display art |
| P3 | `Media/Games/DungeonDwellers/Chests/Icons/Chest_L40_Level40MilestoneChest.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent milestone chest; SoloGames 40x40 badge and collection icon | Needs manual review | Consider a simplified small-icon companion to the existing display art |
| P3 | `Media/Games/DungeonDwellers/Chests/Icons/Chest_L60_Level60MilestoneChest.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent milestone chest; SoloGames 40x40 badge and collection icon | Needs manual review | Consider a simplified small-icon companion to the existing display art |
| P3 | `Media/Games/DungeonDwellers/Chests/Icons/Chest_L80_Level80MilestoneChest.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent milestone chest; SoloGames 40x40 badge and collection icon | Needs manual review | Consider a simplified small-icon companion to the existing display art |
| P3 | `Media/Games/DungeonDwellers/Crates/AdventurersCache.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent crate; SoloGames crate popup 152x154 art / 40x40 badge | Remaster | Future faction-neutral crate pass; preserve 256x256 transparent contract |
| P3 | `Media/Games/DungeonDwellers/Crates/RoyalVanguardChest.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent crate; SoloGames crate popup 152x154 art / 40x40 badge | Remaster | Future faction-neutral crate pass; preserve 256x256 transparent contract |
| P3 | `Media/Games/DungeonDwellers/Crates/VoidlordReliquary.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent crate; SoloGames crate popup 152x154 art / 40x40 badge | Remaster | Future faction-neutral crate pass; preserve 256x256 transparent contract |
| P3 | `Media/Games/DungeonDwellers/Crates/WarboundStrongbox.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent crate; SoloGames crate popup 152x154 art / 40x40 badge | Remaster | Future faction-neutral crate pass; preserve 256x256 transparent contract |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/AkoruSoulkeeper.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/AstralaxDevourer.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/AzarakWebTyrant.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/CATSMasterBase.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/DrownedAncient.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/EmperorBlackfuse.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/GnarlfangPacklord.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/GorvakUnchained.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/GrumbarEarthbreaker.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/HighSeerSkyrend.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/KingCandlewick.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/LordColdgrave.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/MurkfinTideKing.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/NexusLordVaelrix.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/OmegaReaver.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/StormtalonMatriarch.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/SunbladeGrandMagister.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/XavrosFelwhisper.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/ZarissCoilQueen.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/FullBody/ZLRArenaOverlord.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent milestone boss; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/AkoruSoulkeeper.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/AstralaxDevourer.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/AzarakWebTyrant.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/CATSMasterBase.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/DrownedAncient.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/EmperorBlackfuse.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/GnarlfangPacklord.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/GorvakUnchained.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/GrumbarEarthbreaker.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/HighSeerSkyrend.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/KingCandlewick.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/LordColdgrave.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/MurkfinTideKing.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/NexusLordVaelrix.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/OmegaReaver.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/StormtalonMatriarch.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/SunbladeGrandMagister.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/XavrosFelwhisper.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/ZarissCoilQueen.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Bosses/Icons/ZLRArenaOverlord.tga` | 256x256 | TGA 32-bit RGBA, uncompressed, 262,188 B | DungeonCrawlerContent milestone boss; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Chests/Display/Chest_L100_Level100MilestoneChest.tga` | 512x512 | TGA 32-bit RGBA, uncompressed, 1,048,620 B | DungeonCrawlerContent milestone chest; SoloGames crate popup 152x154 art | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Chests/Display/Chest_L20_Level20MilestoneChest.tga` | 512x512 | TGA 32-bit RGBA, uncompressed, 1,048,620 B | DungeonCrawlerContent milestone chest; SoloGames crate popup 152x154 art | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Chests/Display/Chest_L40_Level40MilestoneChest.tga` | 512x512 | TGA 32-bit RGBA, uncompressed, 1,048,620 B | DungeonCrawlerContent milestone chest; SoloGames crate popup 152x154 art | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Chests/Display/Chest_L60_Level60MilestoneChest.tga` | 512x512 | TGA 32-bit RGBA, uncompressed, 1,048,620 B | DungeonCrawlerContent milestone chest; SoloGames crate popup 152x154 art | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Chests/Display/Chest_L80_Level80MilestoneChest.tga` | 512x512 | TGA 32-bit RGBA, uncompressed, 1,048,620 B | DungeonCrawlerContent milestone chest; SoloGames crate popup 152x154 art | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/01_Player_Portraits_Classic/Portraits/DwarfDefender.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames hero/class portrait at 43-50 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/01_Player_Portraits_Classic/Portraits/ElfRanger.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames hero/class portrait at 43-50 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/01_Player_Portraits_Classic/Portraits/HumanMage.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames hero/class portrait at 43-50 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/01_Player_Portraits_Classic/Portraits/HumanPaladin.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames hero/class portrait at 43-50 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/01_Player_Portraits_Classic/Portraits/HumanPriest.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames hero/class portrait at 43-50 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/01_Player_Portraits_Classic/Portraits/OrcWarrior.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames hero/class portrait at 43-50 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/01_Player_Portraits_Classic/Portraits/UndeadRogue.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames hero/class portrait at 43-50 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/01_Player_Portraits_Classic/Portraits/VoidWarlock.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames hero/class portrait at 43-50 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/02_Player_FullBody_Classic/FullBody/DwarfDefender.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames 110x160 hero body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/02_Player_FullBody_Classic/FullBody/ElfRanger.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames 110x160 hero body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/02_Player_FullBody_Classic/FullBody/HumanMage.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames 110x160 hero body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/02_Player_FullBody_Classic/FullBody/HumanPaladin.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames 110x160 hero body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/02_Player_FullBody_Classic/FullBody/HumanPriest.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames 110x160 hero body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/02_Player_FullBody_Classic/FullBody/OrcWarrior.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames 110x160 hero body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/02_Player_FullBody_Classic/FullBody/UndeadRogue.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames 110x160 hero body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/02_Player_FullBody_Classic/FullBody/VoidWarlock.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames 110x160 hero body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Bat/Bat_Black_01.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Bat/Bat_Blue_03.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Bat/Bat_Brown_02.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Bat/Bat_Violet_04.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Cultist/Cultist_Black_03.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Cultist/Cultist_Horned_04.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Cultist/Cultist_Purple_01.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Cultist/Cultist_Red_02.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Demon/Demon_Blue_03.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Demon/Demon_Blue_Armored_04.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Demon/Demon_Purple_02.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Demon/Demon_Red_01.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Goblin/Goblin_Guard_02.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Goblin/Goblin_Hood_03.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Goblin/Goblin_Raider_01.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Imp/Imp_Blue_03.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Imp/Imp_Purple_02.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Imp/Imp_Red_01.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Skeleton/Skeleton_Armored_02.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Skeleton/Skeleton_Bare_01.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Slime/Slime_Green_01.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Slime/Slime_Yellow_02.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Spider/Spider_Brown_02.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Spider/Spider_Night_03.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Spider/Spider_Shadow_01.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Wolf/Wolf_Dark_02.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Wolf/Wolf_Grey_01.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Wolf/Wolf_White_03.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames minion offer/party icon at 38-43 px | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/04_Boss_Icons_Set_A/Icons/DarkPaladin.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/04_Boss_Icons_Set_A/Icons/DemonWarlord.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/04_Boss_Icons_Set_A/Icons/FireMageBoss.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/04_Boss_Icons_Set_A/Icons/IceQueen.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/04_Boss_Icons_Set_A/Icons/LichLord.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/04_Boss_Icons_Set_A/Icons/OrcChampion.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/04_Boss_Icons_Set_A/Icons/SkeletonKing.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/04_Boss_Icons_Set_A/Icons/SpiderMatriarch.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/04_Boss_Icons_Set_A/Icons/TrollWitchDoctor.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/04_Boss_Icons_Set_A/Icons/VoidPriest.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/05_Boss_FullBody_Set_A/FullBody/DarkPaladin.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/05_Boss_FullBody_Set_A/FullBody/DemonWarlord.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/05_Boss_FullBody_Set_A/FullBody/FireMageBoss.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/05_Boss_FullBody_Set_A/FullBody/IceQueen.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/05_Boss_FullBody_Set_A/FullBody/LichLord.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/05_Boss_FullBody_Set_A/FullBody/OrcChampion.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/05_Boss_FullBody_Set_A/FullBody/SkeletonKing.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/05_Boss_FullBody_Set_A/FullBody/SpiderMatriarch.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/05_Boss_FullBody_Set_A/FullBody/TrollWitchDoctor.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/05_Boss_FullBody_Set_A/FullBody/VoidPriest.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/06_Boss_Icons_Set_B/Icons/BatLord.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/06_Boss_Icons_Set_B/Icons/CultMaster.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/06_Boss_Icons_Set_B/Icons/DragonkinBoss.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/06_Boss_Icons_Set_B/Icons/FelKnight.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/06_Boss_Icons_Set_B/Icons/GoblinMechBoss.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/06_Boss_Icons_Set_B/Icons/Necromancer.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/06_Boss_Icons_Set_B/Icons/ShadowAssassin.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/06_Boss_Icons_Set_B/Icons/SlimeTyrant.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/06_Boss_Icons_Set_B/Icons/StoneGolem.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/06_Boss_Icons_Set_B/Icons/WolfAlpha.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonDwellersAssetSets; SoloGames boss enemy icon at 50x50 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/07_Boss_FullBody_Set_B/FullBody/BatLord.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/07_Boss_FullBody_Set_B/FullBody/CultMaster.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/07_Boss_FullBody_Set_B/FullBody/DragonkinBoss.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/07_Boss_FullBody_Set_B/FullBody/FelKnight.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/07_Boss_FullBody_Set_B/FullBody/GoblinMechBoss.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/07_Boss_FullBody_Set_B/FullBody/Necromancer.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/07_Boss_FullBody_Set_B/FullBody/ShadowAssassin.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/07_Boss_FullBody_Set_B/FullBody/SlimeTyrant.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/07_Boss_FullBody_Set_B/FullBody/StoneGolem.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/07_Boss_FullBody_Set_B/FullBody/WolfAlpha.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonDwellersAssetSets; SoloGames boss enemy body at 110x196 | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_ArakkoaWindseer_SkyrendProphet.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_ArenaGladiator_ZLRBloodChampion.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_BloodElfSpellbreaker_SunbladeDisruptor.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_BogBeast_MarshrootAncient.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_BrokenSoulbinder_AkorutheForsaken.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_ClockworkReaver_GeargrindPrototype.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_DarkIronBombardier_FusebeardDemolitionist.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_EtherealPhaseblade_NexusCutthroat.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_FelOrcBerserker_HellfireBloodhowler.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_FrostRevenant_ColdgraveWatcher.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_GnollBrute_RedtoothMauler.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_HarpyStormtalon_ScreechwingTempest.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_KoboldMiner_CandlewickTunnelRat.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_ManaWyrm_ArcaneGlimmermaw.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_MurlocTidecaller_GlubfintheLoud.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_NagaSiren_CoilscaleEnchantress.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_NerubianWebwarden_CryptwebBinder.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_TroggEarthshaker_Grumblefist.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_ZeroWingDrone_CATSAssaultUnit.tga` | 128x128 | TGA 32-bit RGBA, uncompressed, 65,580 B | DungeonCrawlerContent expansion enemy; SoloGames 50x50 enemy icon | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_ArakkoaWindseer_SkyrendProphet.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_ArenaGladiator_ZLRBloodChampion.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_BloodElfSpellbreaker_SunbladeDisruptor.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_BogBeast_MarshrootAncient.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_BrokenSoulbinder_AkorutheForsaken.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_ClockworkReaver_GeargrindPrototype.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_DarkIronBombardier_FusebeardDemolitionist.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_EtherealPhaseblade_NexusCutthroat.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_FelOrcBerserker_HellfireBloodhowler.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_FrostRevenant_ColdgraveWatcher.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_GnollBrute_RedtoothMauler.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_HarpyStormtalon_ScreechwingTempest.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_KoboldMiner_CandlewickTunnelRat.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_ManaWyrm_ArcaneGlimmermaw.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_MurlocTidecaller_GlubfintheLoud.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_NagaSiren_CoilscaleEnchantress.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_NerubianWebwarden_CryptwebBinder.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_SatyrFelwhisper_XavrostheTwisted.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_TroggEarthshaker_Grumblefist.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |
| P4 | `Media/Games/DungeonDwellers/Sets/09_Enemy_FullBody_Expansion_01/FullBody/Enemy_ZeroWingDrone_CATSAssaultUnit.tga` | 256x512 | TGA 32-bit RGBA, uncompressed, 524,332 B | DungeonCrawlerContent expansion enemy; SoloGames 110x196 enemy body | Keep | Retain unchanged; role, aspect and module style are coherent |

## C. Asset categories

| Category | Files | Current role | Direction |
|---|---:|---|---|
| Core player portraits | 8 | Class selection and hero portrait | Keep; deliberately compact pixel-painted set |
| Core player full-body | 8 | Hero body plate | Keep; avoid portrait/full-body work in early batches |
| Minion portraits | 28 | Recruit offers, party cards and collection | Keep; coherent family with readable silhouettes |
| Classic boss icons | 20 | Enemy/boss icon | Keep; paired with their full-body art |
| Classic boss full-body | 20 | Enemy body plate | Keep; complex character art is out of early-batch scope |
| Expansion enemy icons | 20 | Enemy icon | Keep; inspect the Satyr cross-scope duplicate separately |
| Expansion enemy full-body | 20 | Enemy body plate | Keep; cohesive high-detail set |
| Milestone boss icons | 20 | Boss icon | Keep; strong painted portraits |
| Milestone boss full-body | 20 | Boss body plate | Keep; complex content art |
| Milestone chests | 10 | Five large popup images plus five small badges | Keep display art; review small icon crops later |
| Crates | 4 | Large crate-popup art and fallback badge | Later original/faction-neutral pass |
| Dice | 9 | Constant player/foe combat rolls | Next production family; replace all coherently before integration |
| Reward icons | 5 | Crate choices and collection entries | Batch 01 |

No in-scope texture serves the main console, C button, navigation, settings, notifications, minimap, Battle Pass or Achievements. Those modules are outside this Dungeon Dwellers audit.

## D. Recommended production order

1. `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_CreshCoinCache.tga` — Frequent crate reward; current multi-object scene muddies at 36 px; low-risk opaque square.
2. `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_DamageRelic.tga` — Frequent permanent-damage reward; simplify its competing frame, embers and relic detail.
3. `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_PortraitToken.tga` — Frequent skin reward; clean cameo silhouette is safe and independent.
4. `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_FullBodyToken.tga` — Frequent skin reward; stronger full-figure contour improves 36 px readability.
5. `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_ArmourChoiceToken.tga` — Maps both SHARDS and ARMOUR; class-neutral breastplate is clearer than a tiny full suit.
6. `Media/Games/DungeonDwellers/Dice/Dice_Web.tga` — Most visually inconsistent in-scope asset; flat pixel web beside painted dice.
7. `Media/Games/DungeonDwellers/Dice/Dice_1.tga` — Constant combat visibility; simple and low-risk.
8. `Media/Games/DungeonDwellers/Dice/Dice_2.tga` — Constant combat visibility; simple and low-risk.
9. `Media/Games/DungeonDwellers/Dice/Dice_3.tga` — Constant combat visibility; simple and low-risk.
10. `Media/Games/DungeonDwellers/Dice/Dice_4.tga` — Constant combat visibility; simple and low-risk.
11. `Media/Games/DungeonDwellers/Dice/Dice_5.tga` — Constant combat visibility; simple and low-risk.
12. `Media/Games/DungeonDwellers/Dice/Dice_6.tga` — Constant combat visibility; simple and low-risk.
13. `Media/Games/DungeonDwellers/Dice/Dice_7.tga` — Constant combat visibility; simple and low-risk.
14. `Media/Games/DungeonDwellers/Dice/Dice_8.tga` — Constant combat visibility; simple and low-risk.
15. `Media/Games/DungeonDwellers/Crates/AdventurersCache.tga` — Large self-contained crate popup art; later faction-neutral silhouette pass.
16. `Media/Games/DungeonDwellers/Crates/RoyalVanguardChest.tga` — Large self-contained crate popup art; current heraldic motif should become original/faction-neutral.
17. `Media/Games/DungeonDwellers/Crates/VoidlordReliquary.tga` — Large self-contained crate popup art; strong candidate after small icons.
18. `Media/Games/DungeonDwellers/Crates/WarboundStrongbox.tga` — Large self-contained crate popup art; current heraldic motif should become original/faction-neutral.
19. `Media/Games/DungeonDwellers/Chests/Icons/Chest_L20_Level20MilestoneChest.tga` — Small milestone badge uses a dense crop of chest display art.
20. `Media/Games/DungeonDwellers/Chests/Icons/Chest_L40_Level40MilestoneChest.tga` — Small milestone badge uses a dense crop of chest display art.

## Runtime format assessment

- Successful local runtime format: 32-bit, uncompressed TGA. The in-scope Lua paths do not request PNG, BLP, JPEG or WebP.
- Power-of-two: every in-scope runtime asset uses power-of-two dimensions. Candidates preserve that established project contract.
- Alpha: required for 147 in-scope files. Batch 01 reward tiles are intentionally opaque but retain an RGBA channel like the originals.
- Coordinates: Dungeon artwork uses full texture coordinates; no `SetTexCoord` crop is applied in the Dungeon renderer.
- Tint: enemy dice and locked/defeated states are tinted or desaturated. Reward icons are fixed-colour art but must tolerate locked-state desaturation/50% vertex colour in the collection.
- Exact paths: `DungeonCrawlerContent.lua` constructs reward paths from the Dungeon root plus exact filenames. Candidate names intentionally differ and are not connected.
- Dimensions: the reward-card frame is 40x40 with a 2 px inset, producing a 36x36 visible icon. Existing and candidate runtime files remain 128x128 square.
- Conversion tooling: no image converter exists in this repository. The already-installed ImageMagick executable was inspected and used; no software was installed or downloaded.

## Batch 01 comparison entries

### Cresh Coin Cache

- Existing texture: `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_CreshCoinCache.tga`
- Existing dimensions: 128x128, opaque 32-bit uncompressed TGA
- Source candidate: `ArtSource/TextureRemaster/Batch01/Source/CreshChat_DungeonReward_CreshCoinCache_Master.png` (1254x1254 opaque PNG)
- Runtime candidate: `ArtSource/TextureRemaster/Batch01/RuntimeCandidate/CreshChat_DungeonReward_CreshCoinCache_128.tga` (128x128 opaque 32-bit uncompressed TGA)
- UI role: Boss-coin/cache reward on crate choices and collection rows.
- Expected improvement: A single pouch and three oversized coins replace the busy loose-coin scene.
- Risk: The cyan seal is new visual vocabulary and must not be mistaken for a gem reward.
- Required in-game test: Trigger or temporarily stage a COINS choice in an approved integration build; inspect 36 px reward card plus locked/unlocked collection states.
### Damage Relic

- Existing texture: `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_DamageRelic.tga`
- Existing dimensions: 128x128, opaque 32-bit uncompressed TGA
- Source candidate: `ArtSource/TextureRemaster/Batch01/Source/CreshChat_DungeonReward_DamageRelic_Master.png` (1254x1254 opaque PNG)
- Runtime candidate: `ArtSource/TextureRemaster/Batch01/RuntimeCandidate/CreshChat_DungeonReward_DamageRelic_128.tga` (128x128 opaque 32-bit uncompressed TGA)
- UI role: Permanent starting-damage reward.
- Expected improvement: One tall red crystal creates a cleaner damage silhouette.
- Risk: May read as a generic crystal unless the ember fissure survives client filtering.
- Required in-game test: Stage a DAMAGE choice; inspect at 0.70/1.00/1.50 UI scale and verify foe tint is not applied.
### Portrait Token

- Existing texture: `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_PortraitToken.tga`
- Existing dimensions: 128x128, opaque 32-bit uncompressed TGA
- Source candidate: `ArtSource/TextureRemaster/Batch01/Source/CreshChat_DungeonReward_PortraitToken_Master.png` (1254x1254 opaque PNG)
- Runtime candidate: `ArtSource/TextureRemaster/Batch01/RuntimeCandidate/CreshChat_DungeonReward_PortraitToken_128.tga` (128x128 opaque 32-bit uncompressed TGA)
- UI role: Portrait-skin token reward.
- Expected improvement: Simplified cameo profile reads faster than the current fine medallion portrait.
- Risk: Profile remains human-like and must stay class/race neutral.
- Required in-game test: Stage a PORTRAIT choice and collection row; verify unlocked, locked, desaturated and 50% vertex-colour states.
### Full-Body Token

- Existing texture: `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_FullBodyToken.tga`
- Existing dimensions: 128x128, opaque 32-bit uncompressed TGA
- Source candidate: `ArtSource/TextureRemaster/Batch01/Source/CreshChat_DungeonReward_FullBodyToken_Master.png` (1254x1254 opaque PNG)
- Runtime candidate: `ArtSource/TextureRemaster/Batch01/RuntimeCandidate/CreshChat_DungeonReward_FullBodyToken_128.tga` (128x128 opaque 32-bit uncompressed TGA)
- UI role: Full-body-skin token reward.
- Expected improvement: Larger full-length silhouette and brighter sapphire field improve tiny-size recognition.
- Risk: The ivory figure is high contrast and could bloom on bright displays.
- Required in-game test: Stage a FULLBODY choice and collection row; check figure separation and no white edge after TGA export.
### Armour Choice Token

- Existing texture: `Media/Games/DungeonDwellers/RewardIcons/Icons/RewardIcon_ArmourChoiceToken.tga`
- Existing dimensions: 128x128, opaque 32-bit uncompressed TGA
- Source candidate: `ArtSource/TextureRemaster/Batch01/Source/CreshChat_DungeonReward_ArmourChoiceToken_Master.png` (1254x1254 opaque PNG)
- Runtime candidate: `ArtSource/TextureRemaster/Batch01/RuntimeCandidate/CreshChat_DungeonReward_ArmourChoiceToken_128.tga` (128x128 opaque 32-bit uncompressed TGA)
- UI role: Armour/shard reward used by both SHARDS and ARMOUR keys.
- Expected improvement: Broad class-neutral breastplate is clearer than a miniature full suit and three gems.
- Risk: May communicate armour more strongly than 'choice'; tooltip text remains necessary.
- Required in-game test: Stage SHARDS and ARMOUR choices; verify both resolve to the same candidate and remain readable at 36 px.

The labelled contact sheet is `ArtSource/TextureRemaster/Batch01/Preview/Batch01_DungeonRewards_Existing_vs_Candidate.png`.

## Batch 02: canonical base portraits

Batch 02 starts the base class/minion/enemy pass while explicitly excluding class skins, armour skins, alternate colour variants and full-body art. All five candidates are original pixel-art concepts, remain disconnected from live Lua and use the established 128x128 uncompressed RGBA TGA contract.

| Existing texture | Candidate | UI role | Expected improvement | Risks | Required in-game test |
|---|---|---|---|---|---|
| `Media/Games/DungeonDwellers/Sets/01_Player_Portraits_Classic/Portraits/HumanPaladin.tga` | `ArtSource/TextureRemaster/Batch02/RuntimeCandidate/CreshChat_DungeonBaseClass_HumanPaladin.tga` | Base Human Paladin portrait | Stronger face, ivory/gold plate and blue collar read at 38-50 px while retaining chunky pixels. | New face proportions may feel more mature than the current base. | Inspect hero picker, combat portrait, lock/desaturation state and all UI scales. |
| `Media/Games/DungeonDwellers/Sets/01_Player_Portraits_Classic/Portraits/OrcWarrior.tga` | `ArtSource/TextureRemaster/Batch02/RuntimeCandidate/CreshChat_DungeonBaseClass_OrcWarrior.tga` | Base Orc Warrior portrait | Cleaner tusk/brow silhouette and stronger worn-iron material separation. | Dark beard may merge into the tile at low brightness. | Inspect hero picker and combat portrait at 38, 40 and 50 px. |
| `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Skeleton/Skeleton_Bare_01.tga` | `ArtSource/TextureRemaster/Batch02/RuntimeCandidate/CreshChat_DungeonBaseMinion_SkeletonBare.tga` | Canonical bare Skeleton minion | Removes incidental second figure and makes skull/rib cage immediately readable. | Thin ribs may lose definition under client filtering. | Inspect normal, selected, locked and desaturated minion states. |
| `Media/Games/DungeonDwellers/Sets/03_Minion_Portraits_Core/Slime/Slime_Green_01.tga` | `ArtSource/TextureRemaster/Batch02/RuntimeCandidate/CreshChat_DungeonBaseMinion_SlimeGreen.tga` | Canonical Green Slime minion | Simpler mound silhouette and brighter eyes improve recognition without adding a skin cue. | Green-on-black edge may be too dark on low-gamma displays. | Inspect at 38 px over every supported Dungeon panel/theme. |
| `Media/Games/DungeonDwellers/Sets/08_Enemy_Icons_Expansion_01/Icons/Enemy_KoboldMiner_CandlewickTunnelRat.tga` | `ArtSource/TextureRemaster/Batch02/RuntimeCandidate/CreshChat_DungeonBaseEnemy_KoboldMiner.tga` | Candlewick Tunnel Rat enemy icon | Candle, alert eye and miner silhouette read more cleanly in the encounter slot. | Candle flame is a small bright element and may bloom at high UI scale. | Inspect encounter, defeated/desaturated, tooltip and duplicate-BLEND-layer states. |

Comparison: `ArtSource/TextureRemaster/Batch02/Preview/Batch02_BasePortraits_Existing_vs_Candidate.png`.
Prompts and output contracts: `ArtSource/TextureRemaster/Batch02/GenerationPrompts.md`.

## Completed base portrait candidate scope

The controlled base pass continued through Batch 09 without connecting any candidate to live Lua/XML paths. It now covers all 8 base class portraits, one canonical portrait for each of 9 minion archetypes, and all 20 expansion enemy icons. The 37 candidates deliberately exclude class armour, class unlock skins, alternate minion colour/gear skins and all full-body artwork.

- Complete roster: `ArtSource/TextureRemaster/BaseRemasterRoster.md`
- Whole-roster QA sheet: `ArtSource/TextureRemaster/Batch09/Preview/AllBaseCandidates_QA.png`
- Per-batch comparisons: `ArtSource/TextureRemaster/Batch02/Preview/` through `Batch09/Preview/`
- Runtime contract: all 37 candidates are 128x128 uncompressed 32-bit RGBA TGA files.
- Alpha QA: no residual magenta-key pixels were detected in the candidate exports.
- Integration state: source and runtime candidates only; existing Dungeon Dwellers textures and code paths remain unchanged.

## Dice, rewards, crates and milestone chest candidate scope

Batches 10 through 14 complete the remaining dice/reward/crate/milestone-chest request in the established pixel-art direction.

- 9 dice candidates at 128x128, including a fully remastered `Dice_Web` status face.
- 5 corrected pixel-art reward candidates at 128x128. These supersede but do not overwrite the earlier Batch 01 drafts.
- 4 crate candidates at 256x256 with original, faction-neutral seals.
- 5 milestone display candidates at 512x512 plus 5 matching 128x128 icon exports.
- 23 editable masters produce 28 runtime files because milestone display/icon pairs share one master.
- Complete roster: `ArtSource/TextureRemaster/DiceRewardsCratesChestsRoster.md`.
- Whole-scope QA sheet: `ArtSource/TextureRemaster/Batch14/Preview/DiceRewardsCratesChests_AllCandidates_QA.png`.
- Integration state: disconnected candidates only; no live texture, Lua, XML or TOC path changed.

## Active boss remaster

Batch 15 begins the active 20-boss portrait/full-body pass using bosses referenced directly by `DungeonCrawlerContent.lua`.

- Completed pairs: King Candlewick, Gnarlfang Packlord, Murkfin Tide King, Zariss Coil Queen and Grumbar Earthbreaker.
- Output per boss: one source master, one 256x256 portrait and one 256x512 full-body candidate.
- Identity consistency: portrait and body are derived from the same generated master.
- Scope boundary: the separate legacy boss asset sets under `Sets/04` through `Sets/07` are not included in this active-roster pass.
- Complete/remaining roster: `ArtSource/TextureRemaster/BossRemasterRoster.md`.
- Integration state: completed candidates use unchanged live texture paths; no source-code path changed.

Batches 22 through 24 continued the active-boss pass. Twelve additional boss portrait/full-body pairs are now generated and installed at unchanged live paths. Stormtalon Matriarch, Sunblade Grand Magister and ZLR Arena Overlord remain on their previous artwork because the image-generation usage limit was reached before their masters completed. See `Docs/BossArtCompletionReport.md`.

## Base class and enemy full-body remaster

Batches 16 through 21 complete the non-skin base class and active-enemy full-body pass.

- Base classes: 8 of 8 complete.
- Active enemies: 20 of 20 complete.
- All runtime candidates preserve the existing 256x512 RGBA TGA contract.
- Class armour, alternate skins, bosses and legacy boss sets remain outside this pass.
- Complete/remaining roster: `ArtSource/TextureRemaster/FullBodyRemasterRoster.md`.
- Whole-enemy QA sheet: `ArtSource/TextureRemaster/Batch21/Preview/AllEnemyFullBodyCandidates_QA.png`.
- Integration state: disconnected candidates only; no live texture or source-code path changed.

## Audit method and limits

- Inspected the TOC load order and the loaded Dungeon asset/content/rendering Lua. No XML files exist in the repository.
- Scanned the complete repository for image extensions, Dungeon paths, texture methods, backdrop fields, masks, status bars, atlases, texture coordinates and dynamic roots.
- Decoded every in-scope file, read dimensions/alpha/size, computed file and decoded-pixel signatures, and visually inspected contact sheets for every in-scope family.
- “Currently loaded” is demand-dependent: all 192 are code-addressable, but offline inspection cannot know which optional Dungeon surface a player opens in a session.
- Candidate quality was inspected at 128x128 and the actual 36x36 reward-slot size. It has not been tested in WoW and is not connected to live code.
