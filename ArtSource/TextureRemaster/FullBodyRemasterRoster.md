# Base Class and Enemy Full-Body Remaster

This pass covers non-skin full-body sprites for the eight base classes and twenty active enemies. Class armour, alternate skins, bosses and legacy boss asset sets are excluded.

## Base classes complete: 8 of 8

Batch 16:

- Human Paladin
- Orc Warrior
- Dwarf Defender
- Elf Ranger
- Human Mage

Batch 17:

- Human Priest
- Undead Rogue
- Void Warlock

Each class sprite matches its previously approved remastered portrait and uses only practical base equipment.

## Active enemy full bodies complete: 20 of 20

Batch 17:

- Candlewick Tunnel Rat (`KoboldMiner`)
- Redtooth Mauler (`GnollBrute`)

Batch 18:

- Glubfin the Loud (`MurlocTidecaller`)
- Coilscale Enchantress (`NagaSiren`)
- Grumblefist (`TroggEarthshaker`)
- Screechwing Tempest (`HarpyStormtalon`)
- Xavros the Twisted (`SatyrFelwhisper`)

Batch 19:

- Cryptweb Binder (`NerubianWebwarden`)
- Coldgrave Watcher (`FrostRevenant`)
- Fusebeard Demolitionist (`DarkIronBombardier`)
- Nexus Cutthroat (`EtherealPhaseblade`)
- Skyrend Prophet (`ArakkoaWindseer`)

Batch 20:

- Akoru the Forsaken (`BrokenSoulbinder`)
- Sunblade Disruptor (`BloodElfSpellbreaker`)
- Hellfire Bloodhowler (`FelOrcBerserker`)
- Marshroot Ancient (`BogBeast`)
- Arcane Glimmermaw (`ManaWyrm`)

Batch 21:

- Geargrind Prototype (`ClockworkReaver`)
- ZLR Blood Champion (`ArenaGladiator`)
- CATS Assault Unit (`ZeroWingDrone`)

## Remaining active enemy full bodies

None.

## Runtime contract and review state

- Source master: 1024x1024 RGBA PNG.
- Runtime candidate: 256x512 uncompressed 32-bit RGBA TGA.
- Sprites preserve source proportions and fit within a transparent 236x440 area; no horizontal stretching is used.
- Candidates remain disconnected from live Lua paths.
- Offline visual review is complete for Batches 16 through 21; in-game rendering has not been tested.
- Whole-enemy QA sheet: `ArtSource/TextureRemaster/Batch21/Preview/AllEnemyFullBodyCandidates_QA.png`.
