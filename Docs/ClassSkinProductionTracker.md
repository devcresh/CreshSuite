gi# Class Skin Production Tracker

## Project contract

- Target: World of Warcraft TBC Anniversary
- Established artwork: current reworked full-body and icon references only
- Runtime targets: full body 256x512 RGBA TGA; icon 128x128 RGBA TGA
- Skins per class: 20
- Assets per class: 40
- Active class: Warrior
- Started: 2026-06-30
- Status: Full Bodies and Icons In Progress

## Actual CreshChat class roster

The addon currently has eight Dungeon Dwellers base archetypes. This tracker uses
their real internal artwork identities rather than adding unsupported classes.

| Class | Base identity | Source pair | Completed pairs | Review | Implementation | Status |
| --- | --- | --- | ---: | --- | --- | --- |
| Warrior | OrcWarrior | Found | 2/20 | In progress | Not started | In Progress |
| Paladin | HumanPaladin | Found | 0/20 | Pending | Not started | Not Started |
| Ranger | ElfRanger | Found | 0/20 | Pending | Not started | Not Started |
| Rogue | UndeadRogue | Found | 0/20 | Pending | Not started | Not Started |
| Priest | HumanPriest | Found | 0/20 | Pending | Not started | Not Started |
| Defender | DwarfDefender | Found | 0/20 | Pending | Not started | Not Started |
| Mage | HumanMage | Found | 0/20 | Pending | Not started | Not Started |
| Warlock | VoidWarlock | Found | 0/20 | Pending | Not started | Not Started |

Shaman and Druid armour-set folders are not base-class definitions. Hunter maps to
the existing Ranger concept only if explicitly approved later. They are therefore
not silently treated as production classes.

## Warrior approved references

| Type | Approved reference |
| --- | --- |
| Full body | `Assets/Classes/Warrior/Source/Class_Warrior_Source_Full.png` |
| Icon | `Assets/Classes/Warrior/Source/Class_Warrior_Source_Icon.png` |

Identity lock: green orc, black topknot and beard, tusks, muscular proportions,
one-handed axe, round wooden shield, rugged plate/leather layout, established stance,
viewing angle, silhouette, and painted 8/16-bit pixel treatment.

## Warrior skin progress

| No. | Skin | Full | Icon | Pair | Runtime conversion | Addon | Status |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 01 | Base | Complete | Complete | Matches | Complete | Not added | Review Ready |
| 02 | Elite | Complete | Complete | Matches | Complete | Not added | Review Ready |
| 03 | Battle-Worn | Planned | Planned | Pending | Pending | Not added | Next |
| 04 | Royal | Planned | Planned | Pending | Pending | Not added | Planned |
| 05 | Shadow | Planned | Planned | Pending | Pending | Not added | Planned |
| 06 | Holy | Planned | Planned | Pending | Pending | Not added | Planned |
| 07 | Nature | Planned | Planned | Pending | Pending | Not added | Planned |
| 08 | Arcane | Planned | Planned | Pending | Pending | Not added | Planned |
| 09 | Fire | Planned | Planned | Pending | Pending | Not added | Planned |
| 10 | Frost | Planned | Planned | Pending | Pending | Not added | Planned |
| 11 | Fel | Planned | Planned | Pending | Pending | Not added | Planned |
| 12 | Blood | Planned | Planned | Pending | Pending | Not added | Planned |
| 13 | Spirit | Planned | Planned | Pending | Pending | Not added | Planned |
| 14 | Desert | Planned | Planned | Pending | Pending | Not added | Planned |
| 15 | Obsidian | Planned | Planned | Pending | Pending | Not added | Planned |
| 16 | Emerald | Planned | Planned | Pending | Pending | Not added | Planned |
| 17 | Void | Planned | Planned | Pending | Pending | Not added | Planned |
| 18 | Ancient | Planned | Planned | Pending | Pending | Not added | Planned |
| 19 | Champion | Planned | Planned | Pending | Pending | Not added | Planned |
| 20 | Prestige | Planned | Planned | Pending | Pending | Not added | Planned |

## Production gate

Do not begin Paladin until Warrior reaches 20/20 approved matching pairs, naming and
folder validation, runtime registration, and user-confirmed in-game testing. Artwork
production does not invent unlock rules or alter gameplay data.
