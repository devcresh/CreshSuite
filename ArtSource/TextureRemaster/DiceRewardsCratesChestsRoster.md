# Dice, Rewards, Crates and Milestone Chests

This pass provides disconnected pixel-art candidates for every Dungeon Dwellers die, reward icon, crate and milestone chest. Existing runtime textures and code paths remain unchanged.

## Completion summary

- Dice: 9 of 9
- Reward icons: 5 of 5
- Crates: 4 of 4
- Milestone chest displays: 5 of 5
- Milestone chest icons: 5 of 5
- Runtime candidates: 28
- Generated source masters: 23; each milestone icon is derived from its matching display master
- QA overview: `Batch14/Preview/DiceRewardsCratesChests_AllCandidates_QA.png`

## Dice

- Batch 10: `CreshChat_DungeonDie_Dice1.tga` through `CreshChat_DungeonDie_Dice5.tga`
- Batch 11: `CreshChat_DungeonDie_Dice6.tga` through `CreshChat_DungeonDie_Dice8.tga`
- Batch 11: `CreshChat_DungeonDie_DiceWeb.tga`
- Runtime contract: 128x128 uncompressed 32-bit RGBA TGA; designed for the current 28x28 visible area.

## Reward icons

Batch 12 contains corrected pixel-art replacements for:

- `CreshChat_DungeonReward_CreshCoinCache_Pixel.tga`
- `CreshChat_DungeonReward_DamageRelic_Pixel.tga`
- `CreshChat_DungeonReward_PortraitToken_Pixel.tga`
- `CreshChat_DungeonReward_FullBodyToken_Pixel.tga`
- `CreshChat_DungeonReward_ArmourChoiceToken_Pixel.tga`

These supersede the smoother Batch 01 candidate concepts. Batch 01 remains preserved for comparison and was not overwritten.

## Crates

Batch 13 contains:

- `CreshChat_DungeonCrate_AdventurersCache.tga`
- `CreshChat_DungeonCrate_RoyalVanguardChest.tga`
- `CreshChat_DungeonCrate_VoidlordReliquary.tga`
- `CreshChat_DungeonCrate_WarboundStrongbox.tga`
- Runtime contract: 256x256 uncompressed 32-bit RGBA TGA.

## Milestone chests

Batch 14 contains matching display and icon candidates for levels 20, 40, 60, 80 and 100:

- `RuntimeCandidate/Display/CreshChat_DungeonMilestoneChest_LNN_Display.tga` at 512x512
- `RuntimeCandidate/Icons/CreshChat_DungeonMilestoneChest_LNN_Icon.tga` at 128x128

Each pair is exported from one 1024x1024 master so the popup and collection icon cannot drift into different designs.

## Review state

All 28 runtime candidates decoded successfully with RGBA channels and the expected power-of-two dimensions. A pixel scan found no residual high-red/high-blue chroma-key pixels. Dice pip counts were visually inspected at source size and in the 96px QA sheet. Offline review is complete; no candidate has been connected to or tested inside WoW.
