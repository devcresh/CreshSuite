# Dungeon Dwellers Batch 01 Generation Prompts

Tool: built-in OpenAI image generation. Use case: `stylized-concept`. Each request produced one separate opaque PNG master. No Blizzard art, other-addon art or external image library was supplied as input.

Shared direction: original painted fantasy Dungeon Dwellers reward icon; opaque square midnight enamel tile; thin inset antique-gold octagonal rim; warm upper-left light and cool lower-right rim; strong central silhouette; controlled detail; 12% safe padding; clear at 36x36; no text, letters, numbers, logo, watermark, faction symbol, Blizzard artwork, copied game art, sprite sheet, mockup or transparent background.

## Cresh Coin Cache

- Current role: COINS reward on crate-choice cards and collection entries.
- Concept: one open dark-leather pouch holding three oversized antique-gold coins, with a small original cyan diamond seal.
- Colour behaviour: fixed gold/brown/navy with a cyan identifier; must tolerate locked desaturation.
- Master: 1254x1254 opaque PNG.
- Runtime: 128x128 opaque RGBA uncompressed TGA.
- Output: `Source/CreshChat_DungeonReward_CreshCoinCache_Master.png`.

## Damage Relic

- Current role: permanent starting-damage reward.
- Concept: one jagged crimson crystal spearhead/relic in a compact dark-iron collar with a bright amber core fissure.
- Colour behaviour: fixed crimson/ember/navy; no external flames or blood.
- Master: 1254x1254 opaque PNG.
- Runtime: 128x128 opaque RGBA uncompressed TGA.
- Output: `Source/CreshChat_DungeonReward_DamageRelic_Master.png`.

## Portrait Token

- Current role: portrait-skin token reward.
- Concept: violet-and-gold cameo medallion with a gender-neutral adventurer head-and-shoulders silhouette in profile.
- Colour behaviour: fixed violet/gold/navy; minimal face detail; class/race neutral.
- Master: 1254x1254 opaque PNG.
- Runtime: 128x128 opaque RGBA uncompressed TGA.
- Output: `Source/CreshChat_DungeonReward_PortraitToken_Master.png`.

## Full-Body Token

- Current role: full-body-skin token reward.
- Concept: simplified full-length class-neutral adventurer silhouette in a neutral hero pose inside a tall sapphire hexagonal medallion.
- Colour behaviour: fixed sapphire/ivory/gold/navy; must not resemble a specific class, race or character.
- Master: 1254x1254 opaque PNG after removing the generator's uniform white outer canvas.
- Runtime: 128x128 opaque RGBA uncompressed TGA.
- Output: `Source/CreshChat_DungeonReward_FullBodyToken_Master.png`.

## Armour Choice Token

- Current role: shared SHARDS and ARMOUR reward icon.
- Concept: one class-neutral dark-steel breastplate with broad pauldrons over an amber shield medallion and a small cyan clasp.
- Colour behaviour: fixed dark steel/gold/amber/navy; no helmet, limbs, full character or copied armour set.
- Master: 1254x1254 opaque PNG.
- Runtime: 128x128 opaque RGBA uncompressed TGA.
- Output: `Source/CreshChat_DungeonReward_ArmourChoiceToken_Master.png`.

Runtime derivatives are saved separately in `RuntimeCandidate/` with matching role names and `_128.tga` suffixes. None is connected to Lua.
