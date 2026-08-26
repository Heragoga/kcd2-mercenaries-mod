# Custom companions

44 named companions, each one a clone of a vanilla character: its head, hair and beard,
its `skald_character` row — so the name and the voice come from the base game for free —
and its gear. `mercenaries.CustomCompanionsData` maps a companion id to a soul GUID, a
price and a display name; `HireCustomCompanion` spawns it.

**The roster is generated.** [`tools/companions_roster.py`](../tools/companions_roster.py)
is the single source of truth and
[`tools/gen_companions.py`](../tools/gen_companions.py) writes it into all thirteen
places it has to exist. Edit the roster, re-run the generator, done:

```
python tools/gen_companions.py            # write
python tools/gen_companions.py --check    # report only, touch nothing
```

Every target file gets one sentinel-delimited block that is rewritten in place, so
running it twice is a no-op. **Do not hand-edit inside those blocks** — the next run
overwrites them.

```
python tools/check_companions.py
```

checks the result afterwards: XML well-formedness, guid shape and uniqueness, that every
port has a trigger and a quest node in all four dialogue files, that every dialogue
string is localised, that no closable visor survives anywhere, that the bare-headed four
really are, and that each of the hero exemptions is still wired.

## What a companion needs

| File | What lands there |
|---|---|
| `rpg/soul__mercenaries.xml` | the soul: own `soul_id`, merc brain, `mercenariesFaction` |
| `skald/skald_character__mercenaries.xml` | the character, copied off the vanilla row |
| `skald/skald_character2profession__mercenaries.xml` | `pocestny` |
| `skald/skald_character2role__mercenaries.xml` | `role_mercenary_test` and `_test2` |
| `Storm/appearance/mercenariesappearance.xml` | head / hair / beard / body, keyed `hasName` on the soul |
| `Storm/equipment/mercenariesequipment.xml` | `setInventory preset="inventory_merc_<key>"` |
| `Storm/roles/mercenariesroles.xml` | the two roles again, this time on the soul |
| `item/InventoryPreset__mercenaries.xml` | clothing preset + weapon preset + pockets |
| `item/clothing_preset__mercenaries.xml` | only for a **built** kit — see below |
| `item/weapon_preset__mercenaries.xml` | only for a **built** loadout |
| `mercenaries.lua` | the `CustomCompanionsData` row |
| `…/mercenaries_background_quest.xml` ×2 | two `CreatePlayerReward` nodes, one per dialogue; **Amount is the companion id** |
| `…/hire_dialog.xml` ×2 | an out-port and a `Sequence` in the right category menu |
| `…/quartermaster_dialog.xml` ×2 | the same again — the quartermaster hires the same 44 |
| `localization/*_xml.xml` ×16 | `ui_mercenary_custom_<key>`, `merc_henry_<key>`, `merc_provider_<key>` |

The quest and dialog files exist **twice**, once under `kutnohorsko` and once under
`trosecko`; they are hand-mirrored copies, so the generator writes both.

## Vanilla, or built

`cloth` and `weap` in the roster each take one of two forms:

- `V("UC_HanushBattle")` — wear a preset that already exists in vanilla, untouched. This
  is the ideal: an exact clone, nothing new authored.
- `B(base, drop, add)` / `W(items…)` — build one. `base` is a vanilla preset to start
  from (or `None` for nothing), `drop` names pieces to remove and `add` names pieces to
  put on. Used where the character has no fightable kit anywhere in the game — Sigismund
  is only ever dressed for court, Musa wears a coat and a cap, Martin is in a smith's
  tunic — and for the Painter, whose kit is invented outright.

The generator prints the resolved defence total of every built preset, so a kit that
lands in the wrong tier is visible without launching the game. For reference the squad's
own budgets are weak 600, medium 1300, strong 1850 (see [outfits.md](outfits.md)).

## Helmets

**No closable visors.** A companion fights with his face shut, which reads wrong and
hides the very head the clone exists for. Every visored bascinet in the roster is
swapped for an open one of similar defence — `BascinetOpen03_m01_C4` (293) or
`BascinetOpen08_m01_B3` (272) against a visored 284–301, so the armour budget barely
moves. Radzig needs no swap: his own preset already carries the `mNoVisor` variant.

Four go bare-headed on purpose — **Aulitz, Sigismund, the Chamberlain and Henry's
father Martin**. Aulitz drops to his plain `UC_Aulitz` preset, which has no helmet in it
at all; the other three simply do not get one added.

## Martin, and being immortal

Martin wears **no armour whatsoever** — his own `UC_Father` preset and nothing else: his
cap, tunic, hose and boots, thirty points of defence across the lot, all of it cosmetic.
He is a blacksmith in his shirtsleeves, not a soldier.

Which is why he is **immortal**. `soul_vip_class` is a bitfield —
1 pickpocket, 2 attack, 4 immortality, 8 unconsciousness, 16 loot — and only the
combinations named in `references/Libs/Tables/rpg/soul_vip_class.xml` are declared, so
pick from those rather than adding bits together. Companions default to **16**
(`loot_protection`): the player should not be able to strip his own men. Martin gets
**12** (`immortality_and_unconsciousness_protection`), the same class the quartermaster
and Aleksej carry. Losing loot protection costs nothing — a man who can never die or be
knocked out never becomes lootable.

Any roster entry can override it with `vip=`. The generator validates the value against
the declared list and says in its report whenever an entry departs from the default.

Dropping a helmet means dropping the padded coif with it where the coif was only there
to satisfy `RequiresFilledSlot` on `head_helmet` — but *not* where the character wears
one in his own right (Martin keeps his mail coif). And with no helmet the
cap-under-helmet rule stops applying, so the Chamberlain keeps his own cap.

## They are mercenaries

A companion is spawned as **`SpawnedFriend_hero_<soul>_<n>`**, not under a prefix of his
own. That is deliberate and it is the archers' trick: `SpawnedFriend_` is what every
squad system keys on, so a companion gets the camp, the look-at prompts, formations,
orders, the straggler sweep, the LOD boost and the rest **for free**, instead of each of
those needing a second prefix added to its list. Under the old
`MercenaryCustomCompanion_` name most of them simply did not see him.

`_hero_` then marks the only three things he must not share, all via
`mercenaries:IsHeroName`:

| | Why |
|---|---|
| `EquipMercenary` / `EquipMercenaryWeapon` return early | he wears what his own character wears; the squad's livery is not his |
| `GearWantsCustom` returns false | the player's custom uniform is not his either |
| `RequestBark` and the camp-chat pairing skip him | **he never talks** |

**Never talks** is the whole rule. The order barks and the camp gossip pool are written
for anonymous sellswords and are played on the soul's own voice, so putting one in
Zizka's mouth is worse than silence. `RequestBark` is the single queue every order bark
goes through and `CampChatTick` is the single place conversations are paired, so one
check in each covers all of it. He still sits, eats, takes a bed and does everything
else a camping merc does.

`IsHeroName` also matches the old `MercenaryCustomCompanion` prefix, so companions in
saves taken before the rename keep working.

One consequence worth knowing: `IsOwnSoulId` is built from the `Souls` tables, and a
companion is not in them — each has his own soul. Target selection recognises him **by
name**, so a name change that misses that check makes the squad treat its own
companions as valid targets.

## The three traps

**A quest item in a weapon preset arms nobody.** `longswordRadzig` exists as an item and
is exactly what Radzig should carry — and it is flagged `IsQuestItem`, so a preset
containing it leaves him bare-handed, silently. He uses his own vanilla `UC_Radzig`
preset instead. Check any hand-picked weapon against `IsQuestItem` before using it.

**A sheathed polearm does not render.** Samuel's `UC_Samuel_battleM44b` loadout carries
one, which would make him read as unarmed until he drew it. He gets `UC_Samuel_battleM48c`
instead. Same reason polearms are out of the squad's random weapon roll.

**Copying `body_type` off the vanilla row can make the NPC invisible.** A body type the
mod does not already ship can pair with a `unique_assets` index belonging to the
character's own quest, and that index cannot travel. The generator clamps to `{0, 2, 3, 4}`
and says so in its report when it does.

## The hire menu

There are **two** hiring menus and both carry the full roster: the provider's
`hire_dialog` and the quartermaster's own `quartermaster_dialog`. They differ only in
which role speaks the second half of each line — `role_mercenary_provider` against
`role_mercenary_quartermaster` — and each has its own port set and its own family of
quest reward nodes (`execute_recruit_<key>` against `exec_qm_hire_c<id>`). Four files in
all, once per region.

44 options do not fit in one list, so the custom-companion `Decision` holds five
sub-menus and each of those holds its own companions plus a back option:

| Menu | Who |
|---|---|
| Lords and knights | Radzig, Hanush, Erik, Aulitz, Jobst, Bergov, Vávák, Ruthard, Samuel, Oderin, Istvan, the Chamberlain |
| Crowns and courts | Sigismund, Lichtenstein, Brabant, Musa, Zacharias, Capon |
| Zizka's company | Zizka, the Devil, Godwin, Kubenka, Adder, Janosh, Hertl, Pelcl, Marek, Cverk, Volek |
| Skalitz and old friends | Martin, Janek, Jaroslav, Vasko, Black Bartosch, Arne |
| Rogues and freeriders | Gnarly, Jasak, Jan Posy, Miroslav, Menhard, Mathew, Boček, Petr of Písek, the Painter |

Membership is the `cat` field on each roster entry, and the existing 18 are listed in
`EXISTING` purely so they can be sorted into the same menus — nothing else about them is
generated.

**The menu is replaced as a whole element, anchored on `seq_type_cancel`.** Matching the
first `</Sequences></Decision>` instead does not work: the category sub-menus are
themselves `Decision`s, so that close belongs to the *first category*, and replacing
there appends a second copy of every later category rather than replacing them. That
produced a malformed dialog once already.

## Seeing them

`merc_cc_lineup` spawns one NPC per companion in rows in front of the player — free, not
squad members, not counted against `MaxCompanions`. `merc_cc_who` names the one you are
standing next to, `merc_cc_draw` makes them draw, `merc_cc_clear` despawns them. It reads
`CustomCompanionsData`, so it always covers whatever the roster currently holds.

## Localisation

English gets real text; the other fifteen files get the English string in both cells, the
same convention the rest of the mod uses. `tools/Translate.py` fills them in from
`English_xml.xml` afterwards.

## DLC faces

The Painter (`m_head_painter`) and Zacharias (`m_head_zachary`) come from DLC. If the
player does not own it those heads resolve to nothing and the NPC spawns but does not
render — the same failure mode as the `body_type` trap. Nothing gates them at present.
