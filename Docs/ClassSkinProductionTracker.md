# Class Skin Production Tracker

## Project

- Target: WoW TBC Anniversary
- Planned skins per class: 20
- Planned assets per skin: one full body and one icon
- Current production class: Warrior
- Started: 2026-06-30
- Current status: Source Review

## Class taxonomy audit

CreshChat currently defines eight base Dungeon Dwellers archetypes: Warrior, Paladin,
Ranger, Rogue, Priest, Defender, Mage, and Warlock. The requested tracker instead
lists Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock, and Druid.
Hunter/Ranger may be equivalent, but that mapping is not yet approved. Defender has
no requested row, while Shaman and Druid have armour-set artwork but no matching base
class definition in the current eight-class artwork set. No ambiguous mapping will be
used for production.

| Class/archetype | Current base artwork | Tracker mapping | Status |
| --- | --- | --- | --- |
| Warrior | OrcWarrior | Warrior | Source Review |
| Paladin | HumanPaladin | Paladin | Not Started |
| Ranger | ElfRanger | Hunter (unconfirmed) | Blocked on mapping |
| Rogue | UndeadRogue | Rogue | Not Started |
| Priest | HumanPriest | Priest | Not Started |
| Defender | DwarfDefender | None | Blocked on mapping |
| Mage | HumanMage | Mage | Not Started |
| Warlock | VoidWarlock | Warlock | Not Started |
| Shaman | No base-class pair found | Shaman | Blocked on source |
| Druid | No base-class pair found | Druid | Blocked on source |

## Warrior approved source pair

| Reference | Approved workspace copy | Original reworked source | Dimensions | Status |
| --- | --- | --- | ---: | --- |
| Full body | `Assets/Classes/Warrior/Source/Class_Warrior_Source_Full.png` | `ArtSource/TextureRemaster/Batch16/Source/CreshChat_DungeonBaseClass_OrcWarrior_FullBody_Master.png` | 1024x1024 | Located and visually reviewed |
| Icon | `Assets/Classes/Warrior/Source/Class_Warrior_Source_Icon.png` | `ArtSource/TextureRemaster/Batch02/Source/CreshChat_DungeonBaseClass_OrcWarrior_Master.png` | 1024x1024 | Located and visually reviewed |

Both references depict the same green orc warrior with black topknot, tusks,
brown-and-black plate/leather equipment, round shield, and axe. Older armour-tier
skins, previews, runtime candidates, and legacy class art are excluded as production
references.

## Warrior design lock

- Identity: heavily built orc frontline warrior.
- Weapon: one-handed axe; preserve its established size and hand.
- Off hand: round wooden shield with metal rim and boss.
- Armour: rugged plate-and-leather battlefield equipment.
- Preserve: topknot, tusks, broad shoulders, shield-and-axe silhouette, stance,
  viewing angle, body proportions, face, and restrained 8/16-bit pixel treatment.
- Avoid: changing race, weapon type, shield shape, pose, anatomy, modern materials,
  photorealism, excessive particles, or effects that obscure the silhouette.

## Warrior variant tracker

| No. | Skin | Full body | Icon | Pair | Addon | Status |
| ---: | --- | --- | --- | --- | --- | --- |
| 01 | Base | Reference approved | Reference approved | Matches | Not added | Source ready |
| 02 | Elite | Planned | Planned | Pending | Not added | Not Started |
| 03 | Battle-Worn | Planned | Planned | Pending | Not added | Not Started |
| 04 | Royal | Planned | Planned | Pending | Not added | Not Started |
| 05 | Shadow | Planned | Planned | Pending | Not added | Not Started |
| 06 | Holy | Planned | Planned | Pending | Not added | Not Started |
| 07 | Nature | Planned | Planned | Pending | Not added | Not Started |
| 08 | Arcane | Planned | Planned | Pending | Not added | Not Started |
| 09 | Fire | Planned | Planned | Pending | Not added | Not Started |
| 10 | Frost | Planned | Planned | Pending | Not added | Not Started |
| 11 | Fel | Planned | Planned | Pending | Not added | Not Started |
| 12 | Blood | Planned | Planned | Pending | Not added | Not Started |
| 13 | Spirit | Planned | Planned | Pending | Not added | Not Started |
| 14 | Desert | Planned | Planned | Pending | Not added | Not Started |
| 15 | Obsidian | Planned | Planned | Pending | Not added | Not Started |
| 16 | Emerald | Planned | Planned | Pending | Not added | Not Started |
| 17 | Void | Planned | Planned | Pending | Not added | Not Started |
| 18 | Ancient | Planned | Planned | Pending | Not added | Not Started |
| 19 | Champion | Planned | Planned | Pending | Not added | Not Started |
| 20 | Prestige | Planned | Planned | Pending | Not added | Not Started |

## Production gates

- Only the two approved files above may drive Warrior production.
- Generate matching full-body and icon pairs before approval.
- Keep source, generated variants, converted runtime files, and archive material separate.
- Do not register artwork or invent unlock rules during artwork production.
- Do not begin Paladin until Warrior reaches 20/20 approved pairs and passes implementation testing.

## Known issues

- Class taxonomy must be resolved before Ranger/Hunter, Defender, Shaman, or Druid production.
- In-game implementation and persistence are not tested.
- No Warrior variants have been generated yet.
