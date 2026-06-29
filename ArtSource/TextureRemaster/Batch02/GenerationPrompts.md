# Batch 02 Generation Prompts

Batch 02 covers five canonical Dungeon Dwellers base portraits. It excludes class armour, unlock skins, colour variants and full-body artwork. Each image was generated separately, visually inspected, chroma-keyed to hard alpha, and exported as a disconnected 128x128 TGA candidate.

## Shared direction

- Authentic hand-placed 8-bit/16-bit-era pixel art: hard square clusters, limited palettes and sparse deliberate dithering.
- Original TBC-era fantasy dungeon-adventure mood without reproducing Blizzard artwork, symbols, characters, factions, logos or frames.
- Thin rust-copper square border, near-black interior and a strong centered silhouette readable at 38-50 px.
- Important details inset from the edge; no text, watermark, animation or alternate-skin details.
- Generator background: flat `#ff00ff` outside the tile for local conversion to crisp transparency.
- Editable master: 1024x1024 RGBA PNG. Runtime candidate: 128x128 uncompressed 32-bit RGBA TGA.

## Human Paladin

- Current role: Canonical base player portrait for the Human Paladin.
- Concept: Young blond human holy guardian in ivory plate, restrained antique-gold trim and a deep blue collar.
- Shape/composition: Head-and-shoulders three-quarter bust; broad shoulder plate and clear face silhouette.
- Border/colour: Rust-copper border; fixed ivory, gold, blue and warm skin palette.
- Lighting/readability: Warm upper-left key, cool shadow; bright hair and eyes remain distinct at 38 px.
- Negative instructions: No faction emblems, recognizable Blizzard armour, weapons, text, photorealism, smooth painting or class-skin variants.
- Output: `CreshChat_DungeonBaseClass_HumanPaladin_Master.png` / `CreshChat_DungeonBaseClass_HumanPaladin.tga`

## Orc Warrior

- Current role: Canonical base player portrait for the Orc Warrior.
- Concept: Green-skinned veteran with a dark topknot, short beard, iron-and-russet shoulder armour and a stern expression.
- Shape/composition: Head-and-shoulders three-quarter bust with tusks and shoulder plate safely inset.
- Border/colour: Rust-copper border; fixed green, iron, leather and ember palette.
- Lighting/readability: Warm upper-left key; tusks, brow and red-orange eyes carry the small-size read.
- Negative instructions: No faction emblems, recognizable Blizzard armour, weapons, text, photorealism, smooth painting or class-skin variants.
- Output: `CreshChat_DungeonBaseClass_OrcWarrior_Master.png` / `CreshChat_DungeonBaseClass_OrcWarrior.tga`

## Skeleton Bare

- Current role: Canonical unarmoured Skeleton minion portrait.
- Concept: One aged ivory skull and upper rib cage with no equipment.
- Shape/composition: Upright centered bust with large eye sockets and a clean jaw/rib silhouette.
- Border/colour: Rust-copper border; fixed bone, umber and near-black palette.
- Lighting/readability: Warm upper-left key; eye sockets and jaw gaps stay open at 38 px.
- Negative instructions: No armour, helmet, weapon, jewellery, glowing magic, second skeleton, text, smooth painting or skin-variant details.
- Output: `CreshChat_DungeonBaseMinion_SkeletonBare_Master.png` / `CreshChat_DungeonBaseMinion_SkeletonBare.tga`

## Slime Green

- Current role: Canonical Green Slime minion portrait.
- Concept: A squat translucent-looking green ooze mound with two yellow-green eyes, a few drips and one controlled highlight.
- Shape/composition: Simple centered mound with a broad footprint and uninterrupted silhouette.
- Border/colour: Rust-copper border; fixed olive, leaf-green and yellow-green palette.
- Lighting/readability: Warm upper-left glint; eyes remain the brightest and clearest feature.
- Negative instructions: No skull, armour, weapon, accessory, text, alternate colour skin, smooth painting or busy internal detail.
- Output: `CreshChat_DungeonBaseMinion_SlimeGreen_Master.png` / `CreshChat_DungeonBaseMinion_SlimeGreen.tga`

## Kobold Miner

- Current role: Base enemy icon for Candlewick Tunnel Rat.
- Concept: Original russet-furred tunnel scavenger/miner with alert amber eyes, a dark iron cap, one short candle and a worn collar.
- Shape/composition: Three-quarter head-and-shoulders bust; candle flame and long ear remain safely inset.
- Border/colour: Rust-copper border; fixed russet, dark iron, leather and ember palette.
- Lighting/readability: Candle provides the warm focal light; eye, muzzle and flame remain distinct at 38 px.
- Negative instructions: Do not reproduce Blizzard kobold art or props; no faction mark, second creature, text, elaborate background, smooth painting or photorealism.
- Output: `CreshChat_DungeonBaseEnemy_KoboldMiner_Master.png` / `CreshChat_DungeonBaseEnemy_KoboldMiner.tga`
