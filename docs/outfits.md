# Squad Outfits

`mercenaries.Outfits` (in `mercenaries.lua`) is the squad wardrobe. Styles 1-5 and 8-17 carry **10 presets per tier** (450 generated presets); style 6 (Skalitz) is authored separately with **4 per tier** and style 7 is the custom uniform, see below. `EquipMercenary` parses the tier out of the merc's entity name, looks up `Outfits[style][tier]` and rolls one preset from it.

| # | Style | Heraldry | Silhouette |
|---|---|---|---|
| 1 | Generic Mercs | **none** — a free company serves nobody | professional freelance soldier |
| 2 | Bandits | **none** — no lord, no colours | hoods, rough coats, scavenged and mismatched armour |
| 3 | Cumans | **none** | caftan instead of gambeson, loose hose, knee boots, open bascinets |
| 4 | Leipa | `_mLeipa` surcoat/coat/coif | standard man-at-arms in Leipa colours |
| 5 | Kuttenberg | `_mKuttenberg` (18 surcoats, 10 coats, 2 coifs, 1 hood) | town levy in Kuttenberg colours |
| 6 | Skalitz | Skalitz waffenrock (4), red hood, mail collar — **from *House of Kobyla*, not vanilla** | hand-authored, 4 presets per tier, generated from `tools/gen_skalitz_presets.py` |
| 7 | *(custom uniform)* | — | not a preset pool — see [The custom uniform](custom-gear.md) |
| 8 | Prague | `_mPrague` (4 surcoats, a coat, 2 hoods, 2 coifs) | city regiment in Prague colours |
| 9 | Sigismund | `_mMagyar` + `_mUher` (2 surcoats, 3 coats, hood, 2 coifs) | Hungarian royal livery |
| 10 | Order of the Red Star | `_mKrizovnik` (5 surcoats, 2 hoods) | crusader order — red star on white |
| 11 | Bergov | `_mBergov` (5 surcoats, 2 coats, hood, 2 coifs) | noble retinue |
| 12 | Nebakov | `_mNebak` (4 surcoats, coat, hood, 2 coifs) | noble retinue |
| 13 | Semine | `_mSemin` (4 surcoats, coat, 2 hoods, coif) | noble retinue |
| 14 | Pisek | `_mPisek` (3 surcoats, 2 coats, hood, 2 coifs, hose) | town levy |
| 15 | Teutonic Order | `_mTeuton` (3 surcoats, 2 coats, hood, own brigandine) | black cross |
| 16 | Ruthard | `_mRuthart` (3 surcoats, coat, coif, own leg harness) | Kuttenberg patrician |
| 17 | Papal Legate | `_mPapal` (2 surcoats, hood, coif) | the legate's guard |

**Skalitz (style 6) is authored piece by piece**, not drawn from the item budget below, and carries 4 presets per tier instead of 10. The authored list lives in `tools/gen_skalitz_presets.py`, which writes the twelve presets from it: change the look by editing the spec there and re-running, never by editing the XML. Hand-editing is what caused the last regression — `_1`/`_3` and `_2`/`_4` silently became byte-identical.

**Its livery is a real dependency.** The Skalitz waffenrock (four surcoats), the plain red Skalitz hood and the Skalitz mail collar come from the third-party *House of Kobyla Arms, Armour and Regalia* mod, which is why the outfit label says so. Everything else in the presets is vanilla, so **without** that mod the base layers still equip and the men simply turn out without the surcoat — no error, just no heraldry.

> **The "Skalitz reverts to generic style" bug was exactly that, but permanently:** the shipped presets had lost every livery piece and kept only the plain vanilla base, so a Skalitz merc was assembled from the same pool as style 1 whether or not the player had the dependency. On top of that, `_1`/`_3` and `_2`/`_4` were byte-identical in all three tiers, so the style fielded two looks per tier instead of four. Regenerating from the spec restores both. If mercs still look generic *after* this fix, the dependency is missing — that is the one case where the old symptom is expected.

**Style 7 is the custom uniform**, not a wardrobe: the player hands the quartermaster a set of gear and the whole company copies it (`mercenaries.CustomOutfitIndex = 7`). It has no entry in `Outfits`, and `EquipMercenary` falls through to style 1 if it is ever looked up. New liveries therefore start at 8.

Sigismund's livery is `_mMagyar`/`_mUher` — he was King of Hungary, and that is the only livery his army has in the game. Styles 8 and 9 deliberately share their heraldry with the `sigi` and `prague` **enemy** groups: dressing your company in Prague colours does not make it the Prague regiment, but the two will look alike on a field.

Style 6 also stays Skalitz because `SkalitzOutfitIndex = 6` drives shield matching in `mercenaries_equipment.lua`. Style indices are assumed by `EnemyOutfitOverride` and the `merc_battle` console commands — don't renumber them.

**Style 7 is the odd one out.** It has no entry in `Outfits` at all: it is the set of items the player handed the quartermaster, worn piece by piece, and `EquipMercenary` branches out to `GearApplyArmour` before it ever reaches the table. It is *shown* second, right after Generic, but numbered 7 for exactly the reason above. See [custom-gear.md](custom-gear.md).

## Armour budget

Every preset is built to a fixed **armour budget** for its tier — the sum of `DefenseStab + DefenseSlash + DefenseSmash` across every piece:

| Tier | Budget | Measured spread across styles 1-5, 8-17 |
|---|---|---|
| weak | 600 | 587–610 (3.9%) |
| medium | 1300 | 1287–1308 (1.6%) |
| strong | 1850 | 1836–1864 (1.5%) |

So **switching style never changes how tough a merc is, only how he looks.** That was not true before: the old table ran from 126 (`cuman_2_01`, graded weak) to 1030 (Kuttenberg weak average) inside the same tier — a Kuttenberg "weak" merc was tougher than a Cuman "strong" one. It also listed `test_cls2_soldier_01`, a preset that resolves to **zero items**, so one Generic strong merc in eight spawned effectively naked.

### Why the budget works

Colour variants of a base model are defensively identical — `Hood01` has 13 `_m##` variants all at 2/3/5, `CoifMail01` has 4 at one stat line. Visual variety is therefore free. Each preset is built by picking a **skeleton** of base models that sums to the tier budget, then rolling colours over it. All 450 presets are distinct in both silhouette and colour.

The same machinery builds the six enemy-group wardrobes, to a per-group budget instead of a per-tier one — see [Enemy groups](enemies.md).

## Silhouettes

Each style/tier has 3 archetypes, all solved to the same budget, rotated through the 10 slots:

| Style | weak | medium | strong |
|---|---|---|---|
| Generic | padded, kettle, maillight | kettlemail, skullbrig, openbasc | cuirassier, brigandier, kettleveteran |
| Bandits | hooded, scavenger, stolenhelm | raubritter, hoodedmail, lootedbrig | warlord, hoodedheavy, mismatched |
| Cumans | lamellar, mailrider, scout | bascinet, heavycaftan, horsearcher | chieftain, brigrider, veteranrider |

Every liveried style (4, 5, 8-17) reuses the Generic archetypes and gets its livery injected over the top by `solve_arch`, which is why the Generic archetypes themselves carry no `SURCOAT` slot: **styles 1 and 2 wear no heraldry at all.** A freelance company answers to nobody and a bandit has no lord, so a waffenrock on either reads wrong.

## Layering rules

These come from how the vanilla `soldier_*` presets are actually built, and every generated preset satisfies all of them:

- A **helmet needs a coif** under it. Never a cloth cap under a helmet.
- **Mail and plate need padding** under them — a gambeson, or (Cumans) a quilted caftan.
- **A hauberk's gambeson must match its length**: `GambesonShort` with `MailShort`, `GambesonLong` with `MailLong`.
- **Leg armour needs padded chausses** (`LegsPadded*`) under it.
- Everyone gets hose and footwear.
- One item per slot.

The length-pairing and slot-uniqueness rules are the ones that break silently — a Long gambeson under a Short hauberk still equips, it just looks wrong.

## Reinforced caftans

A Cuman wears a caftan where a Bohemian wears a gambeson **plus** a mail shirt, so the Cuman styles have two fewer armour-bearing slots than everyone else. At the weak budget that is the difference between 190 and 600; there is no way to close it with vanilla items without dressing Cumans as men-at-arms.

`item__mercenaries.xml` therefore carries **26 reinforced caftans** — one-to-one clones of the `Caftan01`–`Caftan05` colourways, same mesh, same icon, same UI name, with defence raised to **95/100/55 (250)**, a lamellar-lined profile sitting between a brigandine and a mail hauberk. Weight +4kg and price ×2.2 to match. They are named `<source>_mercRnf` and are the only new items this system adds; everything else is vanilla.

## Item selection

Presets are built only from a vetted pool: **1565 vanilla armour pieces**, filtered to exclude

- named-character and quest items (Žižka, Capon, Brunswig, Radzig, Hanuš, Bergov, …) — several of these are *disguise* items that hide 234–250 armour under an ordinary cap or coat mesh, which would silently blow the budget;
- clergy, jester (the whole `Coat06` line), plague, painter and cutscene-only oddities;
- another lord's heraldry, except where a style deliberately flies it.

The `merc_skalitz_*` presets carry **six** item GUIDs that exist in no vanilla table — the four Skalitz surcoats, the hood and the mail collar, all from *House of Kobyla Arms, Armour and Regalia* (the same dependency the Skalitz shields in `weapon_preset__mercenaries.xml` used to carry, before those were pointed at vanilla equivalents). `tools/gen_skalitz_presets.py` knows which six they are and refuses to write a preset containing any other unresolvable GUID.

The `merc_lipa_strong_*` presets were documented as carrying the same dependency; checked GUID by GUID against `references/base_game/Libs/Tables/item/item*.xml`, **all 33 of their items now resolve in vanilla**. They are no longer drawn by style 4, which uses generated presets, and stay in the XML so old saves don't break.

## OutfitTierHints

`mercenaries_difficulty.lua` grades a clothing GUID into weak/medium/strong via `DiffClothingTierIndex`, which used to read `Outfits` alone. The `recruit` and `ruthenian` groups still dress from 22 vanilla presets the squad no longer wears, so those are kept in `mercenaries.OutfitTierHints` and folded into the same index — otherwise `DiffWardrobe` loses their grade and falls back to array position. They are graded by measured armour value (<950 weak, <1575 medium, else strong), which is more accurate than the hand-sorting they had before.

The six rebuilt enemy groups are deliberately **not** listed here. Their pools are authored worst-first along a ramp, so `DiffWardrobe`'s positional fallback already splits them correctly — and grading them on the merc thresholds would flatten a whole group into one tier and destroy that ordering.

## Two traps in the generator

Both cost real visual variety before they were caught, and both are the same shape:

- **`cosmetic()` counted the optional `None` as zero.** A slot the solver may leave empty (`TORSO_CLOTH=COAT_ROUGH + [N]`) looked like it spanned 0–10 points instead of 7–10, so it never qualified as free to swap and never re-rolled. Result: 17 of 30 bandit presets wore the same `Coat05`. Measure the spread over the *real* candidates only — whether the slot is filled is the solver's decision, and re-rolling never changes it.
- **The helmet converges on a tight budget.** It is the single biggest term in an outfit, so the solver picks whichever model hits the target and the whole group ends up in one hat. The enemy builder gives `HELMET` a wider swap allowance (7% of the group budget) for this reason. `TORSO_PAD` and `TORSO_MAIL` are never re-rolled — swapping there breaks the gambeson/hauberk length pairing.

## Adding a livery style

A new style is one entry in `LIVERY` (the livery item GUIDs and how they are injected), a name in `STYLE_ORDER` at the index you want, and then the wiring, which is where the real work is.

A `LIVERY` entry has up to four keys. `SURCOAT`, `TORSO_CLOTH` and `HOOD` are pools the injector draws from. **`SWAP`** maps a stock base model to its liveried twin in *any* slot — that is how the liveried coifs, Ruthard's `LegsBrigandine04` and the Teutonic `Brigandine05` get in. Every swap piece must be stat-identical to the model it replaces or it moves the tier budget (the Teuton brigandine is the one exception, 8 points light).

Excluded from every livery on purpose: anything flagged `ui_in_unique_clothing` (a lord's *personal* harness, e.g. `LegsPlate03_mBergov`), the `*Captured` quest-state variants, and Pisek's `ui_in_warning` caps and boots.

| File | What to add |
|---|---|
| `mercenaries.lua` | `Outfits[N]` — the generated preset pool |
| `clothing_preset__mercenaries.xml` | the 30 presets |
| `mercenaries_spawning.lua` | an `EnemyOutfitOverride[N]` so the test-battle enemy line differs |
| `…/mercenaries_background_quest.xml` | `exec_clothes_N` — token count **is** the style index |
| `…/dismissal_dialog.xml` | an out-port and an answer `Sequence` |
| `…/order_wheel_chat.xml` | an out-port and a wheel slot |
| `localization/*_xml.xml` × 16 | `ui_merc_equip_xxx`, `merc_henry_equip_xxx`, `merc_test_equip_xxx` |

The quest and dialog files exist **twice**, once under `kutnohorsko` and once under `trosecko` — they are hand-mirrored copies, so every change lands in both.

The order wheel paginates three per page with the fourth slot always "more", so it now runs six pages deep:

```
1: generic  custom     bandits    -> more
2: cumans   leipa      kuttenberg -> more
3: skalitz  prague     sigismund  -> more
4: krizovnik bergov    nebakov    -> more
5: semine   pisek      teuton     -> more
6: ruthard  papal
```

Seventeen styles is a lot of wheel: Papal is five "more" clicks in. If it starts to grate, the fix is to group the eight house liveries behind a single "colours of a house" entry on page three rather than extending the chain further.

## Changing the wardrobe

To retune a tier, change the budget and rebuild — do **not** hand-edit individual presets, or the pools drift apart again. The invariant worth protecting is that the min and max of every pool stay inside a few percent of each other and of the other styles at the same tier.
