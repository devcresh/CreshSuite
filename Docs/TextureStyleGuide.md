# CreshChat Dungeon Dwellers Texture Style Guide

This guide covers original Dungeon Dwellers artwork. It does not authorize copying or closely reproducing Blizzard icons, logos, frames, faction marks, armour sets, characters or other copyrighted artwork. New assets should sit comfortably beside the TBC Anniversary client while remaining visibly CreshChat's own work.

The current library deliberately combines compact pixel-painted core characters with higher-detail painted expansion enemies, bosses, crates and rewards. Preserve those family identities. The remaster is a controlled consistency pass, not a mandate to repaint every texture in one style.

## Dungeon portrait pixel-art direction

- Base class, minion and enemy portrait replacements retain the established chunky 8-bit/16-bit feel.
- Build forms from hard square pixel clusters, a limited palette and sparse purposeful dithering. Do not use smooth painterly gradients, vector-clean curves, photorealistic rendering or post-resize sharpening noise.
- Use a near-black interior tile and the established thin rust-copper square frame for the portrait families that already carry it.
- Aim for an original TBC-era dungeon-adventure atmosphere through worn iron, leather, bone, torchlight and restrained magic colours. Do not reproduce Blizzard characters, creature designs, faction symbols, armour, logos or frames.
- Judge portraits first at 38-50 px. Eyes, face opening and one class/archetype cue must survive at that size.
- Class armour/unlock skins remain outside the base-texture remaster and must not leak into canonical portraits.

## Shape language

- Lead with one clear silhouette before internal detail.
- Small icons should use broad medallions, crystals, pouches, armour plates, dice and tokens rather than thin filigree.
- Use softened bevels, clipped corners and shallow fantasy points. Avoid hair-thin spikes that alias below 40 px.
- Reward icons should contain one focal object and at most one subordinate support form.
- Character and enemy art may be more complex, but weapons, limbs and silhouettes must stay inside safe margins.
- Prefer recognition without text. Do not bake names, tiers or numbers into art unless a later design explicitly requires them.

## Border style

- Batch 01 reward icons use a thin, even inset octagonal antique-gold rim over a dark enamel tile.
- At 128 px, the outer rim should occupy roughly 5-8 px per edge. It is a frame, not the focal subject.
- Keep border thickness and corner cuts consistent across a family.
- Do not add a baked tile border to transparent portraits, full-body figures, crates or dice unless the whole family is deliberately redesigned around one.

## Lighting and surface treatment

- Standard light direction: warm upper-left key light, cool lower-right rim light, deep navy shadow.
- Painted materials should read as worn brass, dark steel, leather, enamel, crystal, stone or cloth—not glossy product rendering.
- Use a few broad scratches, brush marks or chips instead of high-frequency noise.
- Saturated magic glows should stay narrow. Large bloom merges at 28-50 px and becomes a coloured blob.
- Keep metal highlights warm and controlled so theme-coloured UI chrome remains distinct.

## Composition and icon padding

- Keep small-icon focal content within the central 76% of the master, leaving about 12% safe padding on all sides.
- Reward subjects should fill about 56-64% of a square canvas.
- Keep faces, gems, coin seals, weapon tips and shoulders away from the border.
- Preserve each runtime aspect ratio. Never stretch square source art into full-body holders or vice versa.
- Compose full-body art for the current 1:2 source contract while checking the actual 110x160 hero and 110x196 enemy holders.

## Alpha edges

- All current in-scope TGAs carry 8-bit alpha; 147 use visible transparency.
- Export clean antialiasing with no black/white matte, halos, pinholes or semi-transparent background noise.
- Preserve useful edge colour in transparent pixels. Test over black, white, neutral grey, red enemy panels and green hero panels.
- The renderer may stack one or two duplicate `BLEND` layers to strengthen opacity. Inspect edges in that stacked state; a faint fringe can become conspicuous.
- Opaque tiles may keep a fully opaque alpha channel to match the project's 32-bit TGA convention.

## Contrast and small-size readability

- Reward icons: test at 36x36, the visible area of the current 40x40 reward frame.
- Dice: test at 28x28, the visible area of the current 32x32 die frame.
- Portrait/enemy icons: test from 38x38 through 50x50.
- Full-body art: test at 110x160 and 110x196.
- Reserve the brightest 10-15% of the value range for the focal gem, eye, coin edge or magic core.
- Limit small-icon focal content to roughly three hue families.
- If detail disappears at runtime size, simplify or enlarge it; sharpening noise is not a substitute for hierarchy.
- Test locked/desaturated states and the foe die's `(1.00, 0.82, 0.82)` vertex tint.

## Recommended master and runtime sizes

Keep existing runtime contracts unless a later task explicitly changes code and layout.

| Asset family | Recommended editable master | Current runtime export | Current visible/UI size |
|---|---:|---:|---:|
| Reward icon | 1024x1024 or larger square | 128x128 TGA | 36x36 reward card; collection varies |
| Die face/status | 1024x1024 | 128x128 TGA | 28x28 |
| Portrait/enemy/boss icon | 1024x1024 | 128x128 TGA | 38-50 px square |
| Crate | 1024x1024 | 256x256 TGA | about 152x154; sometimes 40x40 fallback badge |
| Milestone chest display | 2048x2048 | 512x512 TGA | about 152x154 |
| Milestone chest icon | 1024x1024 | 128x128 TGA | about 40x40 |
| Full-body character/enemy | 1024x2048 | 256x512 TGA | 110x160 or 110x196 |

Batch 01 generator masters are 1254x1254 opaque PNGs. Retain them losslessly and derive the 128 px runtime candidate once. The Full-Body Token master had only its generated white outer canvas cropped away before resizing; the painted tile itself was not redrawn.

## Runtime export rules

- Existing successful format: 32-bit, uncompressed TGA with 8 bits per channel.
- Preserve power-of-two dimensions; every current Dungeon Dwellers texture does so.
- PNG is suitable for source masters and previews, but no in-scope Lua path loads local PNG runtime art.
- Do not introduce BLP, JPEG, WebP, compression changes or a new converter pipeline without a separate client-compatibility review.
- Decode and inspect every export before testing. Confirm width, height, RGBA channels, opacity/transparency and uncompressed image type.
- Keep candidates disconnected. Do not overwrite or rename live files until a separately approved integration task.

## Naming conventions

- Source master: `CreshChat_Dungeon<Family>_<Role>_Master.png`
- Runtime candidate: `CreshChat_Dungeon<Family>_<Role>_<Width>.tga`
- Preview: `BatchNN_Dungeon<Family>_<Purpose>.png`
- Preserve established role spelling from Lua, including `CreshCoinCache`, `FullBodyToken` and `ArmourChoiceToken`.
- Use PascalCase roles, underscores between structural parts, two-digit batch numbers, and no spaces/version strings in runtime candidate names.

## Folder conventions

```text
ArtSource/TextureRemaster/
├── BatchNN/
│   ├── Source/            # lossless editable/generated masters
│   ├── Preview/           # labelled comparisons and reviews
│   └── RuntimeCandidate/  # disconnected TGA exports
└── Reference/             # CreshChat-authored notes only
```

Live art stays under `Media/Games/DungeonDwellers/` until integration is explicitly approved.

## Theme colouring

- Use dark neutral fields, antique gold, dark steel, ivory and controlled gem colours so art remains readable against CreshChat's many themes.
- Theme-reactive chrome should remain code-drawn; do not export one texture per colour theme.
- Check fixed-colour art against Cresh Minimal, a cyan/blue theme and Classic Bronze/WoW Classic.
- Maintain family colour cues: gold/cyan currency, red/orange damage, violet portrait, sapphire full-body and dark-steel/amber armour.

## Tintable versus fixed-colour textures

May be tinted or desaturated by current Lua:

- Dice, especially the foe die's pale-red vertex tint.
- Locked collection entries at 50% vertex colour and optional desaturation.
- Defeated enemy icon/full-body art via desaturation and holder alpha.
- Monochrome future masks designed specifically for tinting.

Requires fixed colours:

- Batch 01 reward icons in normal unlocked state.
- Painted portraits, enemies, bosses, full-body characters, crates and milestone chests.
- Any multi-colour illustration whose material and reward identity depends on its palette.

Do not apply arbitrary theme tint to painted art. State changes should use the existing locked/dead desaturation paths.

## Review gate

An asset is eligible for live integration only after the source, runtime export, contact sheet and actual-size preview are inspected, followed by in-game testing. Verify the exact path, alpha edges, duplicate opacity layers, tint/desaturation states, UI scale, panel theme, aspect ratio and memory behaviour. Offline inspection is not proof that the TBC Anniversary client rendered the asset correctly.
