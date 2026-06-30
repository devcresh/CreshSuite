# Dungeon Dwellers Texture-Link Audit

**Branch:** `audit/dungeon-dwellers-texture-links`
**Audit date:** 2026-06-29
**Auditor:** Claude Code (automated)

---

## A. Audit Summary

| Metric | Count |
|---|---|
| Total Dungeon Dwellers entities found | 150 |
| Total required image slots | 292 |
| Total unique runtime image files confirmed | 292 |
| Correct links | 292 |
| Missing images | 0 |
| Missing links | 0 |
| Broken paths | 0 |
| Incorrect entity mappings | 0 |
| Portrait / full-body reversals | 0 |
| Icon / display reversals | 0 |
| Reworked images confirmed installed | 151 |
| Old textures still active (by design or pending art) | 141 |
| Placeholders still active (by design) | 20 |
| Duplicate links | 1 (SHARDS + ARMOUR reward icons) |
| Ambiguous mappings | 0 |
| Automatically repaired items | 0 |
| Deferred items | 4 |

All 292 runtime image slots resolve to existing files. No Lua, XML, or TOC file was changed. No commit or push was performed.

---

## B. Complete Link Table

### Player Classes — Portrait (Set 01)

| Category | Entity | Internal ID | Image type | Defined path | File exists | Correct entity | Status |
|---|---|---|---|---|---|---|---|
| Player portrait | Human Paladin | HumanPaladin | 128×128 portrait | Sets/01_Player_Portraits_Classic/Portraits/HumanPaladin.tga | Yes | Yes | Correct |
| Player portrait | Orc Warrior | OrcWarrior | 128×128 portrait | Sets/01_Player_Portraits_Classic/Portraits/OrcWarrior.tga | Yes | Yes | Correct |
| Player portrait | Undead Rogue | UndeadRogue | 128×128 portrait | Sets/01_Player_Portraits_Classic/Portraits/UndeadRogue.tga | Yes | Yes | Correct |
| Player portrait | Dwarf Defender | DwarfDefender | 128×128 portrait | Sets/01_Player_Portraits_Classic/Portraits/DwarfDefender.tga | Yes | Yes | Correct |
| Player portrait | Elf Ranger | ElfRanger | 128×128 portrait | Sets/01_Player_Portraits_Classic/Portraits/ElfRanger.tga | Yes | Yes | Correct |
| Player portrait | Human Mage | HumanMage | 128×128 portrait | Sets/01_Player_Portraits_Classic/Portraits/HumanMage.tga | Yes | Yes | Correct |
| Player portrait | Human Priest | HumanPriest | 128×128 portrait | Sets/01_Player_Portraits_Classic/Portraits/HumanPriest.tga | Yes | Yes | Correct |
| Player portrait | Void Warlock | VoidWarlock | 128×128 portrait | Sets/01_Player_Portraits_Classic/Portraits/VoidWarlock.tga | Yes | Yes | Correct |

### Player Classes — Full Body (Set 02)

| Category | Entity | Internal ID | Image type | Defined path | File exists | Correct entity | Status |
|---|---|---|---|---|---|---|---|
| Player full body | Human Paladin | HumanPaladin | 256×512 full body | Sets/02_Player_FullBody_Classic/FullBody/HumanPaladin.tga | Yes | Yes | Correct |
| Player full body | Orc Warrior | OrcWarrior | 256×512 full body | Sets/02_Player_FullBody_Classic/FullBody/OrcWarrior.tga | Yes | Yes | Correct |
| Player full body | Undead Rogue | UndeadRogue | 256×512 full body | Sets/02_Player_FullBody_Classic/FullBody/UndeadRogue.tga | Yes | Yes | Correct |
| Player full body | Dwarf Defender | DwarfDefender | 256×512 full body | Sets/02_Player_FullBody_Classic/FullBody/DwarfDefender.tga | Yes | Yes | Correct |
| Player full body | Elf Ranger | ElfRanger | 256×512 full body | Sets/02_Player_FullBody_Classic/FullBody/ElfRanger.tga | Yes | Yes | Correct |
| Player full body | Human Mage | HumanMage | 256×512 full body | Sets/02_Player_FullBody_Classic/FullBody/HumanMage.tga | Yes | Yes | Correct |
| Player full body | Human Priest | HumanPriest | 256×512 full body | Sets/02_Player_FullBody_Classic/FullBody/HumanPriest.tga | Yes | Yes | Correct |
| Player full body | Void Warlock | VoidWarlock | 256×512 full body | Sets/02_Player_FullBody_Classic/FullBody/VoidWarlock.tga | Yes | Yes | Correct |

### Minion Portraits (Set 03)

Reworked variants (9): size 65554 B. Unremastered variants (19): size 65580 B (original art retained by design; no rework was requested).

| Category | Entity | Internal ID | Image type | Defined path | File exists | Correct entity | Status |
|---|---|---|---|---|---|---|---|
| Minion portrait | Black Bat | Bat_Black_01 | 128×128 portrait | Sets/03.../Bat/Bat_Black_01.tga | Yes | Yes | Correct — reworked |
| Minion portrait | Blue Bat | Bat_Blue_03 | 128×128 portrait | Sets/03.../Bat/Bat_Blue_03.tga | Yes | Yes | Correct — original art |
| Minion portrait | Brown Bat | Bat_Brown_02 | 128×128 portrait | Sets/03.../Bat/Bat_Brown_02.tga | Yes | Yes | Correct — original art |
| Minion portrait | Violet Bat | Bat_Violet_04 | 128×128 portrait | Sets/03.../Bat/Bat_Violet_04.tga | Yes | Yes | Correct — original art |
| Minion portrait | Purple Cultist | Cultist_Purple_01 | 128×128 portrait | Sets/03.../Cultist/Cultist_Purple_01.tga | Yes | Yes | Correct — reworked |
| Minion portrait | Black Cultist | Cultist_Black_03 | 128×128 portrait | Sets/03.../Cultist/Cultist_Black_03.tga | Yes | Yes | Correct — original art |
| Minion portrait | Horned Cultist | Cultist_Horned_04 | 128×128 portrait | Sets/03.../Cultist/Cultist_Horned_04.tga | Yes | Yes | Correct — original art |
| Minion portrait | Red Cultist | Cultist_Red_02 | 128×128 portrait | Sets/03.../Cultist/Cultist_Red_02.tga | Yes | Yes | Correct — original art |
| Minion portrait | Red Demon | Demon_Red_01 | 128×128 portrait | Sets/03.../Demon/Demon_Red_01.tga | Yes | Yes | Correct — reworked |
| Minion portrait | Blue Demon | Demon_Blue_03 | 128×128 portrait | Sets/03.../Demon/Demon_Blue_03.tga | Yes | Yes | Correct — original art |
| Minion portrait | Blue Armored Demon | Demon_Blue_Armored_04 | 128×128 portrait | Sets/03.../Demon/Demon_Blue_Armored_04.tga | Yes | Yes | Correct — original art |
| Minion portrait | Purple Demon | Demon_Purple_02 | 128×128 portrait | Sets/03.../Demon/Demon_Purple_02.tga | Yes | Yes | Correct — original art |
| Minion portrait | Goblin Raider | Goblin_Raider_01 | 128×128 portrait | Sets/03.../Goblin/Goblin_Raider_01.tga | Yes | Yes | Correct — reworked |
| Minion portrait | Goblin Guard | Goblin_Guard_02 | 128×128 portrait | Sets/03.../Goblin/Goblin_Guard_02.tga | Yes | Yes | Correct — original art |
| Minion portrait | Goblin Hood | Goblin_Hood_03 | 128×128 portrait | Sets/03.../Goblin/Goblin_Hood_03.tga | Yes | Yes | Correct — original art |
| Minion portrait | Red Imp | Imp_Red_01 | 128×128 portrait | Sets/03.../Imp/Imp_Red_01.tga | Yes | Yes | Correct — reworked |
| Minion portrait | Blue Imp | Imp_Blue_03 | 128×128 portrait | Sets/03.../Imp/Imp_Blue_03.tga | Yes | Yes | Correct — original art |
| Minion portrait | Purple Imp | Imp_Purple_02 | 128×128 portrait | Sets/03.../Imp/Imp_Purple_02.tga | Yes | Yes | Correct — original art |
| Minion portrait | Bare Skeleton | Skeleton_Bare_01 | 128×128 portrait | Sets/03.../Skeleton/Skeleton_Bare_01.tga | Yes | Yes | Correct — reworked |
| Minion portrait | Armored Skeleton | Skeleton_Armored_02 | 128×128 portrait | Sets/03.../Skeleton/Skeleton_Armored_02.tga | Yes | Yes | Correct — original art |
| Minion portrait | Green Slime | Slime_Green_01 | 128×128 portrait | Sets/03.../Slime/Slime_Green_01.tga | Yes | Yes | Correct — reworked |
| Minion portrait | Yellow Slime | Slime_Yellow_02 | 128×128 portrait | Sets/03.../Slime/Slime_Yellow_02.tga | Yes | Yes | Correct — original art |
| Minion portrait | Shadow Spider | Spider_Shadow_01 | 128×128 portrait | Sets/03.../Spider/Spider_Shadow_01.tga | Yes | Yes | Correct — reworked |
| Minion portrait | Brown Spider | Spider_Brown_02 | 128×128 portrait | Sets/03.../Spider/Spider_Brown_02.tga | Yes | Yes | Correct — original art |
| Minion portrait | Night Spider | Spider_Night_03 | 128×128 portrait | Sets/03.../Spider/Spider_Night_03.tga | Yes | Yes | Correct — original art |
| Minion portrait | Grey Wolf | Wolf_Grey_01 | 128×128 portrait | Sets/03.../Wolf/Wolf_Grey_01.tga | Yes | Yes | Correct — reworked |
| Minion portrait | Dark Wolf | Wolf_Dark_02 | 128×128 portrait | Sets/03.../Wolf/Wolf_Dark_02.tga | Yes | Yes | Correct — original art |
| Minion portrait | White Wolf | Wolf_White_03 | 128×128 portrait | Sets/03.../Wolf/Wolf_White_03.tga | Yes | Yes | Correct — original art |

### Cosmetic Boss Sets (Sets 04–07)

These 20 cosmetic boss entities are distinct from the 20 gameplay bosses. They provide alternate boss skins selectable in the asset-set system (used via `DUNGEON_BODY_SET` / `DUNGEON_ICON_SET` in SoloGames.lua). They are not reworked; all retain original art and all files exist.

| Category | Entity | Set | Image type | File exists | Status |
|---|---|---|---|---|---|
| Cosmetic boss icon | Skeleton King | 04 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Lich Lord | 04 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Demon Warlord | 04 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Void Priest | 04 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Orc Champion | 04 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Troll Witch Doctor | 04 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Dark Paladin | 04 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Fire Mage Boss | 04 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Ice Queen | 04 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Spider Matriarch | 04 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss full body | Skeleton King | 05 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Lich Lord | 05 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Demon Warlord | 05 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Void Priest | 05 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Orc Champion | 05 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Troll Witch Doctor | 05 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Dark Paladin | 05 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Fire Mage Boss | 05 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Ice Queen | 05 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Spider Matriarch | 05 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss icon | Wolf Alpha | 06 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Bat Lord | 06 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Slime Tyrant | 06 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Goblin Mech Boss | 06 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Cult Master | 06 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Necromancer | 06 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Fel Knight | 06 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Shadow Assassin | 06 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Stone Golem | 06 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss icon | Dragonkin Boss | 06 | 256×256 icon | Yes | Correct — original art |
| Cosmetic boss full body | Wolf Alpha | 07 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Bat Lord | 07 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Slime Tyrant | 07 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Goblin Mech Boss | 07 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Cult Master | 07 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Necromancer | 07 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Fel Knight | 07 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Shadow Assassin | 07 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Stone Golem | 07 | 256×512 full body | Yes | Correct — original art |
| Cosmetic boss full body | Dragonkin Boss | 07 | 256×512 full body | Yes | Correct — original art |

### Enemy Icons (Set 08)

All 20 files reworked (65554 B). All paths resolve correctly in DungeonCrawlerContent.lua.

| Category | Entity | Internal ID | Image type | Defined path | File exists | Status |
|---|---|---|---|---|---|---|
| Enemy icon | Candlewick Tunnel Rat | KOBOLD_MINER | 128×128 icon | Sets/08.../Icons/Enemy_KoboldMiner_CandlewickTunnelRat.tga | Yes | Correct — reworked |
| Enemy icon | Redtooth Mauler | GNOLL_BRUTE | 128×128 icon | Sets/08.../Icons/Enemy_GnollBrute_RedtoothMauler.tga | Yes | Correct — reworked |
| Enemy icon | Glubfin the Loud | MURLOC_TIDECALLER | 128×128 icon | Sets/08.../Icons/Enemy_MurlocTidecaller_GlubfintheLoud.tga | Yes | Correct — reworked |
| Enemy icon | Coilscale Enchantress | NAGA_SIREN | 128×128 icon | Sets/08.../Icons/Enemy_NagaSiren_CoilscaleEnchantress.tga | Yes | Correct — reworked |
| Enemy icon | Grumblefist | TROGG_EARTHSHAKER | 128×128 icon | Sets/08.../Icons/Enemy_TroggEarthshaker_Grumblefist.tga | Yes | Correct — reworked |
| Enemy icon | Screechwing Tempest | HARPY_STORMTALON | 128×128 icon | Sets/08.../Icons/Enemy_HarpyStormtalon_ScreechwingTempest.tga | Yes | Correct — reworked |
| Enemy icon | Xavros the Twisted | SATYR_FELWHISPER | 128×128 icon | Sets/08.../Icons/Enemy_SatyrFelwhisper_XavrostheTwisted.tga | Yes | Correct — reworked |
| Enemy icon | Cryptweb Binder | NERUBIAN_WEBWARDEN | 128×128 icon | Sets/08.../Icons/Enemy_NerubianWebwarden_CryptwebBinder.tga | Yes | Correct — reworked |
| Enemy icon | Coldgrave Watcher | FROST_REVENANT | 128×128 icon | Sets/08.../Icons/Enemy_FrostRevenant_ColdgraveWatcher.tga | Yes | Correct — reworked |
| Enemy icon | Fusebeard Demolitionist | DARK_IRON_BOMBARDIER | 128×128 icon | Sets/08.../Icons/Enemy_DarkIronBombardier_FusebeardDemolitionist.tga | Yes | Correct — reworked |
| Enemy icon | Nexus Cutthroat | ETHEREAL_PHASEBLADE | 128×128 icon | Sets/08.../Icons/Enemy_EtherealPhaseblade_NexusCutthroat.tga | Yes | Correct — reworked |
| Enemy icon | Skyrend Prophet | ARAKKOA_WINDSEER | 128×128 icon | Sets/08.../Icons/Enemy_ArakkoaWindseer_SkyrendProphet.tga | Yes | Correct — reworked |
| Enemy icon | Akoru the Forsaken | BROKEN_SOULBINDER | 128×128 icon | Sets/08.../Icons/Enemy_BrokenSoulbinder_AkorutheForsaken.tga | Yes | Correct — reworked |
| Enemy icon | Sunblade Disruptor | BLOOD_ELF_SPELLBREAKER | 128×128 icon | Sets/08.../Icons/Enemy_BloodElfSpellbreaker_SunbladeDisruptor.tga | Yes | Correct — reworked |
| Enemy icon | Hellfire Bloodhowler¹ | FEL_ORC_BERSERKER | 128×128 icon | Sets/08.../Icons/Enemy_FelOrcBerserker_HellfireBloodhowler.tga | Yes | Correct link — name note (see §I) |
| Enemy icon | Marshroot Ancient | BOG_BEAST | 128×128 icon | Sets/08.../Icons/Enemy_BogBeast_MarshrootAncient.tga | Yes | Correct — reworked |
| Enemy icon | Arcane Glimmermaw | MANA_WYRM | 128×128 icon | Sets/08.../Icons/Enemy_ManaWyrm_ArcaneGlimmermaw.tga | Yes | Correct — reworked |
| Enemy icon | Geargrind Prototype | CLOCKWORK_REAVER | 128×128 icon | Sets/08.../Icons/Enemy_ClockworkReaver_GeargrindPrototype.tga | Yes | Correct — reworked |
| Enemy icon | ZLR Blood Champion | ARENA_GLADIATOR | 128×128 icon | Sets/08.../Icons/Enemy_ArenaGladiator_ZLRBloodChampion.tga | Yes | Correct — reworked |
| Enemy icon | CATS Assault Unit | ZERO_WING_DRONE | 128×128 icon | Sets/08.../Icons/Enemy_ZeroWingDrone_CATSAssaultUnit.tga | Yes | Correct — reworked |

¹ The Lua `name` field for FEL_ORC_BERSERKER is "Maghar Bloodhowler" but the texture filename is `HellfireBloodhowler`. The link is not broken. See §I.

### Enemy Full Bodies (Set 09)

All 20 files reworked (524306 B). Paths match Set 08 entity-to-filename mapping exactly.

| Category | Entity | Internal ID | Image type | File exists | Status |
|---|---|---|---|---|---|
| Enemy full body | Candlewick Tunnel Rat | KOBOLD_MINER | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Redtooth Mauler | GNOLL_BRUTE | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Glubfin the Loud | MURLOC_TIDECALLER | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Coilscale Enchantress | NAGA_SIREN | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Grumblefist | TROGG_EARTHSHAKER | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Screechwing Tempest | HARPY_STORMTALON | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Xavros the Twisted | SATYR_FELWHISPER | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Cryptweb Binder | NERUBIAN_WEBWARDEN | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Coldgrave Watcher | FROST_REVENANT | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Fusebeard Demolitionist | DARK_IRON_BOMBARDIER | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Nexus Cutthroat | ETHEREAL_PHASEBLADE | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Skyrend Prophet | ARAKKOA_WINDSEER | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Akoru the Forsaken | BROKEN_SOULBINDER | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Sunblade Disruptor | BLOOD_ELF_SPELLBREAKER | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Hellfire Bloodhowler¹ | FEL_ORC_BERSERKER | 256×512 full body | Yes | Correct link — name note |
| Enemy full body | Marshroot Ancient | BOG_BEAST | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Arcane Glimmermaw | MANA_WYRM | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | Geargrind Prototype | CLOCKWORK_REAVER | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | ZLR Blood Champion | ARENA_GLADIATOR | 256×512 full body | Yes | Correct — reworked |
| Enemy full body | CATS Assault Unit | ZERO_WING_DRONE | 256×512 full body | Yes | Correct — reworked |

### Gameplay Boss Icons and Full Bodies (Bosses/)

17 bosses have reworked art (262162 B icon / 524306 B full body). 3 retain original art (262188 B / 524332 B). All 40 files exist and all paths in DungeonCrawlerContent.lua resolve correctly. All 20 entries carry `artStatus = "PLACEHOLDER"` in the data; this field is not read at runtime and is stale for 17 entries (see §I).

| Category | Entity | Internal ID | Level | Icon exists | FullBody exists | Art state |
|---|---|---|---|---|---|---|
| Gameplay boss | King Candlewick | KING_CANDLEWICK | 10 | Yes | Yes | Reworked |
| Gameplay boss | Gnarlfang the Packlord | GNARLFANG_PACKLORD | 20 | Yes | Yes | Reworked |
| Gameplay boss | Murkfin Tide King | MURKFIN_TIDE_KING | 30 | Yes | Yes | Reworked |
| Gameplay boss | Zariss the Coil Queen | ZARISS_COIL_QUEEN | 40 | Yes | Yes | Reworked |
| Gameplay boss | Grumbar Earthbreaker | GRUMBAR_EARTHBREAKER | 50 | Yes | Yes | Reworked |
| Gameplay boss | Stormtalon Matriarch | STORMTALON_MATRIARCH | 60 | Yes | Yes | Original art retained |
| Gameplay boss | Xavros Felwhisper | XAVROS_FELWHISPER | 70 | Yes | Yes | Reworked |
| Gameplay boss | Azarak the Web Tyrant | AZARAK_WEB_TYRANT | 80 | Yes | Yes | Reworked |
| Gameplay boss | Lord Coldgrave | LORD_COLDGRAVE | 90 | Yes | Yes | Reworked |
| Gameplay boss | Emperor Blackfuse | EMPEROR_BLACKFUSE | 100 | Yes | Yes | Reworked |
| Gameplay boss | Nexus Lord Vaelrix | NEXUS_LORD_VAELRIX | 110 | Yes | Yes | Reworked |
| Gameplay boss | High Seer Skyrend | HIGH_SEER_SKYREND | 120 | Yes | Yes | Reworked |
| Gameplay boss | Akoru the Soulkeeper | AKORU_SOULKEEPER | 130 | Yes | Yes | Reworked |
| Gameplay boss | Sunblade Grand Magister | SUNBLADE_GRAND_MAGISTER | 140 | Yes | Yes | Original art retained |
| Gameplay boss | Gorvak the Unchained | GORVAK_UNCHAINED | 150 | Yes | Yes | Reworked |
| Gameplay boss | The Drowned Ancient | DROWNED_ANCIENT | 160 | Yes | Yes | Reworked |
| Gameplay boss | Astralax the Devourer | ASTRALAX_DEVOURER | 170 | Yes | Yes | Reworked |
| Gameplay boss | Prototype Omega-Reaver | OMEGA_REAVER | 180 | Yes | Yes | Reworked |
| Gameplay boss | ZLR Arena Overlord | ZLR_ARENA_OVERLORD | 190 | Yes | Yes | Original art retained |
| Gameplay boss | CATS, Master of the Base | CATS_MASTER_BASE | 200 | Yes | Yes | Reworked |

### Class Armour — Active Classes (8 × 5 tiers)

All 80 files (40 icons + 40 full bodies) exist under `ClassArmor/Icons/<Class>/` and `ClassArmor/FullBody/<Class>/`. All have `artStatus = "LIVE_TEXTURE_PACK_V4"` and are correctly linked. Paths verified for all 8 classes × 5 tiers.

| Class | Tiers present | Icon files | FullBody files | Status |
|---|---|---|---|---|
| Paladin | 1–5 | 5 | 5 | Correct |
| Warrior | 1–5 | 5 | 5 | Correct |
| Rogue | 1–5 | 5 | 5 | Correct |
| Ranger | 1–5 | 5 | 5 | Correct |
| Mage | 1–5 | 5 | 5 | Correct |
| Priest | 1–5 | 5 | 5 | Correct |
| Warlock | 1–5 | 5 | 5 | Correct |
| Defender | 1–5 | 5 | 5 | Correct |

### Class Armour — Placeholder Classes (Druid and Shaman)

Stored under `ArmourSets/<CLASS>/<TIER_NAME>/Icon.tga` and `FullBody.tga`. All 20 files exist. `artStatus = "PLACEHOLDER"` and `reservedClass = true` are correct and by design.

| Class | Tiers present | Files exist | Status |
|---|---|---|---|
| Druid | 1–5 | Yes (10 files) | Placeholder — correct |
| Shaman | 1–5 | Yes (10 files) | Placeholder — correct |

### Milestone Chests

| Category | Entity | Level | Icon path | Display path | Files exist | Status |
|---|---|---|---|---|---|---|
| Milestone chest | Level 20 Milestone Chest | 20 | Chests/Icons/Chest_L20_*.tga | Chests/Display/Chest_L20_*.tga | Yes | Correct — reworked |
| Milestone chest | Level 40 Milestone Chest | 40 | Chests/Icons/Chest_L40_*.tga | Chests/Display/Chest_L40_*.tga | Yes | Correct — reworked |
| Milestone chest | Level 60 Milestone Chest | 60 | Chests/Icons/Chest_L60_*.tga | Chests/Display/Chest_L60_*.tga | Yes | Correct — reworked |
| Milestone chest | Level 80 Milestone Chest | 80 | Chests/Icons/Chest_L80_*.tga | Chests/Display/Chest_L80_*.tga | Yes | Correct — reworked |
| Milestone chest | Level 100 Milestone Chest | 100 | Chests/Icons/Chest_L100_*.tga | Chests/Display/Chest_L100_*.tga | Yes | Correct — reworked |

### Reward Icons

`SHARDS` and `ARMOUR` share `RewardIcon_ArmourChoiceToken.tga`. This duplicate link is intentional (both reward types use the same icon). See §F.

| Category | Reward type | Path | File exists | Status |
|---|---|---|---|---|
| Reward icon | COINS | RewardIcons/Icons/RewardIcon_CreshCoinCache.tga | Yes | Correct — reworked |
| Reward icon | DAMAGE | RewardIcons/Icons/RewardIcon_DamageRelic.tga | Yes | Correct — reworked |
| Reward icon | PORTRAIT | RewardIcons/Icons/RewardIcon_PortraitToken.tga | Yes | Correct — reworked |
| Reward icon | FULLBODY | RewardIcons/Icons/RewardIcon_FullBodyToken.tga | Yes | Correct — reworked |
| Reward icon | SHARDS | RewardIcons/Icons/RewardIcon_ArmourChoiceToken.tga | Yes | Correct — reworked (shared) |
| Reward icon | ARMOUR | RewardIcons/Icons/RewardIcon_ArmourChoiceToken.tga | Yes | Correct — reworked (shared) |

### Crates

| Category | Entity | Path | File exists | Status |
|---|---|---|---|---|
| Crate icon | Adventurer's Cache | Crates/AdventurersCache.tga | Yes | Correct — reworked |
| Crate icon | Warbound Strongbox | Crates/WarboundStrongbox.tga | Yes | Correct — reworked |
| Crate icon | Royal Vanguard Chest | Crates/RoyalVanguardChest.tga | Yes | Correct — reworked |
| Crate icon | Voidlord Reliquary | Crates/VoidlordReliquary.tga | Yes | Correct — reworked |

### Dice Faces

Loaded via `DUNGEON_DICE_ROOT .. "Dice_" .. value .. ".tga"` in SoloGames.lua. All 9 files reworked (65554 B).

| Entity | Path | File exists | Status |
|---|---|---|---|
| Dice_1 | Dice/Dice_1.tga | Yes | Correct — reworked |
| Dice_2 | Dice/Dice_2.tga | Yes | Correct — reworked |
| Dice_3 | Dice/Dice_3.tga | Yes | Correct — reworked |
| Dice_4 | Dice/Dice_4.tga | Yes | Correct — reworked |
| Dice_5 | Dice/Dice_5.tga | Yes | Correct — reworked |
| Dice_6 | Dice/Dice_6.tga | Yes | Correct — reworked |
| Dice_7 | Dice/Dice_7.tga | Yes | Correct — reworked |
| Dice_8 | Dice/Dice_8.tga | Yes | Correct — reworked |
| Dice_Web | Dice/Dice_Web.tga | Yes | Correct — reworked |

---

## C. Missing Images

No missing images. All 292 runtime image slots resolve to existing files.

---

## D. Missing or Broken Links

No broken or missing links found. All texture paths in DungeonCrawlerContent.lua, DungeonDwellersAssetSets.lua, and SoloGames.lua resolve to existing files.

---

## E. Unlinked Reworked Images

No unlinked reworked images. All 151 reworked runtime files (127 from Batches 01–21 + 24 from Batches 22–24) are referenced by the live modules and are correctly installed at their existing paths.

Source masters under `ArtSource/TextureRemaster/` are intentionally not loaded at runtime. No source master or preview file is referenced by any Lua module.

---

## F. Duplicate Links

| Runtime path | Entities using it | Intentional? | Risk | Recommended action |
|---|---|---|---|---|
| `RewardIcons/Icons/RewardIcon_ArmourChoiceToken.tga` | SHARDS, ARMOUR reward types | Yes — both reward types represent armour choices | None | No action required |

---

## G. Placeholder and Fallback Usage

### Intentional placeholders (by design)

- **Druid class armour (tiers 1–5):** `ArmourSets/DRUID/.../Icon.tga` and `FullBody.tga`. `reservedClass = true`, `artStatus = "PLACEHOLDER"`. Gameplay disabled. Retain until Druid art is supplied.
- **Shaman class armour (tiers 1–5):** `ArmourSets/SHAMAN/.../Icon.tga` and `FullBody.tga`. Same status. Retain until Shaman art is supplied.

### Old art retained (remaster not yet produced)

- **Stormtalon Matriarch** (boss level 60): Icon and full body at original dimensions (262188 B / 524332 B). Art generation reached limit before this boss was reached. Existing live art retained.
- **Sunblade Grand Magister** (boss level 140): Same status.
- **ZLR Arena Overlord** (boss level 190): Same status.

### Original art retained (rework scope did not include these)

- **19 of 28 minion portrait variants** (all _02, _03, _04 suffix variants): Rework covered only the primary _01 variant of each species type. The _02+ variants exist and are correctly linked but were not reworked.
- **40 cosmetic boss set images** (Sets 04–07): These use the old fantasy-themed boss art (SkeletonKing, LichLord, etc.). No rework was requested or performed for these sets.

### Fallback used when texture path is nil

SoloGames.lua `dungeonSetTexture` falls back to `Interface\\Icons\\INV_Misc_QuestionMark` when a path is nil. This fallback cannot trigger for any entity in the current data tables because all runtime paths resolve to existing files.

---

## H. Repairs Performed

None. All discovered image slots are correctly linked. No Lua, XML, or TOC file was changed during this audit.

---

## I. Deferred Items

### 1. Three gameplay bosses without reworked art

| Boss | Key | Level | Status |
|---|---|---|---|
| Stormtalon Matriarch | STORMTALON_MATRIARCH | 60 | Art generation ended before Batch 25; original art retained |
| Sunblade Grand Magister | SUNBLADE_GRAND_MAGISTER | 140 | Same |
| ZLR Arena Overlord | ZLR_ARENA_OVERLORD | 190 | Same |

**What is missing:** New icon (256×256 RGBA TGA) and full-body (256×512 RGBA TGA) master images for each boss.
**Why not changed:** Source art does not yet exist.
**Required to resolve:** Generate or supply master images, export as uncompressed 32-bit RGBA TGA at the correct dimensions, and place them at the existing runtime paths (preserving filenames). No Lua changes needed.
**Paths to update later:**
- `Media/Games/DungeonDwellers/Bosses/Icons/StormtalonMatriarch.tga`
- `Media/Games/DungeonDwellers/Bosses/FullBody/StormtalonMatriarch.tga`
- `Media/Games/DungeonDwellers/Bosses/Icons/SunbladeGrandMagister.tga`
- `Media/Games/DungeonDwellers/Bosses/FullBody/SunbladeGrandMagister.tga`
- `Media/Games/DungeonDwellers/Bosses/Icons/ZLRArenaOverlord.tga`
- `Media/Games/DungeonDwellers/Bosses/FullBody/ZLRArenaOverlord.tga`

### 2. FEL_ORC_BERSERKER display name / filename mismatch

- **Data:** `name = "Maghar Bloodhowler"` in DungeonCrawlerContent.lua
- **Texture filename:** `Enemy_FelOrcBerserker_HellfireBloodhowler.tga` (both icon and full body)
- **Issue:** The display name used in Lua does not match the name encoded in the texture filename. All other enemies match their display name to their texture filename (e.g. "Candlewick Tunnel Rat" → `..._CandlewickTunnelRat.tga`).
- **Why not changed:** The texture link is not broken — the file at `HellfireBloodhowler` exists and is correctly referenced. A fix requires either renaming the files and updating the Lua paths, or changing the display name. Either path may affect in-game text visible to the player. Requires explicit user decision.
- **File to update:** [DungeonCrawlerContent.lua](../DungeonCrawlerContent.lua) line referencing `name = "Maghar Bloodhowler"` in `FEL_ORC_BERSERKER`, or rename both TGA files and update their two Lua path strings.

### 3. Stale artStatus metadata for 17 gameplay bosses

All 20 gameplay boss entries in DungeonCrawlerContent.lua have `artStatus = "PLACEHOLDER"`. Seventeen of them now have reworked art. This field is not read at runtime (grep confirmed it has no usage in SoloGames.lua or any other module), so it has no functional effect. It is purely documentation metadata.
- **Why not changed:** Not a texture link. Data-only change that is safe but low priority.
- **Recommended action:** Update `artStatus` for the 17 reworked bosses to `"LIVE_BOSS_ART"` (or a similar label) and leave the 3 unremastered bosses at `"PLACEHOLDER"` in [DungeonCrawlerContent.lua](../DungeonCrawlerContent.lua).

### 4. Minion variants and cosmetic boss sets without rework

- 19 minion portrait variants (_02, _03, _04 per species) in Set 03 retain original art.
- 40 cosmetic boss images in Sets 04–07 retain original art.
- **Why not changed:** No rework was requested for these. All links are correct. No action required unless a future rework batch targets them.

---

## Validation results

```
git diff --check  →  clean (no whitespace errors)
git diff --stat   →  127 binary files changed, 0 insertions, 0 deletions
git diff -- "*.lua" "*.xml" "*.toc"  →  no output (no source changes)
```

- No gameplay logic changed.
- No SavedVariables changed.
- No networking changed.
- No chat behaviour changed.
- No version number changed.
- No unrelated formatting changed.
- No other project was touched.
- No commit or push was performed.
- In-game testing remains pending (user must confirm).
