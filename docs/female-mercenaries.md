# Female mercenaries: what the game actually supports

2026-09-06. Every claim below was read out of the shipped game data (`Data/*.pak` under the
Steam install) or out of `references/rose_of_bohemia_main`; nothing is inferred from how KCD1
worked or from what a mod page says.

The question was whether the Rose of Bohemia head swap can be turned into female soldiers.
The short answer: **Rose's technique gives you female faces, and only faces. It cannot give
you female soldiers, and neither can the game's own female pipeline — for a different and
much harder reason.** The two are worth separating because they fail in different places.

The research sections come first; what was actually built — `merc_hire_female`, female heads
and hair lifted onto male bodies — is under
[What was built](#what-was-built-merc_hire_female), along with what has been seen working and
what has not.

## What Rose of Bohemia actually does

A byte-level diff of all 308 loose files in the mod against the vanilla paks
(`references/rose_of_bohemia_main` vs `Data/*.pak`): 237 identical, 27 modified, 44 new.

Everything meaningful is a **file replacement at a fixed vanilla path**:

| path | vanilla | mod |
|---|---:|---:|
| `humans/male/head/m_head_henry/m_head_henry.skin` | 2 088 692 | 2 263 752 |
| `.../m_head_henry_LOD1.skin` | 1 157 260 | 2 263 752 |
| `.../m_head_henry_LOD2.skin` | 789 788 | 2 263 752 |
| `.../m_head_henry_poses.xml` | 928 415 | 2 884 453 |
| `humans/male/head/henry/henry_head_poses.xml` | 618 343 | 2 884 429 |
| `humans/male/hair/m_hair_henry/m_hair_henry.skin` | 1 538 168 | 2 042 444 |

plus six material files, 12 replaced and 38 new `.dds`. The only new table is
`Libs/Tables/Character/CharacterComponent__rose_of_bohemia_main.xml`, which re-declares
`m_hair_henry` under `<Component Name="Male">` → `Hair` purely to attach hair-physics
`JointElement`s (`f_hair_rose_01`, `hair_strand_rose_l_01`, …).

Three things follow from that table:

1. **The head skeleton is untouched.** `henry_head.chr` ships in the mod but is
   byte-identical to vanilla (223 400 bytes, identical string set). The female head mesh was
   retargeted onto Henry's existing head rig — a Blender job, not an engine change.
2. **The body is untouched.** No body mesh, no body texture, no skeleton. Rose is a male
   body with a female head and long hair. Male armour, male animations, male skeleton, male
   everything below the neck.
3. **The override is global and path-keyed.** It replaces `m_head_henry`, so it applies to
   every character that uses `m_head_henry` — which is Henry alone. There is no selector, no
   soul, no rule. You cannot make *some* NPCs use it and not others.

The LOD shortcut is worth noting since we'd inherit it: LOD1 and LOD2 are byte-identical
copies of the full-detail mesh, so Rose's head never drops detail with distance. On one
player character that is invisible. On fifty mercs in Kuttenberg it is exactly the class of
thing [npc-lod.md](npc-lod.md) and [performance.md](performance.md) exist to fight.

## The game's own female pipeline exists, and it is a civilian pipeline

The engine has full first-class female support. It is not a hack we would be inventing:

- `Libs/Tables/rpg/soul_archetype.xml` — `soul_archetype_id="1"` is `NPC_Female`,
  `gender_id="2"`. Our souls in `data/libs/tables/rpg/soul__mercenaries.xml` all carry
  `soul_archetype_id="0"` (`NPC`, `gender_id="1"`).
- `Scripts/Entities/AI/NPC_Female.lua` is a real entity class, sibling to `NPC`:
  `fileModel = "Objects/Characters/humans/female/skeleton/female.cdf"`,
  `esClothingConfig = "female2"`, `defaultSoulArchetype = "NPC_Female"`.
- Storm has the selectors already: `Libs/Storm/appearance/common/bodies.xml` and
  `heads.xml` carry `<isWoman/>` rules that hand out `f_body*` and `f_head_0*`.
- 986 of the game's 7 200-odd souls are archetype 1. 214 of 1 162 `skald_character` rows are
  `gender="1"` with their own `voice_id`s, so voice is a solved problem.

So the *plumbing* is a two-line change: `soul_archetype_id="1"` in our soul table, and
`class = "NPC_Female"` at the 22 `SpawnEntity` sites (13 files) that currently pass
`class = "NPC"`. That part is genuinely easy.

Then it walks into a wall.

### There is no female armour in the game

Counting `.skin` files under `humans/<gender>/clothing/` across every pak:

| | female | male |
|---|---:|---:|
| clothing meshes | **205** | 1 577 |

The female 205, by category: 122 dresses, 39 caps, 21 headcovers, 6 hoods, 6 shoes, 3
"other" head, 7 bathrobes, 1 chastity belt. The male 1 577 include 66 plate, 42 leg armour,
33 arm armour, 27 gauntlets, 111 helmets, 39 coifs, 54 hose, 57 boots, 54 scabbards.

`CharacterComponent.xml` agrees. The `<Component Name="Female">` subtree is 6 489 lines with
**10** `ArmorType`s — `F_Bonnet`, `F_CapAndWimple`, `F_Hat`, `F_Hood`, `F_HoodOpen`,
`F_Shoes`, `F_SimpleDress`, `F_Veil`, `F_VeilAndWimple`, `TunicLong` — and only three
clothing slots (Head, Torso, Legs). The `<Component Name="Male">` subtree is 44 000 lines
with **48** `ArmorType`s and the full slot set including arms, hands, feet and scabbard.

Our gear tables ([custom-gear.md](custom-gear.md), `mercenaries_gear_data.lua`,
`clothing_preset__mercenaries.xml`) are male item IDs throughout. Handed to a female body
they resolve to nothing in the Female tree: the merc turns up in the `female2` default
(`female_body`, `f_head_000`, a dress) or in underwear.

### There is no female combat, at any layer

This is the harder one, and it is not a content gap we could paper over with meshes.

**Animation sets.** 50 female `.dba` files against 274 male. The female list is
`female_baker`, `female_embroidery`, `female_hoeing`, `female_sweeping`, `female_tailor`,
`female_housekeeper`… There is no `female_combat.dba`, no `female_weapon.dba`, no
`female_bow.dba`. The male set has `male_combat.dba`, `male_combat_v2.dba`, `male_weapon.dba`,
`male_bow.dba`, `male_battle.dba` and sixteen weapon-idle sets. The only female file with a
fight in its name is `female_pogrom_trackview_fightbehindwagon.dba` — a scripted trackview.

`female.chrparams` binds `Animations\humans\female\*.dba` and nothing else, so the male
combat databases are not merely unused by female characters, they are not in the female
animation set at all.

**Mannequin.** `NPC_Female` runs `wh_female_controllerdefs.xml` /
`wh_female_database.adb`; `NPC` runs `kcd_male_controllerdefs.xml` /
`kcd_male_database.adb`. `kcd_male_fragmentids.xml` declares 2 215 fragment IDs, 202 of them
combat (`CombatAttack`, `CombatBlockPerfect`, `CombatAttackRiposteGen`,
`CombatClinchGuardMaster`, `CombatDodge`, `CombatDrawWeapon`, …). `wh_female_fragmentids.xml`
declares 846 and **zero** real combat fragments — the only combat-shaped names in it are
`CombatStealthClinchSlave`, `CombatStealthGrabSlave`, `Quest_AttackOnFemale*`: the *receiving*
side of a scripted assault. A female NPC entering combat has no state machine to run.

**Skeleton.** `female.chr` and `male.chr` are close but not equal. Female *has* the weapon
sockets — `RightWeaponSlot`, `LeftWeaponSlot`, `LeftWeaponSheath`, `RightWeaponRoot`,
`scabbardRoot`, `BackSlot_bow/crossbow/quiver/shield`. Female *lacks*
`LeftWeaponEnd`, `LeftWeaponSecondaryBelt`, `LeftWeapon_IKBlend`, `LeftWeapon_IKTarget`,
`LeftElbow`, `RightElbow`, `LeftKnee`, `RightKnee` — the joints the combat IK drives.
(Method: ASCII string extraction from the two binary `.chr` files, so treat it as strong
evidence rather than a proof; the named joints are unambiguous, the absence of others is
inference from their absence in the string table.)

**The data confirms the intent.** Of the 986 female souls in the game, 972 have
`combat_level="0"`. The highest is 0.7, on `malovanoJest_noblewoman`. Nobody at Warhorse ever
shipped a woman who fights.

So: a `NPC_Female` merc would spawn correctly, walk, talk, follow orders, and then stand
inert the moment a fight started — with no armour on and no weapon animation to draw one.

## What is actually feasible

**Female-presenting mercs on male bodies.** Rose's technique, redone selectively. Everything
below the neck stays male, so armour, combat, formations, `mercenaries_formation.lua`,
target selection and the whole mod work untouched.

The one thing Rose does that we must *not* copy is the global path override. Instead, our
own `Libs/Tables/Character/CharacterComponent__mercenaries.xml` would add new named
components alongside the vanilla ones — the same merge Rose already proves works:

```xml
<Head Name="m_head_merc_f01" FilePath="humans/male/head/m_head_merc_f01">
  <Elements>
    <SkinElement EquipmentPart="face" Model="m_head_merc_f01.skin" Material="m_head_merc_f01_m01.mtl" />
  </Elements>
</Head>
```

matching the vanilla shape of `m_head_081` exactly, plus a hair entry under `Male` → `Hair`.
The 109 rules in `data/libs/Storm/appearance/mercenariesappearance.xml` are already keyed by
`soul_name` (`<hasName Name="soul_merc_weak_1"/>`), so pointing a subset of souls at the new
head is a `setHead` / `setHair` edit and nothing more — no Lua, no spawn change, no save
implications.

The cost is entirely art, and it is real: each face needs a female head mesh retargeted onto
the generic male head rig, its own `_poses.xml` morph set (Rose's is 2.9 MB), materials, and
DDS set — and unlike Rose we would need proper LOD1/LOD2 for it, because these are fifty NPCs
in a town, not one player character. Beards must be forced off. The result is a male
silhouette with a female face: whether that reads as "female soldier" or as "man with a
woman's face" is an art judgement I can't make from the data, and is the thing worth
prototyping on one head before committing to a set.

## What was built: female mercenaries as their own category

They are a category of their own, alongside the archers and the custom companions — not a
flavour of the melee tiers. `data/Scripts/mods/mercenaries_female.lua`.

    merc_hire_female [count]          console, count defaults to 5
    "Women."                          on the hire menu and the quartermaster's, 1 / 3 / 5 / 10
    100 groschen a head               what a medium man costs

Entity names are `SpawnedFriend_female_medium_<rand>_<soulGuid>` — the archers' shape
(`SpawnedFriend_archer_medium_…`) and for the same reason. The mod reads a merc's tier out of
his name with a plain `string.find(name, '_medium_')` — twice in `mercenaries_equipment.lua`,
once each in `custom_gear` and `util` — so keeping the tier in the name means camp housing,
upkeep, difficulty scaling, formations and the roster all resolve them without knowing this
category exists.

Four things differ, and nothing else does.

### 1. Their own wardrobe, exempt from the squad's outfit style

`tools/gen_female_gear.py` takes the ten style-1 medium presets, drops every item in a head
slot (34 helmet, 33 cap, 32 padded coif, 31 coif, 23 hood) and writes the rest back as ten new
presets. Style `0f` is not a real style, which is the point: nothing in `mercenaries.Outfits`
can reach them, so `ChangeMercOutfit` cannot put a helmet back on. The exemption itself is one
branch at the top of `EquipMercenary`, next to the one custom companions already use — that
function is the single place every dressing path goes through (hire, outfit change, roster
rebuild after a load or a stow, custom uniform).

**Slot resolution reads the mod's own `mercenaries_gear_data.lua`** rather than re-deriving
slots from the vanilla tables, because `gen_gear_table.py` already does that derivation
properly — over every `item*.xml` and the armour mods too.

That matters because parsing those tables naively is a trap this script fell into once. The
first version matched only `<Armor>` elements and so dropped nothing but the mail coifs, leaving
every helmet on. Worse, it made me report a wrong conclusion: that the helmet in these presets
(`713a4f57-…`) was an armour-mod item absent from vanilla. **It is not.** It is vanilla
`KettleHat03_m02_B3` — a `<Helmet>`, not an `<Armor>`. Armour stats live on four element types:
`<Armor>` (1916), `<Hood>` (130), `<Helmet>` (106) and `<QuickSlotContainer>` (7).

### What a bare head actually costs

With all four element types read, the real figures:

| | armour (stab+slash+smash) |
|---|---:|
| the ten medium presets, as they are | **1302** |
| the same ten with the headgear removed | **888** |
| difference | **−414** |

1302 against the 1300 the medium tier is solved to in `docs/outfits.md` is the cross-check that
the measurement is right this time. 888 sits between the weak budget (600) and medium (1300):
**a bare-headed woman is worth about 68% of a medium man, not 88%.** Every preset gives up a
helmet *and* a mail coif — `KettleHat03`, `SkullCap01/04`, `BascinetOpen01/07` plus a
`CoifMail`/`CoifSmall` apiece.

That is a real balance decision, not a rounding error, and it is left as-is because the ask was
medium gear minus helmets and that is literally what this builds. If effectiveness parity with a
medium man matters more than the gear list, the one-line change is to point `SOURCE` in
`gen_female_gear.py` at the **strong** presets (`6d657263-0103-…`, budget 1850): minus the same
~414 that lands near 1436, a shade above medium. Padding the body pieces to fake the budget back
is the option not taken — it would misrepresent what the player is buying.

**Why a wardrobe and not a runtime strip.** The previous attempt dressed them normally and then
called `Human.UnequipItemInSlot` on the head slots, on a four-pass timer to get past the
same-frame refusal `custom_gear.lua` documents. It ran — `kcd.log` showed the sweep touching
all ten women with a live `ent.human` and no refusal — and the helmets stayed on. `GetArmor`
read `0 -> 0`, so it could not even say whether the unequip had landed. A preset that never
contained a helmet cannot leave one on.

### 2. No *audible* dialogue — and only that

They are ordinary mercenaries in every respect except the sound of their voice. Same brain
(`e2a51ce4-…`, byte-for-byte the medium merc's), same faction, same social class, same
`combat_level`, same roles, same `InjectInteraction`, same order wheel, same E-dialog, same
camp behaviours. The soul rows differ from `soul_merc_medium_*` in exactly one field:
`skald_character_name`.

What is off is the sound, at the two choke points the custom companions already use:

- `RequestBark` returns early for them, next to its existing `IsHero` check. That is the single
  queue every order bark goes through, so one line covers all of them.
- the camp-chat pairing skips them, as it skips named companions.

Both for the same reason `docs/companions.md` gives: every bark and gossip line the company
owns was recorded for anonymous male sellswords and plays on the soul's own voice, so putting
one in a woman's mouth is worse than silence.

`OrderBarkSome` additionally *prefers* speakers who can actually speak — it builds the pool
from the unmuted men where there are any, and falls back to the whole squad otherwise. Without
that, a mixed company would spend one of its three speaking slots on someone who says nothing
and the order would read as unacknowledged. A company of nothing but women selects normally and
simply stays quiet, which is the intended outcome rather than an error.

#### The bug this replaced

The first build had no dialogue options on them at all, and the cause was not the code — it was
a missing table. **Roles are assigned by a Storm rule keyed on the soul name**
(`libs/Storm/roles/mercenariesroles.xml`), and `soul_merc_female_*` had no rule in that file.
The order wheel binds every one of its 66 responses to `Role="role_mercenary_test"`, so a soul
with no role has nothing to bind and the wheel comes up empty.

Ten rules were added, each granting `role_mercenary_test` and `role_mercenary_test2` exactly as
all 138 other merc souls get them, plus the matching `skald_character2role` rows.

That build also skipped `InjectInteraction` outright, which took the order wheel away along
with the voice. Both were wrong: the ask was to mute them, not to silence them.

#### The hire menu: one wrong role broke the quartermaster

The "Women." branch was written once and pasted into all four dialogs, and the paste carried
`Role="role_mercenary_provider"` — which is right for `hire_dialog.xml` (the innkeeper's man)
and wrong for `quartermaster_dialog.xml`, whose other 139 NPC lines are all
`role_mercenary_quartermaster`. One reference to a role the dialog has no actor for was enough
to stop the whole quartermaster dialogue loading: **no E prompt at all**, not a missing option.

A dialog casts exactly one NPC role. The check worth running after touching any of them:

    Role="..." counts per file, HENRY excluded -> should be a single entry

    aleksej_dialog.xml         {role_aleksej: 40}
    dismissal_dialog.xml       {role_mercenary_test: 55}
    hire_dialog.xml            {role_mercenary_provider: 57}
    quartermaster_dialog.xml   {role_mercenary_quartermaster: 140}

Two entries in one file means a line is addressed to somebody who is not in the room.

#### Deliberately not shared: the inventory preset

`libs/Storm/equipment/mercenariesequipment.xml` gives every other merc soul a
`setInventory preset="inventory_mercenary_<tier>_<n>"` — a base outfit and weapon applied at
spawn, before the mod's own Lua dresses them. The female souls have no such rule, on purpose.

Every vanilla `soldier_generic_*` base preset contains headgear, and `EquipClothingPreset` does
not reliably strip slots that are already filled (`mercenaries_custom_gear.lua` documents
exactly this: applying a preset made pieces *underneath* visible rather than replacing them).
Handing them a base kit with a helmet in it risks putting back the helmet this whole category
exists to remove. Their clothing and weapons come from `EquipFemale` alone.

The cost is that a woman whose `EquipFemale` somehow failed would stand undressed where a man
would fall back to his base preset. That has not been seen, and the trade is deliberate.

### 3. One tier

One pool of ten faces, one price, medium gear — exactly the archers' shape.

### 4. Female heads, hair and voices

Ten vanilla female heads and seven vanilla hairstyles, lifted onto the male skeleton by
`tools/fit_female_heads.py` and mounted in the Male component tree; ten souls; ten
`skald_character` rows with `gender="1"` and a female `voice_id`. The souls stay
`soul_archetype_id="0"` — archetype 1 is `NPC_Female`, which would hand the NPC the female
skeleton, the `female2` clothing config and the female animation set, and that set has no
combat in it at all.

### The files

| file | what |
|---|---|
| `data/Scripts/mods/mercenaries_female.lua` | the category: souls, wardrobe, hire, spawn, token, console |
| `tools/gen_female_gear.py` | generates the helmet-free presets into `clothing_preset__mercenaries.xml` |
| `tools/fit_female_heads.py` | generates the 51 lifted head/hair meshes |
| `data/libs/tables/character/CharacterComponent__mercenaries.xml` | 10 heads + 10 hair entries in the **Male** tree |
| `data/libs/Storm/appearance/mercenariesappearance.xml` | 10 rules, `soul_merc_female_1…10` |
| `data/libs/tables/rpg/soul__mercenaries.xml` | 10 souls |
| `data/libs/tables/skald/skald_character__mercenaries.xml` (+`2role`, `2profession`) | 10 female voices |
| 4 × `hire_dialog.xml` / `quartermaster_dialog.xml` | the "Women." branch, both regions |
| 2 × `mercenaries_background_quest.xml` | 8 token nodes each |
| `data/libs/tables/item/item__mercenaries.xml` | the hire token |
| `localization/*_xml.xml` | 8 strings × 16 languages |
| `data/libs/Storm/roles/mercenariesroles.xml` | 10 role rules - **without these there are no dialogue options at all** |
| `mercenaries_equipment.lua`, `_roster.lua`, `_orders.lua`, `_camp.lua`, `_util.lua`, `mercenaries.lua` | the hooks: wardrobe, bark mute, camp chat, speaker pool |

**A token GUID collision was caught in review, not in game.** The first draft used
`679a655e-…be64d`, which is already `TokenIDStatus` — hiring women would have fired a status
report and asking for status would have hired women. The token is now `…be02d`, verified unused
across the whole of `data/`.

### The head height, and how it was fixed

The heads bind and render, but the mesh is authored around the *female* skeleton's Head joint
and the female skeleton is shorter, so they sat low. There is no XML lever — across all of
vanilla `CharacterComponent.xml` a `<SkinElement>` only carries `EquipmentPart`, `Material`,
`Model`, `BodyLayerId`, `KeepBodyLayer`, `IsFinalLayer`.

Positions in a `.skin` are plain little-endian `float32` triples, so the lift is arithmetic.
`tools/fit_female_heads.py` edits three places in place at the same byte length, so the chunk
table never moves: the type-0 stream (24-byte header, `n × 12`), `CompiledIntSkinVertices`
(32-byte header, 64-byte records, position at `+12`), and the mesh bbox at `+108`. Each is
checked arithmetically before being touched.

**Z comes from the neck seam, corrected by eye.** The first build used the joint delta
(0.0707), reasoning that helmets hang off the Head joint. In game that landed *"a few
centimetres"* low. The seam delta — male head bbox z-min minus female, `1.4019 − 1.3061 =
0.0958` — is **exactly 25 mm more**, so measurement and eye agree. All fifty female heads share
one bounding box (z-min 1.3061, zero spread), so one constant fits every head. X and Y still
come from the joint. Confirmed correct in game.

Output goes to `data/Objects/characters/humans/male/`, never over `humans/female/…` — shifting
those would lift all 986 vanilla female NPCs 10 cm into the air. **The pak is ~65 MB because of
these 51 meshes**; every byte regenerates from the vanilla paks.

### Not yet seen

- **The hair.** Hidden behind helmets on both runs so far. With the helmets gone from the
  presets themselves it should finally be visible. The ten span all seven female hairstyles on
  purpose:

| | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 | 09 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| hair | f_hair_04 | f_hair_02 | f_hair_05 | f_hair_07 | f_hair_04 | f_hair_02 | **f_hair_01** | **f_hair_03** | **f_hair_06** | **f_hair_01** |
| physics in vanilla | — | — | — | — | — | — | braids | braids | ponytail | braids |

  All ten bald means the hair is not binding at all. Only the bold four wrong means it is the
  dropped hair physics.
- The hire-menu branch, the neck seam, and whether they read as women.

### Known incomplete

- Hair physics is dropped on four styles.
- The new dialogue lines are text only — no voice, no lipsync.
- One wardrobe (style 1 medium). Widening it to the other sixteen liveries is a table change in
  `gen_female_gear.py`.
- No camp-staff or archer variants: melee only.

## Provenance

Extraction and diff scripts were scratch-only; the numbers above come from
`Tables.pak` (`CharacterComponent.xml`, `soul*.xml`, `soul_archetype.xml`, `gender.xml`,
`skald_character.xml`, `ClothingConfig.xml`), `IPL_GameData.pak` (`Libs/Storm/**`),
`Scripts.pak` (`Scripts/Entities/AI/NPC.lua`, `NPC_Female.lua`), `Animations.pak`
(`Mannequin/ADB/**`, `.dba` inventory), `IPL_Characters-part1/part3.pak` (skeletons),
`IPL_Heads-part0.pak` (Henry's head) and `Characters.pak` / `Heads.pak` (clothing and head
mesh counts).
