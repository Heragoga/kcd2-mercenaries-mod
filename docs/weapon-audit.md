# Weapon-preset audit

A debug lineup for the "some spawned NPCs have no weapon" bug. It spawns one NPC
per weapon preset in `data/libs/tables/item/weapon_preset__mercenaries.xml`,
arranged in numbered ranks, and checks each one's inventory for the items the
preset was supposed to give him.

Code: `data/Scripts/mods/mercenaries_weapon_audit.lua`.

## Commands

| Command | What it does |
| --- | --- |
| `merc_wpn_audit` | Spawns all 121 presets on a merc soul — a friendly lineup that just stands there |
| `merc_wpn_audit_p1` … `_p5` | Same, 24 presets at a time (1‑24, 25‑48, 49‑72, 73‑96, 97‑121) |
| `merc_wpn_audit_enemy` | All 121 on a bandit **enemy** soul — hostile, but the exact character the bug is reported on |
| `merc_wpn_audit_draw` | Makes the whole lineup draw, so an empty hand means something is really wrong |
| `merc_wpn_audit_who` | Names the lineup NPC you're standing next to and says whether his weapon landed |
| `merc_wpn_audit_report` | Re-checks the standing lineup, logs the unarmed and the empty-handed |
| `merc_wpn_audit_clear` | Despawns the lineup |
| `merc_wpn_audit_static` | No spawning: lists presets whose `item_class_id` is in no item table at all |

Rank 1 is nearest you, 12 per rank, numbered left to right. Entity names carry
the index and preset name (`MercWpnAudit_038_merc_weapon_axe_medium_2`), so
`merc_wpn_audit_who` is usually quicker than counting.

## Reading the log

Every NPC prints one line to `kcd.log`:

```
[WpnAudit] ok    #038 r4c2  merc_weapon_axe_medium_2   axeBearded=ok
[WpnAudit] FAIL  #061 r6c1  merc_weapon_swordshield_weak_3   swordShort=MISSING UNKNOWN_ITEM=MISSING(shield)
[WpnAudit] lineup: 121 spawned, 17 with no weapon in inventory.
```

`FAIL` means at least one **non-shield** item from the preset never reached the
inventory — a preset the engine did not honour. Shields are reported but never
counted as failures.

`HAND` means every item is present but nothing is being held. `FindItem` proves
only that the item reached the inventory; it does not prove the NPC is visibly
carrying it. Run `merc_wpn_audit_draw`, wait a few seconds for the draw
animation, then `merc_wpn_audit_report` — after a draw, `hand=EMPTY` is a real
defect, whereas before one it just means the weapon has no sheathed carry pose.

## Root cause: `IsQuestItem="true"` (fixed)

The lineup found 4 of 121 presets producing a man with a shield and no weapon.
Every missing item carried `IsQuestItem="true"` in `item.xml`. A quest-owned item
class resolves as an id, so nothing complains, but it is never handed out through
a weapon preset — the rest of the preset arrives and the weapon silently does not.

Scanning the presets for that one attribute reproduces the in-game result exactly,
same four presets, no others — so `IsQuestItem` is the whole story:

| # | Preset | Quest item removed | Replaced with |
| --- | --- | --- | --- |
| 073 | `merc_weapon_swordshield_medium_1` | `nemcuvPoklad_bejkovecShortSwordRusty` | `shortswordBroad` |
| 079 | `merc_weapon_swordshield_medium_3` | `nemcuvPoklad_bejkovecShortSwordRusty` | `shortswordBroad` |
| 083 | `merc_weapon_axeshield_weak_1` | `kovaniAsiDoVezi_protectiveAxe` | `axeWork01` |
| 098 | `merc_weapon_maceshield_weak_4` | `taboryLapkuTrosecko_plesnivecMace` | `maceZizka` |

The replacements keep each preset in its tier band: `shortswordBroad` is what
`swordshield_medium_2`/`_4` already use, `axeWork01` is the same model and the
same Attack 86 as the quest axe, `maceZizka` is the same model as the quest mace
(Attack 102 against 98).

Note the shield in #073 and #083 arrived fine, so this is per-item, not
per-preset: one bad member does **not** take the rest of the preset down with it.

**When adding a weapon preset, check the item is not `IsQuestItem="true"`** — it
is the one failure mode that produces no error anywhere.

## Second cause: polearms are invisible while sheathed

With the quest items replaced the lineup reports `121 spawned, 0 with no weapon`
and not one `hand=EMPTY`, before or after `merc_wpn_audit_draw` — every preset
puts a weapon in the NPC's hand slot. The polearm block (#045–#054) still *looks*
unarmed, because a sheathed polearm has nowhere to sit on the body and renders
nowhere until the NPC draws.

That is not a data defect, so it cannot be fixed in the preset. Polearms are
instead excluded from the "random" melee roll, which is what every enemy group
except the Ruthenians and the knights uses — so roughly one spawned enemy in
eight was reading as unarmed:

```lua
-- mercenaries_equipment.lua
mercenaries.RandomMeleeSetMin = 2
mercenaries.RandomMeleeSetMax = 8   -- 9 = polearm, excluded
```

Set the max back to `9` to put them in the roll again. `merc_weapon_polearm` and
an explicit `weapons = { 9 }` on an enemy group still hand polearms out on purpose.

## Not a problem: "UNKNOWN_ITEM"

Two shield ids used by the mod's `_3`/`_4` shield variants
(`310faab5-8502-47b2-adf8-22149d97d8b6`, `ff806e40-25fb-47de-934b-78c1bd97ef25`)
are in no item table under `references/`, so `merc_wpn_audit_static` flags them
and the lineup prints them as `UNKNOWN_ITEM`. They log `UNKNOWN_ITEM=ok` in game:
they resolve fine, and the `references/` dump is simply older than the build.
Treat `merc_wpn_audit_static` as a hint about the dump, not a verdict on the data.
