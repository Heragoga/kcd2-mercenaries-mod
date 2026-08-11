# utokNaMalesov: structure, and what actually enrols an NPC in the battle

Produced by an exhaustive 20-agent pass over all 339 files of the quest, with every candidate
mechanism adversarially verified. Companion to [npc-lod.md](npc-lod.md) and
[quest-override-battles.md](quest-override-battles.md).

## The headline

**Nothing in this quest hides anyone.** The complete destructive/visibility inventory across all
339 files is `KillNpc` (4, debug-only), `KillnArea` (1), `PermaDeath` (4),
`DeadBodyRegistration` (4), `HideActorCommand`/`ShowActorCommand` (13/11, **dialogue scene
composition keyed by VO Role**, never by a soul), `DespawnAndDisableRandomEvents` (1). Every one
is scoped to an explicit soul array or to a dialogue.

So the merc is not being hidden. **It is failing to be *engaged*, and rendering follows
engagement.**

## What makes an NPC a target: `AddFactionRelationBetweenArrays`

Exactly **6 instances** in the quest, all `RelationValue="-1"`. This is the only node type that
creates combat hostility between the scripted armies.

| file | SoulArray0 | SoulArray1 (the targets) |
| --- | --- | --- |
| `.../boj_na_vnitrnim_nadvori/boj.xml:30` | `player` + `innerCourtyardZizkaband` | `innerCourtyardDefendersAndShooters` + `malesovTowerShooters` |
| `.../tvrz/vnejsek/bitva.xml:89` | `stealthCommando` | `outerCourtyardDefendersAndShooters` + `malesovTowerShooters` |
| `.../vnejsek/intermezzo_na_predhradi.xml:51` | `outerCourtyardZizkabandReinforcements` | `outerCourtyardDefendersAndShooters` + `malesovTowerShooters` |
| `.../boj_ve_vezi_optional/bitva_ve_vezi.xml:38` | `towerDefenders` | `player` + `towerAttackers` |
| `.../protiutok_a_prepad_ve_vesnici/bitva_s_posilami.xml:29` | `zizkabandInVillage` | `villageReinforcements` |
| `.../krvava_noc_v_malesove/pred_prepadem.xml:24` | `malesovFleeingFemaleVillagers` | `player` |

Verified shape (`boj.xml:30`):

```xml
<AddFactionRelationBetweenArrays Name="addfactionrelationbetweenarrays19">
    <Constant Name="RelationValue" Value="-1" />
    <Edge From="joinarrays20.Array" To="SoulArray0" />
    <Edge From="obranci_jdou_bojovat" To="IsActive" />
    <Edge From="joinarrays29.Array" To="SoulArray1" />
</AddFactionRelationBetweenArrays>
```

**The relation is directional: SoulArray0 → SoulArray1.** Being in Array0 makes you hostile
*toward* Array1; being in **Array1** is what makes something *attack you*. This matches the
independent finding that `FactionTree` relations are one-directional (our `mercenariesFaction`
declares hostility outward and no vanilla faction declares anything back).

The second hostility channel is `combat_forcedTarget` (16 `SetRelationContext` nodes). Its `From`
set is entirely named heroes (brabantSoldier_1/2/3/5, cert, sam, hans, zizka, komar, ptacek,
bohuta); its `To` set entirely garrison singletons. **Never the reverse.** That is the exact XML
shape of the measured "0 attacks against mercs, 40 attacks by mercs".

## Why the three injection experiments came out as they did

| run | merc landed in | targeted by anything? | observed |
| --- | --- | --- | --- |
| all 137 | Array0 **and Array1** of every fight, plus `To` of all 16 forced targets | **yes** | **rendered**, fought for the garrison |
| ally 67 | Array0 only, in the fortress | no | nothing |
| 6 companions | `From` side + `EnableBehavior` subjects only | no | nothing |

Every observation predicted. Competing hypotheses all die here: soul membership per se (refuted by
ally-67), `EnableBehavior` on a soul (refuted by the 6-companion run),
`BattleDisableLiteSoulsTarget` (both its aliases were in the ally run), layers/battle groups
(all-137 touched neither and rendered).

## The three enrolment channels

| channel | keyed by | reachable from a mod? |
| --- | --- | --- |
| **Soul membership** | soul GUID ↔ `guidSharedSoulId` | **yes — the only one** |
| Battle groups | level-baked `SmartObjectHolder` + `linktag="battleEntity"` | no |
| Level layers | `AssetProfiles="utoknamalesov_…"` | no |

`registerbattlegroups` / `initializebattlegroup` take `<Asset Name="groupcontrollers"
Alias="…GroupController"/>`, and every such alias resolves to a `<SmartObjectAsset>`, never a
`SoulAsset`. A Lua-spawned merc can never join a battle group — but it does not need to, because
all-137 rendered without joining one.

## Hibernation: not the culprit

`hibernovana_cast` / `nehibernovana_cast` is a **hand-rolled authoring convention**, not an engine
feature — `utokNaMalesov.xml` has no `HibernateMode` attribute at all. `HibernateMode` is an
attribute on `C_ModuleBase` in `wh::conceptmodule` with values
`Script | EventPlace | DLC | ActivityType | Auto`, governing **quest-graph** dormancy. It is
unrelated to NPC MonsterLOD hibernation (`HibernateInMonsterLod` on `SmartBehaviorTemplate`) —
two subsystems sharing an English word.

The non-hibernated branch owns the garrison's *physical presence*: `<Layer>` streaming,
`PermaDeath`, corpse/blood layers, a 24 h timer and an `IntermissionTriggerByDistance
minimaldistance="500"` that unstreams once the player leaves.

## Where souls are defined

**140** `<SoulAsset>` elements (137 with `SharedSoulGuids`, 3 empty scope-imports), **131 distinct
aliases**, **96 distinct soul GUIDs**, across **33 files**. `utokNaMalesov.xml` (29) +
`hibernovana_cast.xml` (12) = 41, only **29%** — the rest are spread over 31 files, including four
outside the hibernated subtree (`nehibernovana_cast/truchlici_vesnicane.xml`,
`.../posadka_na_vnejsim_nadvori.xml`, `.../mrtvoly_vesnicanu_ve_vesnici.xml`, `rekonstrukce.xml`).

Aliases resolve **lexically up the `<Definition File=…>` include chain**; 151 files reference an
alias they never declare. Editing a definition propagates to all descendant consumers — but the
same alias can be re-declared at a nearer scope, so injection must key on **(file, alias)**, not
on alias name alone. There is no runtime soul discovery anywhere: all 67 `MakeArray<Souls>` and
36 `JoinArrays<Souls>` are fed from fixed `<Asset Alias=…/>` children.

## Two defects this pass found in our own tooling

1. **The packaged Malešov override was a no-op.** `diff -rq references/…/utokNaMalesov
   data/…/utokNaMalesov` returned **0 differing files** — the entire 338-file subtree was
   byte-identical to vanilla, with only 11 of 29 top-level assets injected. The `noHostile` skip
   set over-matched and dropped every subtree asset. **Every recent in-game Malešov observation
   was made against an essentially vanilla quest.**
2. **`side_of()` in `OverrideMalesovQuest.py` misclassifies by name.** Measured by GUID overlap
   against the garrison union (`innerCourtyardDefendersAndShooters ∪
   outerCourtyardDefendersAndShooters ∪ towerDefenders ∪ malesovTowerShooters ∪
   outerCourtyardDefenders`, 36 souls) and the Žižka union (`zizkaband ∪ innerCourtyardZizkaband ∪
   outerCourtyardZizkaband`, 14 souls) — the two are **disjoint**, so the partition is exact:

   | alias | souls | ∩ garrison | ∩ Žižka | verdict |
   | --- | ---: | ---: | ---: | --- |
   | `villageReinforcements` | 12 | **6** | 0 | garrison — *misclassified as ally* |
   | `additionalVillageReinforcements` | 6 | 0 | 0 | neither union; its `_1/4/5` singletons are `To` operands of `combat_forcedTarget`, so garrison-side |
   | `villageAssaultUnit` | 12 | 0 | **12** | genuinely Žižka — the sub-agent wrongly called this garrison |
   | `towerAttackers` | 3 | 0 | 2 | genuinely Žižka |

   Classification must be by GUID set, never by alias name, and unmatched names must not default
   to `ally`.

## The implied fix

Since being in `SoulArray1` is what makes something attack you, and `SoulArray1` is by
construction the enemy roster, membership cannot give a *loyal* merc engagement. The way out is to
add the missing reverse relation: a new `AddFactionRelationBetweenArrays` with
**SoulArray0 = the garrison array** and **SoulArray1 = the merc souls**, reusing the existing
node's `IsActive` source. That makes the garrison hostile *to* the mercs without putting the mercs
in the garrison. See `tools/InjectMercHostility.py`.
