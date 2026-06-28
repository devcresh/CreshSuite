# Asset Pipeline

- Game/chat textures: power-of-two TGA with WoW addon paths.
- Notification audio: mono 44.1 kHz OGG plus 25/50/75 percent gain variants.
- Game audio: mono 22.05 kHz OGG, four 12-second soft loops and six effects, each with gain variants.
- Validate every registered path, decode every OGG and verify TGA dimensions before packaging.


## Dungeon placeholder replacement

Enemy and armour placeholders are already stored under their final paths. Final art must be exported as uncompressed 32-bit TGA with power-of-two dimensions. Replace the matching file without renaming it; no Lua edits are required. Enemy icons are 256×256, enemy full-body placeholders are 256×512, armour icons are 256×256 and armour full-body placeholders are 256×512.

## Dungeon texture pack v4.0

Live Dungeon assets are stored under `Media/Games/DungeonDwellers/` in the pack's final folder layout. Enemy and armour records point directly to these TGA files. Chest popups select the next milestone chest visual for the current level, capped at the level-100 artwork. Reward cards use the supplied reward icons, except a direct armour reward uses the exact armour-set icon.

All integrated files are 32-bit RGBA TGA with power-of-two dimensions. All 20 milestone bosses now use final artwork. Only the reserved Druid/Shaman armour sets remain on placeholders. Dungeon dice use 128 × 128 textures; Tetris background themes use 256 × 256 textures.


## Tetris zone backgrounds
The 50 zone reveal images are 256x256, power-of-two, uncompressed 32-bit RGBA TGA files under `Media/Games/Tetris/Backgrounds/`. Stable keys use the `ZONE_` prefix and must match the catalogue entry and filename exactly. The board stretches the square artwork into its tall playfield and reveals it through ten texture-coordinate strips.
