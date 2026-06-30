# Dungeon Dwellers Missing Images — Action Checklist

**Branch:** `audit/dungeon-dwellers-texture-links`
**Date:** 2026-06-29

All broken links have been resolved. All 292 runtime image slots exist. The items below represent art gaps that require new source images before they can be closed. No Lua or XML changes are needed for any of them.

---

## Priority 1 — Missing boss remasters (3 bosses, 6 files)

Art generation reached its usage limit during Batch 24. The three bosses below retain original placeholder art at the correct runtime paths. When replacement masters become available:

1. Export each as **uncompressed 32-bit RGBA TGA** at the correct dimensions.
2. Overwrite the file at the runtime path listed.
3. No code changes required.

| # | Boss | Level | Missing icon | Missing full body | Dimensions |
|---|---|---|---|---|---|
| 1 | Stormtalon Matriarch | 60 | `Media/Games/DungeonDwellers/Bosses/Icons/StormtalonMatriarch.tga` | `Media/Games/DungeonDwellers/Bosses/FullBody/StormtalonMatriarch.tga` | Icon: 256×256 · Full body: 256×512 |
| 2 | Sunblade Grand Magister | 140 | `Media/Games/DungeonDwellers/Bosses/Icons/SunbladeGrandMagister.tga` | `Media/Games/DungeonDwellers/Bosses/FullBody/SunbladeGrandMagister.tga` | Icon: 256×256 · Full body: 256×512 |
| 3 | ZLR Arena Overlord | 190 | `Media/Games/DungeonDwellers/Bosses/Icons/ZLRArenaOverlord.tga` | `Media/Games/DungeonDwellers/Bosses/FullBody/ZLRArenaOverlord.tga` | Icon: 256×256 · Full body: 256×512 |

---

## Priority 2 — Minion variant remasters not yet produced (19 files)

The primary variant (_01) of each minion species was reworked. The _02, _03, and _04 variants retain original art. No link is broken. Rework these when a new minion art batch is scheduled.

| Species | Unremastered variants | Runtime path pattern |
|---|---|---|
| Bat | Bat_Blue_03, Bat_Brown_02, Bat_Violet_04 | `Sets/03_.../Bat/Bat_{Variant}.tga` |
| Cultist | Cultist_Black_03, Cultist_Horned_04, Cultist_Red_02 | `Sets/03_.../Cultist/Cultist_{Variant}.tga` |
| Demon | Demon_Blue_03, Demon_Blue_Armored_04, Demon_Purple_02 | `Sets/03_.../Demon/Demon_{Variant}.tga` |
| Goblin | Goblin_Guard_02, Goblin_Hood_03 | `Sets/03_.../Goblin/Goblin_{Variant}.tga` |
| Imp | Imp_Blue_03, Imp_Purple_02 | `Sets/03_.../Imp/Imp_{Variant}.tga` |
| Skeleton | Skeleton_Armored_02 | `Sets/03_.../Skeleton/Skeleton_{Variant}.tga` |
| Slime | Slime_Yellow_02 | `Sets/03_.../Slime/Slime_{Variant}.tga` |
| Spider | Spider_Brown_02, Spider_Night_03 | `Sets/03_.../Spider/Spider_{Variant}.tga` |
| Wolf | Wolf_Dark_02, Wolf_White_03 | `Sets/03_.../Wolf/Wolf_{Variant}.tga` |

---

## Priority 3 — Cosmetic boss art sets not reworked (40 files)

Sets 04–07 (cosmetic boss skins selected via the asset-set picker) all retain original art. These are a separate system from the 20 gameplay bosses. No rework has been requested for them.

| System | Set | Files | Count |
|---|---|---|---|
| Cosmetic boss icons A | Set 04 | SkeletonKing, LichLord, DemonWarlord, VoidPriest, OrcChampion, TrollWitchDoctor, DarkPaladin, FireMageBoss, IceQueen, SpiderMatriarch | 10 |
| Cosmetic boss full bodies A | Set 05 | Same 10 entities | 10 |
| Cosmetic boss icons B | Set 06 | WolfAlpha, BatLord, SlimeTyrant, GoblinMechBoss, CultMaster, Necromancer, FelKnight, ShadowAssassin, StoneGolem, DragonkinBoss | 10 |
| Cosmetic boss full bodies B | Set 07 | Same 10 entities | 10 |

---

## Priority 4 — Placeholder class armour (20 files, by design)

Druid and Shaman class armour tiers 1–5 intentionally use placeholder images. `artStatus = "PLACEHOLDER"` and `reservedClass = true` are correctly set. No action required until those classes are implemented.

| Class | Files | Location |
|---|---|---|
| Druid | Icon.tga + FullBody.tga × 5 tiers | `ArmourSets/DRUID/<tier>/` |
| Shaman | Icon.tga + FullBody.tga × 5 tiers | `ArmourSets/SHAMAN/<tier>/` |

---

## Deferred code items (no image work required)

| Item | File | Action |
|---|---|---|
| `artStatus = "PLACEHOLDER"` stale for 17 reworked gameplay bosses | [DungeonCrawlerContent.lua](../DungeonCrawlerContent.lua) | Update to `"LIVE_BOSS_ART"` for the 17 completed bosses. Field is not read at runtime so this is a doc-only fix. |
| `name = "Maghar Bloodhowler"` vs texture filename `HellfireBloodhowler` for FEL_ORC_BERSERKER | [DungeonCrawlerContent.lua](../DungeonCrawlerContent.lua) | Requires explicit decision: rename files and update two path strings, OR change the display name. Link is not broken. |
