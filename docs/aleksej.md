# Aleksej of Zaslawye

A **continuous** quest: nine beats, objective after objective, no contract loop. This replaces
the Kleinkrieg contract structure (`KleinkriegContracts` in `mercenaries_banditcamp_quest.lua`,
the twelve-contract accept/clear/report cycle) rather than sitting alongside it. The old system's
`BanditCampSites` table is what the new beats' encounter sites are drawn from — see below.

Aleksej is a licensed bounty-hunter in Kuttenberg who secretly raised an army for **János
Kanizsai, archbishop of Esztergom (Gran)**, on a promise of unlimited funds. Kanizsai lost, was
stripped, and the money stopped. Aleksej now has an army he cannot pay and cannot safely
disband, so he hires Henry to liquidate it, paid out of the town's purse. His officers notice
which of their men keep dying, break with him, and take his own plan — storm Raborsch under
Sigismund's colours — to the field without him.

Beats 1–5 Henry works for him and does not suspect. Beat 6 is the turn. Beats 7–9 he hunts him.

## The nine beats

| # | Objective | Encounter (site) | Document | Trigger in | Trigger out |
|---|---|---|---|---|---|
| 1 | clear the woodland camp | `woodland_camp` — ≈ party size, min 4 solo, rabble; leader **Ondra** | — | talk to Aleksej, take the job | all dead → report to Aleksej |
| 2 | clear the mine hilltop | `mining_camp` — medium/medium, 5 solo; leader **Vávra** | **1**, on Vávra's body | report from beat 1 | doc found or all dead → report |
| 3 | clear the convoy | `patrol_convoy` — large/medium, 6 solo (rabble if solo) + hedge-knight elite leader | — | report from beat 2 | all dead → report |
| 4 | clear the burnt mill camp | `south_camp` — medium, rabble, **trained leader in Sigismund's colours** (surcoat item) | — | report from beat 3 | leader dead → report (the mask-off beat) |
| 5 | clear the patrol | `patrol_company` — **large, strong, knight leader — deliberate outlier** | **2**, on the leader | report from beat 4 | all dead → report (the confession) |
| 6 | go to Aleksej's lodging | Kuttenberg interior — **no combat, Aleksej absent** | **3**, **4**, both in the same room as the surcoat chest | report from beat 5 | enter the room, find the chest → objective advances on its own, no dialogue |
| 7 | clear the Roman fort rearguard | `roman_fort` — few, all knights, elite | **5** | leave beat 6 | all dead or doc found → report (implicitly: Henry is late because of beat 6) |
| 8 | lift the siege of Raborsch | `raborsch` — very large, mixed; reuses `mercenaries_siege.lua` / `mercenaries_raborsch.lua` | **6**, on the last officer | leave beat 7 | siege resolved → report |
| 9 | the marsh island | `swamp_island` — an ordinary camp; Aleksej leads it himself, mortal and armoured | **7**, on Aleksej's own body | beat 8's leader falls | Aleksej dies → the quest ends |

Counts above are base values for a **solo** player and scale with party size; see below.

## Encounter scaling

Base counts in the table are for a **solo** Henry with no company; a lone player must still be
able to play every beat. As the player's merc count grows, each beat's headcount scales with it,
but the **ratios between beats stay fixed** — beat 3 is always noticeably bigger than beat 2,
beat 5 is always the spike. The old `KleinkriegContracts` table (`mercenaries_banditcamp_quest.lua`)
is the working model for this: `ratio` (fraction of `BanditCampFollowerCount()`), `min` (solo
floor), `archerFrac`, `leaderClothing`, `leaderHealthMult` per entry, capped at 10 on the field.
The beat runner that replaces it should keep the same shape, keyed to the nine beats instead of
twelve contracts.

**Beat 5 must be a clear outlier**, tuned so a competent player barely survives. If it plays as a
normal step up from beat 3, beat 6 has no trigger — the near-death is what makes Aleksej sit
Henry down and confess. In `KleinkriegContracts` terms this means beat 5's `ratio` /
`leaderHealthMult` / archer fraction should sit well above the beat-3 convoy's, not on the same
curve. Beat 6 itself has **no** combat at all — that is not a scaling floor of zero, it is a beat
with no encounter.

## Two matched pairs — never edit one alone

**Lines 30 and 33** (`voicelines/aleksej_script.md`). Line 30 (beat 5 assign): *"They ride the low
road past the fields tomorrow. I do not know their road past that..."* Line 33 (beat 5 report):
*"...Bozhe. You took them past the shrine, then..."* He swears in 30 that he does not know their
road beyond the fields, then in 33 names a specific point — past the shrine — beyond that
landmark. He chose the site and timed the job to put Henry there; the slip is the tell. The place
named in 33 **must be the actual `patrol_company` encounter location and must lie beyond the
landmark named in 30**. If the ambush site moves, both lines move together. No sting plays, no
objective updates, Henry has no reaction line — it passes at conversational speed, on purpose.

**The beat-4 surcoat and the beat-6 chest are the same item asset.** The beat-4 leader
(`south_camp`) wears it; the beat-6 chest in Aleksej's lodging is full of them. If the leader's
surcoat and the chest contents are two different assets, the wordless proof at beat 6 does not
land — Henry has to recognise the garment on sight, with no dialogue to explain it (beat 6 has no
dialogue at all, see below). **Not yet built**: no surcoat item exists in
`item__mercenaries.xml` today; it needs to be authored once, referenced from both the beat-4
leader's `EquipClothing`-style preset and the beat-6 `Stash` contents.

## Voice

Ruthenian, roughly fifty, nine years in Bohemia. Warm, funny, generous with money.

- **Never a contraction.** *Do not*, *there is*, *I will*. Not once, including the marsh.
- **Never an enemy count** — counts scale with the player's party, so he cannot cite one. He
  gives a **name** and a **place** instead.
- **"Can you imagine that?"** appears exactly twice: line 21 (beat 3 report) and line 22 (beat 4
  assign). Never in the marsh (beat 9).
- He never names the lord he served until beat 9, line 41 — **Švitrigaila**. Every loc row in
  `localization/English_xml.xml` spells it `Svitrigaila`, no caron — resolved, not a bug: the
  whole file is byte-for-byte US-ASCII (every other diacritic in the mod's text is folded the
  same way, e.g. Vávra → `Vavra`), so this is the file's own established convention, not a
  one-off slip.

Direction notes worth keeping in mind while building the dialogue graph:

- Line 24 (beat 4 report, in response to H4/H5) is **the only moment the mask is off** — cold,
  short, no anger. Everything after it (25–28) is invention delivered fast, assembled as he
  speaks.
- Lines 19–21 (beat 3 report) are deliberate overpayment played slightly too fast — the last
  money he has to spend on goodwill.
- Beat 5's confession (34–38) is entirely true except for one omitted clause — that he is the man
  collecting the silver — and plays as relief, not confession.
- Beat 4's leader is not Kuneš. Aleksej names Kuneš in the assign lines (23); the man Henry
  actually fights is someone else. That mismatch is the beat, not an error to fix.

## Recordings

44 recorded lines: `voicelines/1.mp3` … `voicelines/44.mp3`, 7 min 5 s total. Full index — beat,
measured duration (`ReferenceLength` in seconds), exact text, and the beat-by-beat sequencing
against Henry's 9 unvoiced prompts (`merc_alx_H1`..`H9`) — lives in `voicelines/aleksej_script.md`.
Read that file before wiring any `<Response>`; it is the single source of truth for line order
and duration and takes precedence over anything paraphrased here.

**Loc key naming: resolved as one-key-per-turn, not one-key-per-recording.** `aleksej_script.md`'s
own header still describes an illustrative `merc_alx_L<n>` (one key per `.mp3`) scheme, but what
is actually shipped in `localization/English_xml.xml` — across all 16 language files, complete —
groups the recordings that play as one spoken turn (per the script's own "Sequencing" table) into
a single row: `merc_alx_<beat>_a1`/`a2` for the assign half, `_r1`..`_r4` for the report half.
`aleksej_dialog.xml`'s `ReferenceLength` on each merged `<Response>` is the **sum** of that turn's
recordings' measured lengths. Henry's H1–H7/H8–H9 have no separate key at all: his line **is**
the `ui_alx_<beat>_<slug>` `UiPrompt` text, reused as the spoken `<Response>` `Text` too (one key,
two jobs — the menu prompt and the subtitle are the same short line). `merc_alx_9_h1` is one
orphaned, unreferenced row left over from an earlier draft; harmless, not wired to anything.

**Henry's prompts are no longer all silent.** Same trick as the quartermaster's bandit-camp
lines (`docs/kleinkrieg-voice-lines.md`) and reference_henry_vanilla_voicelines.md: five of
Henry's prompts across `aleksej_dialog.xml` (plus two more in `carbongo/aleksej_marsh.xml`) now
point at existing vanilla `_henry_` StringNames instead of their own `ui_alx_*` key. This gets the
subtitle for free in every shipped language, but the tmck audio itself is not automatic - each
vanilla clip was copied byte-for-byte from `references/Voicelines/dialog/.../tmck_<name>.ogg`
into `voice/carbongo/` (alongside Aleksej's own `jcom_merc_alx_L*.ogg` recordings) so it packs
into this quest's own VO folder; pointing at the StringName alone would have shipped a silent
line with a correct-looking subtitle. Five prompts that had no usable vanilla match were deleted
outright (their `UiPrompt` menu text is unaffected - only the spoken `<Response>` was removed):

| Prompt | Fate |
|---|---|
| `ui_alx_1_done`, `ui_alx_2_done`, `ui_alx_3_done` | → `bark_henry_dokonano_jest_9xDV` ("It is done.") |
| `ui_alx_3_silver` | → `poke_henry_no_a_to_stribr_Tjad` ("And what about the silver?") |
| `ui_alx_4_take` | → `pred_henry_o_jakou_praci__fbLL` ("What do you want me to do?") |
| `ui_alx_5_anyway` | → `beru_henry_jdeme_na_to_ugL0` ("And why not. I'll do it.") |
| `ui_alx_9_who`, `ui_alx_9_men` (`carbongo/aleksej_marsh.xml`) | → `rozl_henry_no_v8xY` ("And?") / `rozh_henry_co_pdeI` ("And then?") |
| `ui_alx_open`, `ui_alx_1_guard`, `ui_alx_greet`, `ui_alx_2_who`, `ui_alx_5_whynow` | deleted - no vanilla line fit without changing the meaning |
| `ui_alx_4_done`, `ui_alx_4_describe` | left as-is, still silent - these carry the actual beat-4 reveal (Sigismund's colours) that lines 24-25 directly react to; no generic vanilla line could stand in without breaking that exchange |

## Beat 9 — simplified

**Superseded.** Beat 9 was built as a suppressed-combat set piece: everyone frozen until a forced
speech finished, an immortal Aleksej swapped for a mortal body double the instant it ended. All of
that is gone. The marsh is now an ordinary camp, Aleksej is an ordinary mortal leader in it on
`soul_aleksej_double`, and killing him ends the quest — see "How the quest is wired" below.

The speech itself (`carbongo/aleksej_marsh.xml`, lines 39–44 with H8/H9) is still authored and
still playable through the `merc_alx_talk` test harness; it simply is not wired into the beat any
more. Restoring it means re-adding the suppression lock and the double swap, both of which are in
git history.

## Documents

Seven, one fact each, payload in the first sentence, sixty words maximum. None carries a beat
that is not already covered by dialogue, an object, or a fight. Items `merc_alx_doc1..7` exist in
`item__mercenaries.xml` (Type 5, `Book` EntityScript, GUIDs `679a655e-189d-4519-b437-ccc4b92beaad`
through `...beb0d`); text is in `localization/English_xml.xml` as `merc_alx_docN_uiname` /
`_uiinfo` / `_part1` / `_part2`, all 7 written. Placement in the world (which body, which chest)
is not yet wired to any spawn.

## Aleksej himself

His soul/character/role chain is built and is not a stub: `soul_aleksej`
(`a1e50000-1c4b-4e6a-9f01-3b8c5d2e7b01`, `soul__mercenaries.xml`) → `char_aleksej`
(`skald_character__mercenaries.xml`, voice pool `generic`) → `role_aleksej`
(`role__mercenaries.xml` + `skald_character2role__mercenaries.xml`). His brain is his own,
**`aleksej_brain`** (`aleksej_scheduler.xml`) — no longer borrowed from the quartermaster. Same
shape as the quartermaster's "lobotomized merc" (a townsman who talks and does not pick fights)
plus his own camp routine and forced-dialogue arms; that is what makes him safe to approach for
beats 1–5, and is a brain choice, not a soul property.

**Blocked on you:** Aleksej's spawn position in his Kuttenberg lodging, and the spawn positions
for his bed, chest and stool. `mercenaries_aleksej.lua` ships a placement editor for exactly this
(`merc_alx_binds` takes F5–F11: F5 his spawn point, F6 stool, F7 bed, F8 chest, F9 dumps the four
positions as a ready-to-paste Lua table, F10 clears, F11 undoes one piece).

## State of the build

**Finished:**
- All 7 documents as readable items + full loc text, GUIDs `...beaad`..`...beb0d`.
- Aleksej's own soul/character/role/**brain** chain: `aleksej_brain` (`aleksej_scheduler.xml`),
  split off from the quartermaster's — same shape (stand, eat, self-defend), plus his own
  camp-routine and forced-dialogue arms. It carries a combat arm — `aleksej_scheduler.xml` fires
  `combat_melee` on `$inCombat | $alxHasTarget` — so he is safe to approach for beats 1–5 and
  still able to fight once beat 9's suppression lifts.
- The forced-dialogue mechanism, proven end-to-end and used for both talk-to beats and beat 9's
  forced speech.
- **The nine-beat runner** (`mercenaries_aleksej.lua`, part 3): `mercenaries.AlxBeats[1..9]`,
  scaling that mirrors `KleinkriegContracts`' `ratio`/`min`/`archerFrac` shape (`AlxScale`),
  band members spawned via the shared `SpawnEnemyAt`/`EquipEnemy` path, named leaders (Ondra,
  Vávra, the hedge-knight, Bartoš, the Sigismund knight) spawned separately, **each on his own
  soul** (`AlxLeaderSouls`, `beat.leaderSoul`, `AlxSpawnLeaderNPC`) so the man Aleksej names is
  the man the player finds and the map marker below has exactly one NPC to resolve to, doc placement on the right corpse for beats 2/5/7, beat 6's chest-or-direct-grant
  fallback, beat 8 delegated whole to `SpawnRaborsch`, and beat 9's own-soul spawn + combat
  suppression (previous section). `merc_alx_beat <n>` / `merc_alx_status` drive and inspect it
  for testing; it does not touch `KleinkriegContracts` or `mercenaries.BCQ` (see the file's own
  header for why, and "The encounter lifecycle" below for the two places it now borrows the
  Kleinkrieg camp's own tables as scratch space).
- **Beats 1–5's full talk-to dialogue trees**, `aleksej_dialog.xml` (both regions,
  byte-identical): assign + Henry's H1–H7 + report, gated on `alx_bN`/`alx_bN_done` bool ports,
  one `alx_accept_N`/`alx_report_N` trigger per committed turn, structure copied from the proven
  `quartermaster_dialog.xml`. Loc keys and `ReferenceLength` are the merged-per-turn scheme
  described above — cross-checked line by line against `aleksej_script.md`.
- **Beat 9's full marsh speech**, `carbongo/aleksej_marsh.xml` (both regions): all six lines
  (39–44) plus H8/H9, flattened into one linear `Autoselect` `Sequence` (no player choice needed,
  same shape as the mod's own NPC-to-NPC gossip files) rather than the nested-Decision nesting a
  branching conversation would need.
- **The nine-objective quest graph**, `mercenaries_background_quest.xml` (both regions):
  `alx_b1..b9`/`alx_bN_done` bool states (beat 1's open + every beat's done are Lua tokens via
  `ItemDescriptorTrigger`, matching the `kk_phase_*` idiom exactly; beats 2–9's open gates are
  pure graph edges off the previous beat), nine `Progress`-type `Objective`s, and a
  `QuestProgress` wrapping the whole arc. The ten bridge-token GUIDs
  (`679a655e-189d-4519-b437-ccc4b92beb1d`..`bebad`) are registered as real `MiscItem` "token" rows
  in `item__mercenaries.xml` and as `mercenaries.TokenIDAlxB1`/`TokenIDAlxB1Done..TokenIDAlxB9Done`
  string constants in `mercenaries_aleksej.lua`, matching the GUIDs on both sides — this was the
  one link in the chain the concurrent lanes had each assumed the other would supply, and it is
  now closed.
- Encounter *sites* for every beat with a fight — `woodland_camp`, `mining_camp`,
  `patrol_convoy`, `south_camp`, `patrol_company`, `roman_fort`, `swamp_island`, `raborsch` — all
  exist in `BanditCampSites` and are what `AlxBeats` reads from directly (not through
  `KleinkriegContracts`, which this quest replaces and no longer touches for Aleksej's own arc —
  `bandit_camp_quest.xml`'s separate top-level quest is untouched, own file, own concern). **These
  sites are genuinely far away** — beat 1's `woodland_camp` is ~4.2km from Aleksej's Kuttenberg
  lodging — so every combat beat's "Started" objective log now carries a `Marker` (beats
  1-5,7 → `alx_leader`, a dedicated soul spawned only on the beat's named leader so the marker
  always resolves to exactly one live NPC, same trick as `bandit_camp_quest.xml`'s
  `banditcamp_leader`; beats 6,9 → `aleksej` himself). `AlxEnsureLeader`, ticked alongside
  `AlxCountLiving`, re-spawns that leader if his entity is gone (a reload - spawned NPCs are not
  saved) and he was never observed dead (`AlxCombat.leaderDead`), so the marker survives a
  save/load the same way `BanditCampEnsureLeader` does for the old arc. Beat 8 (the siege) has no
  marker yet - `SpawnRaborsch` doesn't expose a single tracked anchor NPC to hang one on.
  `merc_alx_goto` (testing only) teleports the player straight to the active beat's site.
- The lodging placement editor (`mercenaries_aleksej.lua`), unused until the four positions are
  placed — see "Blocked on you" above.

**Still to build / genuinely open:**
- **Aleksej's lodging spawn point, bed, stool and chest positions** — blocked on the user
  (`merc_alx_binds`, F5–F11, `merc_alx_dump`, bake the printed table into
  `mercenaries.AlxLodging`). `AlxDump`'s own output format was a real bug found in this
  reconciliation pass — it printed a flat array (`{ { what = "chest", x = ..., ... }, ... }`) that
  did not match what any consumer actually reads (`AlxLodging.chest` / `AlxLodging.chestYaw`,
  keyed fields, not an array); fixed to emit the keyed shape directly. Also newly built in this
  pass: `AlxLodgingSpawn`/`AlxLodgingRemove` (`mercenaries_aleksej.lua`) — without them there was
  no persistent Aleksej NPC anywhere for `aleksej_dialog.xml`'s talk-to menu to actually open on,
  so beats 1–5 were unreachable in play regardless of how correct the Skald graph was. He is now
  spawned (his own soul, same `guidSharedSoulId` as the marsh Aleksej) the moment beat 1 starts,
  and removed the moment beat 6 starts ("Aleksej absent"), both gracefully logging and no-opping
  if `AlxLodging.spawn` is not set yet. Beat 6 itself still grants its two documents to the player
  directly until `AlxLodging.chest` is set, so the quest is not blocked, but the "walk into the
  room and see the chest" beat does not exist yet.
- **The surcoat item shared between beats 4 and 6** (the matched-pair requirement above). Beat
  4's leader already dresses in Sigismund's colours today via a working fallback (the `sigi`
  `EnemyGroups` clothing pool, an existing vanilla soldier-of-Sigismund outfit preset,
  `references/Libs/Tables/item/clothing_preset.xml`'s `soldier_sigi_2_01` and eleven siblings) —
  that satisfies the encounter table's dress-code requirement on its own. What is still missing is
  a single, specific wearable *item* — the same garment, not just the same outfit family — as a
  lootable class for the beat-6 chest, so the "wordless reveal" lands on the *exact* piece rather
  than a same-faction-but-different coincidence. Finding which single garment inside a
  `clothing_preset` bundle is the surcoat, and authoring it as a standalone `item__mercenaries.xml`
  entry, is asset work this reconciliation pass did not attempt (wrong asset reference here is
  worse than the honest current fallback) — `mercenaries.AlxSurcoatClothingGuid` /
  `AlxSurcoatItemClass` are the two read-live hooks waiting for it, no code change needed once
  they exist.
- Beat 9's "Ruthenian names" are armour-only today (`group = "cuman"` for gear) — giving the
  henchmen actual distinct Ruthenian-named souls (rather than reusing the generic `cuman` combat
  pool) needs new soul assets, out of this pass's scope.
- Beat 8's doc 6 is granted to the player directly the moment the siege is lifted, not placed on
  a specific "last officer" body — `mercenaries_raborsch.lua`'s besiegers are not individually
  addressable from `mercenaries_aleksej.lua` without editing that module. Documented simplification,
  not a bug.
- Balance: beat 5's outlier tuning (`ratio 2.0 / min 9 / capBoost 3 / extraHealthMult 1.3`) and
  beat 9's Ruthenian headcount (`fixedBase 4`) are first-pass numbers meant to be played and
  retuned, not final.

## Forced dialogue — the mechanism

`RequestBark` does **not** work for this. It only queues an alias for a `schedulerMonolog` node
inside a behaviour the NPC is already running, and a bark is not a dialogue.

Vanilla's node is **`<ForcedDialog>`**, 560 uses across the shipped quests. It wraps a
`<Dialogue Initiator="NonPlayer">` — an NPC-initiated conversation the player cannot decline:

```xml
<ForcedDialog Name="...">
    <Text StringName="..." Text="..." />
    <Dialogue TechnicalStatus="Enabled" Initiator="NonPlayer">
        <Decision Name="dec1">
            <Sequences>
                <Sequence Name="seq1">
                    <Elements>
                        <Response Role="HENRY" />
                        <Response Role="..." />
                    </Elements>
                </Sequence>
            </Sequences>
        </Decision>
    </Dialogue>
</ForcedDialog>
```

`Initiator="NonPlayer"` is the half that matters — compare the order wheel, which is the same
family with `Initiator="Player"`.

### What actually starts one — the behaviour tree

**A Skald module describes a dialogue. It cannot begin one.** `EntryCondition="Port('x')"` only
picks which `Sequence` runs once a conversation is already under way, so a bool In-port gates the
speech and then waits forever. That single misreading cost five attempts, each of which
deserializes cleanly, resolves every edge, logs no error, and produces silence:

| Tried | Why it cannot work |
| --- | --- |
| `RequestBark` | A bark is not a dialogue at any stage. The test NPC stood there eating bread. |
| bool port alone | Gates a sequence; never starts one. |
| `UrgeADialog` | The NPC waves you over. It is an invitation, not a conversation. |
| `CreateDialogParams` → `DialogParams` port | A census of all 855 vanilla `ForcedDialog` modules: 1776 In-bools, 1823 Out-triggers, **no In-trigger and no DialogParams port**. Those 786 vanilla uses feed other module types. |
| `enqueuedialogue` implicit In-port | Real (vanilla edges into it exist), still silent on its own. |
| top-level `<ForcedDialog>` module + bool port | Real and Skald-valid (`enqueuedialogue` driven from an `ItemDescriptorTrigger`), but redundant once `RequestForceTalk`/`forced_dialog.xml` (below) was working — it never touched the production beat 9 path and existed only in one region copy (`kutnohorsko`'s `aleksej_forced.xml`), so it has been **removed** rather than mirrored to `trosecko`. |

The thing that starts one is **`Function_speech_dialogInitiator`, run from a behaviour tree**.
Vanilla ships a tree literally named `pacholek_forceDialogue`
(`references/AI/quests/mlynarskyUcen/mlynarskyucen.xml:382`) that is three nodes long, and every
vanilla case of an NPC accosting the player — arrest, frisk, trespass, ambush, the pre-duel taunt
— uses this same node, differing only in `preset`. Its `recipient` parameter is a `_wuid` whose
declared default is literally `$__player`; 154 call sites pass it explicitly. **The mod had never
called it once.**

Attempt 6 reached for `Function_speech_schedulerPolylog_initiator` instead, because the two-NPC
camp gossip already used it. That was the wrong lesson from a working example: vanilla routes the
player through `dialogInitiator`, which builds the participant array itself and forwards to
`polylogInitiator`. Four rules come straight off the vanilla call-site census, and attempt 6 broke
three of them:

| Rule | Attempt 6 |
| --- | --- |
| `alias` only — `metarole` and `recipientMetaroles` stay empty. The player holds **no** metarole (185 of 199 uses empty; every non-empty one is NPC↔NPC). | passed the player `GOSSIP`, then `HENRY` |
| never set both `alias` and `metarole` | set both |
| `context`/`customParameters` take `$__null`, not `""` | passed `""` |
| `preset` carries the behaviour flags | used `ingame`; **`fader`** is the one that takes control off the player |

`dialogPreset` has five values in shipped data: `ingame`, `chat`, `fader`, `ignored`,
`player_ingame`. **`fader` is the forced one.** Do not use `player_ingame` — the shipped preset
switch has no branch for it and its `DefaultBranch` is an `ErrorNode`.

### A Definition is not an instance

`RequestDialog` reporting `Decision with alias 'x' was not found!` does **not** mean the alias is
misspelled or the roles are wrong. A `<Definition File="..." />` only makes the dialog module
*type* available to the quest graph. **The instance element in `<Nodes>` is what places it in the
running graph and registers its `<Decision>` with the dialogue manager:**

```xml
<aleksej_marsh Name="aleksej_marsh" PositionY="150" PositionX="900" />
```

Bare, self-closing, no edges. The tag is the `<Dialog Name="...">` from inside the definition
file, *not* the filename. Every one of the mod's 144 working aliased dialogues has both halves;
vanilla has 3779 aliased Definitions and **zero** orphans. Two files in this repo were the only
orphans in either codebase, and they were the two being debugged.

`docs/` note for future work: the check is cheap to automate — for every `<Definition>` whose
target file contains an aliased `<Decision>`, assert the enclosing `<Dialog Name>` appears as a
node tag in the referring quest.

Adding the instance node worked: the alias resolves and both parties join —
`Attempting to start new dialogue with souls 'Ex: <npc>; Ex: Dude'` (`Dude` is the player).

### The preset decides positioning

What remained after that was `Request timed out`. `fader` and `ingame` **position** the
participants; `chat` positions nobody, which is why vanilla's pre-duel taunt — the closest shipped
thing to this beat — uses it. A Lua-spawned NPC is snapped to *terrain*, which is not the same as
*navmesh*: `Path finding failed ... not close enough to nav mesh`. An NPC who cannot path never
arrives, and the request expires. Spawn him near the player, who is by definition standing on
navmesh.

`preset` does **not** have to match the `Dialogue`'s `Type` in the sense of naming the same word,
but they must be *compatible*: `preset=chat` against a `Type="ingame"` (or untyped) `Decision`
logs `Dialogue chat mode is not consistent with its decisions branch type`. The mod's forced
dialogues carry **no `Type` attribute at all** (284 shipped aliased NonPlayer-initiated Decisions
are the same), which is what makes them compatible with every preset including `fader`.

### Why six attempts produced no errors

**A behaviour must also be REGISTERED, not just written.** `AddInterrupt`/`AddInterrupt_attack`
can only fire a behaviour that has a `<SmartBehaviorTemplate>` row in
`data/libs/tables/ai/smartEntity/SmartEntity__so_interrupt__mercenaries.xml`. Without the row the
fire fails with `[AddInterrupt]:Specified behavior doesn't exist on any smart entity` — and if the
flag that marks "already fired" is set inside the same guarded branch, a missing row retries
forever with no error at all. Copy an existing row verbatim.

**The BT loader silently ignores unknown attributes on `Function_` calls** — vanilla itself passes
one (`forceDialogAnimations`) that the callee never declares. So a misspelled or unsupported
attribute is not an error, it is a no-op. `LogToConsole` takes `LogLevel` + **`Message`**, not
`text` — an invented attribute name here is itself silently dropped. `forced_dialog.xml` logs
`[fd]` at every step precisely so a missing/failed link shows up instead of just going quiet.

### The shipped mechanism, as built

The final, working shape is a dedicated behaviour plus a Lua-owned request queue, not a branch
grafted onto an existing tree:

1. **Lua enqueues.** `mercenaries:RequestForceTalk(wuid, alias, preset, altWuid)`
   (`mercenaries_camp.lua`) writes `_G.MercForceTalk[wuid] = { alias, preset, seq }`, keyed under
   both the requested WUID and, if different, the alternate one — `GetMyWUID` and
   `entity.this.id` do not always agree, see `reference_order_barks_and_wuid_keying.md`.
2. **The scheduler polls, once a second, and fires an interrupt.** Any scheduler that needs to be
   able to force a conversation carries a small loop (`aleksej_scheduler.xml` has it because a
   request can arrive while Aleksej is not currently registered as a camp actor, e.g. the
   `merc_alx_talk` test NPC): `ForceTalkWanted` peeks the queue
   without consuming it and sets `fdWant`; on `fdWant & ~fdFired` it builds a synthetic attack
   `information`/`interruptData` (`Function_crime_getMrkev` + `CreateInformationWrapper` +
   `Function_crime_limits_reserveReactionLink`) purely as the payload `AddInterrupt_attack`
   requires, and fires `AddInterrupt_attack ... Behavior="forced_dialog"`. A `seq` counter on each
   request re-arms `fdFired` so a *new* request always fires even after a *previous* dialogue
   failed — without it, one failed `RequestDialog` wedges the whole system, because
   `ForceTalkDone` (which lowers the flags) never ran.
3. **`forced_dialog.xml` runs as the fired interrupt.** It pulls the alias/preset via
   `ForceTalkPull` (consumed at fire time, not at finish time, so a failing request cannot block
   the next one), loops a `Turn` at the player for the duration, and calls
   `Function_speech_dialogInitiator` directly — **not** `schedulerPolylog_initiator` — with
   `alias=$alxAlias`, `metarole=""`, `recipientMetaroles=""`, `recipient=$__player`,
   `preset=$enum:dialogPreset.<fader|chat|ingame>` chosen by `$alxPreset`. This resolved the
   metarole open question below: the player takes no metarole at all, matching the vanilla
   census, and the dialogue plays.
4. **`ForceTalkDone`** clears the queue entry and lowers `fdWant`/`alxForce` once the behaviour
   finishes — this is the hook beat 9's combat suppression should release on.

`camp_actor.xml` is a **second, independent call site**, not just a declaration. It carries its
own `alxForce`/`alxAlias` variables, its own first-priority `ContinuousSwitch` arm gated on
`$alxForce`, and its own inline `Function_speech_dialogInitiator` call followed by
`ExecuteLua code="mercenaries:ForceTalkDone(data, entity)"` — the full mechanism, duplicated
in-tree rather than delegated to `forced_dialog.xml`. It is fed by `mercenaries:ForceTalkRole`
(`mercenaries_camp.lua`), called each poll from inside `camp_actor.xml` itself, which is a third
Lua entry point alongside `ForceTalkWanted`/`ForceTalkPull`/`ForceTalkDone`. This arm exists so a
camp merc or any other NPC running `camp_actor` (not `aleksej_scheduler`/`quartermaster_scheduler`)
can be made to speak without needing the `AddInterrupt_attack`-into-`forced_dialog` detour —
Aleksej's own beat 9 fires through `forced_dialog.xml` via his scheduler's dedicated arm (above),
even though he is also registered as a camp actor at that point; a future beat that forces
dialogue from an ordinary merc or camp NPC would go through this `camp_actor.xml` arm instead.
Both call sites obey the same rules (`alias` only, empty metaroles, `$__null` context,
`preset=fader`).

Test with `merc_alx_talk` (spawns a test NPC on his own soul, 6m ahead on navmesh — close enough
that pathing to the player never fails; walk within 10m) or `merc_alx_talk_now` to force it
immediately. `merc_alx_talk` defaults to `aleksej_marsh` (now the *complete* six-line beat-9
speech, not a stub); `merc_alx_preset <1|2|3>` retunes fader/chat/ingame live;
`merc_alx_talk_clear` removes the test NPC. The bisection probes that proved the mechanism
(`merc_alx_vanilla`, `merc_alx_lua`, `merc_alx_merc`) have been trimmed now that it is proven and
in production use — see `mercenaries_aleksej.lua`'s own header, part 3, for why.

For the nine-beat arc itself: `merc_alx_beat <n>` jumps to (or starts) beat `n` directly, and
`merc_alx_status` prints the active beat, tracked wuids, and — while beat 9 is live — the
`fired`/`speechDone` state of the marsh suppression.


## How the quest is wired

**One int is the quest.** `alx_beat` (a Skald `State TypeT="int"` in the alx half of
`mercenaries_background_quest.xml`) holds which beat is live: `0` = not hired, `1..9` = that beat's
job is out. `alx_done` (a bool beside it) says the job is finished and Henry is walking back.
There is no other progression state anywhere — not in Lua, not in a save blob, not in nine
per-beat bools.

Everything reads those two: the dialogue gates on them, the journal is driven by them, the purse
is driven by them, and so is the camp respawn.

| Thing | Where |
|---|---|
| the int and the bool | `alx_beat`, `alx_done` |
| "is beat N live" | `alx_is_N` — `Control::Compare(alx_beat, Equals, N)` |
| a beat ends | `alx_death_N` — `SoulDeathTrigger` on that beat's own leader soul |
| a beat is handed off | `alx_hand_N` from the dialogue, or the previous kill, or the beat-6 token |
| the camp goes up | `exec_alx_spawn_N` → a token → Lua `AlxSpawnBeat(N)` |
| the money | `exec_alx_pay_N` → `CreatePlayerReward` of the vanilla money item |

### A beat ends when its LEADER dies

Not when the camp is cleared. Every leader is a **soul of his own** (`soul_alx_ondra`,
`soul_alx_vavra`, `soul_alx_hedge`, `soul_alx_bartos`, `soul_alx_knight`, `soul_alx_leader`,
`soul_alx_officer`, `soul_aleksej_double`), declared one-per-`SoulAsset` in the quest. Nothing has
to count bodies — only recognise one man.

**`SoulDeathTrigger` does not work here, and this cost a play-test.** It is the vanilla node for
exactly this, it was wired on each leader's own soul gated on his own beat, and it never fired
once — while, on the same run, the hire advanced the int, the spawn token built the camp and the
tower archers were adopted. So the graph loads and the rest of it works; the trigger simply does
not bind to an NPC Lua spawned at runtime from a shared soul, the way a marker does. Every vanilla
`SoulDeathTrigger` in the corpus watches a level-baked NPC.

So the kill is bridged: Lua notices the leader is down (with the usual missing-handle grace) and
drops that beat's own `AlxDownToken`, which an `ItemDescriptorTrigger` per beat picks up. Those
triggers are gated on `merc_alwaysOn` rather than on a per-beat comparison — the token carries the
beat number itself, so the path needs nothing else in the graph to be working. It is the only
progress Lua still reports, besides beat 6.

A multi-GUID `SharedSoulGuids` means "these several NPCs as a group" in vanilla — it is the wrong
tool both for a marker and for naming the one man whose death matters. One soul, one asset.

### A hand-off is the only thing that moves the int

`alx_hand_N` means "beat N starts now". It increments `alx_beat`, clears `alx_done`, pays for the
beat just finished and issues the next camp's spawn token — all off one trigger, so a hand-off
cannot half-happen. What fires it:

| into beat | fired by |
|---|---|
| 1 | the hire conversation |
| 2–6 | beats 1–5's report conversation |
| 7 | the beat-6 lodging token (he is absent from here on; nobody to report to) |
| 8, 9 | the previous beat's own leader death |

### The camp is not save data

Lua drops every camp on load (`AlxOnLoad`). The quest re-issues that beat's spawn token on the
level's own `OnWake` — which fires on **every** load — gated on `alx_beat == N AND !alx_done`
(`alx_needs_N` → `alx_wake_N`). Lua sweeps the site (`AlxSweepSite`) and rebuilds. So logging out
mid-camp leaves nothing behind, and logging back in puts it back.

`AlxSpawnBeat` is therefore idempotent by contract: it is called on every wake, and a camp already
standing for that beat is left alone.

The camp comes away when the **last** man in it is down **and** the player is
`AlxCampDespawnRange` (100 m) off — the quest closed the beat long before, when the leader fell,
so this only decides when the tents go. Both halves matter: taking it down on the last kill did it
under the player's feet. Tower archers are adopted into the camp as they arrive and, once the
ground is clear, each is swapped for an identical archer at the foot of his tower
(`AlxBringArchersDown`), because there is no way to walk one down a ladder.

### Named leaders wear their own gear

`beat.leaderClothingPreset` (and `leaderWeaponPreset`) equip one exact preset and skip the random
draw from `EnemyGroups[group].clothing`. That pool is for leaders who are only a rank — "the
officer", "the captain". Beat 5's knight is a person.

**Sir Jezhek of Holohlavy** leads the Sigismund patrol, cloned the way the mod's "heinrich" Henry
look-alike already is: a fresh soul of the mod's own (`soul_alx_jezek`), never his real one
(`ztracenaCest_jezek`) — sharing that would put a hostile and the man in his own questline on one
identity, and this quest's per-soul death token with him. His face is copied parametrically from
his own vanilla appearance rule, so nothing is baked to a level.

**He spawned but did not render the first time**, and the cause was `body_type="5"` on his
skald_character — copied from his vanilla row, where it is paired with a `unique_assets` index
that belongs to his own quest and cannot come with him. It was the only `body_type` outside
`{0, 2, 3, 4}` in the whole mod. Now 4, like the other 59.

The two appearance files follow different conventions and both work, which is worth knowing before
copying one into the other: every rule in `enemiesappearance.xml` sets `setBody`, while the custom
companions in `mercenariesappearance.xml` (Kubyenka, Black Bartosch) deliberately do not — they
take the body from the character's own `body_type`. Jezhek lives in the enemies file, so he sets
one.

His **best gear is not a preset in vanilla**: the seven pieces are minted for him during
ztracenaCest's "shaneni_zbroje" chapter and bundled nowhere, which is why he kept coming out in
generic Sigismund plate. `weapon_preset__mercenaries.xml` pairs his broadsword with the Lords of
Holohlavy shield, which vanilla also leaves in no preset.

**He wears the best harness in the game, not his own set.** Five of his seven quest-unique pieces
carry `IsQuestItem="true"`, and `inventory:CreateItem` silently refuses those — the per-piece log
said `NOT CREATED` for exactly those five and equipped the two without the flag. Rather than clone
seven items to dodge one attribute, `AlxKnightHarness` is twelve top-tier vanilla pieces, none
flagged, no surcoat or caparison anywhere in it.

`beat.leaderGear` + `AlxWear` put them on one at a time, using the pattern vanilla's own
`player.lua` uses:

```lua
local id = ent.inventory:FindItem(cls)
if not id then ent.inventory:CreateItem(cls, 1, 1); id = ent.inventory:FindItem(cls) end
ent.actor:EquipInventoryItem(id)
```

**Order matters, and nothing warns you.** `equipment_slot.xml` declares `RequiresFilledSlot`: a
plate slot refuses everything until the padded layer under it is filled.

| slot | requires |
|---|---|
| `head_helmet` | `head_coif_padded` |
| `body_plate`, `body_chainmail`, `sleeves` | `body_cloth_padded` |
| `leg_armor` | `leg_trousers_padded` |
| `spur` | `boot` |

So the arming cap goes on before the bascinet, the gambeson before the cuirass *and* the arms, the
hose before the leg plate, the boots before the spurs. Reorder the list and he ends up half
dressed with no error anywhere.

### The siege scales on both sides

Beat 8 hands off to `mercenaries_raborsch.lua`. Three things scale, and one thing changed about
who shoots whom.

**Archers.** All 19 authored besieger positions used to be manned regardless of party size — a
wall of arrows for a company of four. `RaborschArcherCount` sizes them at `RaborschArcherRatio`
(0.5) of the company, floor 4, capped at 19; `RaborschArcherKeep` spreads them evenly down the
line rather than taking them from one end.

**Cover follows the archer.** A pavise is one man's shield, so `RaborschCoverKeep` matches each to
its nearest authored archer position and stands it only if that position is manned — otherwise
the line was boards propped in a field. The tarases stay: those are the wagon wall, not personal
cover.

**The levy.** Thinning the arrows made a siege against a small company thin overall, so the
shortfall is made up in bodies rather than by putting the arrows back. `RaborschRecruitCount`
fields unarmoured villagers in INVERSE proportion to the company — 12 against a lone player,
none by the time it is 8 strong. They are the new `recruit` enemy group: village clothes over the
looter group's own weakest souls, so nothing new had to be minted.

| company | soldiers | recruits |
|---|---|---|
| solo | 6 | 12 |
| 4 | 6 | 6 |
| 8 | 12 | 0 |
| 16 | 24 | 0 |

**The wall duels the archers, not the assault.** The garrison ran `mod_enemies`, which is *every*
mod-spawned enemy — so they shot the assaulting foot, and a man being shot fights back whatever
his orders are. The whole besieging line turned round and swarmed the wall instead of pressing the
assault. They now run a new `"wall"` mode: a target must be a mod-spawned enemy **and** a static
archer, which is exactly the besiegers' own archers. Fellow defenders are `SpawnedTower_archer_`
(a static archer name but not a mod-enemy one) and are excluded; the foot are mod enemies but not
static archers, and are left to the swords.

### The marsh

Aleksej's Ruthenians are their own enemy group, and three things about it are deliberate:

- **No waffenrocks.** The obvious plate pool is `EnemyGroups.knight`, which is Sigismund's livery
  — every one of its presets carries a `Waffenrock` item, checked item by item. The six armoured
  presets used instead are heraldry-free, mixed in with the twelve cuman ones.
- **Axes and shields, always.** `weapons = { 3 }` — the `WeaponSets` index list, where 3 is
  axe+shield (`ShieldWeaponTypes`, `mercenaries_equipment.lua`).
- **Their own souls**, purely so they are called Ruthenians rather than Cumans:
  `char_enemy_cuman_*` is shared with a Kleinkrieg contract and renaming it would rename those too.

**The preset goes on first, then the harness, then the leftovers come off.** In that order, and
the order is the whole of it.

`EquipClothingPreset` re-dresses a character *wholesale*, so preset-over-preset is clean. Per-piece
armour is not: `EquipInventoryItem` only fills the slots it names, so every slot the preset filled
that `AlxKnightHarness` does not cover stayed filled, and both Jezhek and Aleksej turned up wearing
two kits at once with Sigismund's livery showing through the plate.

The obvious fix — stop giving a hand-dressed leader the group preset — **makes it worse**, and this
cost a play-test to learn. Withhold the preset and every piece still lands in his pack via
`inventory:CreateItem`, but `actor:EquipInventoryItem` quietly declines all twelve and he spawns
in nothing. The inference (single-variable change, symptom flipped from *over*-dressed to
*un*-dressed) is that a runtime-spawned NPC has no usable equipment state until a clothing preset
has been applied to it once. `inventory:RemoveAllItems()` between the two does not help either — it
empties the *pack*, and what is worn stays worn.

So the sequence in `AlxSpawnLeaderNPC` is:

1. `EquipEnemy(ent, beat.group, false)` — the group preset, unconditionally.
2. `RemoveAllItems()` — clears the pack, leaves him dressed.
3. `AlxWear` × 12, in `RequiresFilledSlot` order.
4. `AlxStripOverLayers` — `human:UnequipItemInSlot()` on the four slots the harness does not own
   and that render over it: `body_coat` (7, the Waffenrock), `head_hood` (23), `head_cap` (33),
   `collar` (22). Not `body_cloth` (35) or `leg_trousers` (40) — a shirt and hose belong under a
   gambeson and are invisible under plate.
5. `EquipWeaponPreset` — **spelled out per beat**, because step 2 took the group's weapon off him.
   Jezhek names `AlxJezekWeapons`; Aleksej names `axe_shield_4_02`.

`equipment_slot.xml` declares only five prerequisite rules (`head_helmet <- head_coif_padded`,
`body_plate`/`body_chainmail`/`sleeves <- body_cloth_padded`, `leg_armor <- leg_trousers_padded`,
`spur <- boot`) and the harness satisfies all of them on its own, so a missing underlayer is *not*
what was going on — that was checked and ruled out.

**Diagnosing it next time:** `AlxWear` logs every piece as `worn` / `EquipInventoryItem FAILED` /
`NOT CREATED`, and the dressing now closes with one summary line —
`Sir Jezhek dressed: 12/12 pieces, armour <before> -> <after>` — off `actor:GetArmor()`. There is no
"what is in this slot" query in the scriptbind, but naked against full plate is not a subtle
number. If that line says `12/12` and the armour value barely moves, the pieces are equipping and
something later is undoing it; if it says `0/12`, they never went on. **This needs the dev build**
(`PackageModDev.bat`) — the release exe logs nothing.

For a company of five or fewer the island drops to two archer carts of two archers each and **no
towers at all** — an archer on a deck nobody can reach reads as immortal until the ground is
clear, which is a poor last fight.

### Silver worth taking

Beat 3 is a *silver* convoy, so its hedge knight carries two cakes of cast silver
(`beat.loot` / `lootCount`). There was no lootable silver in KCD2 to give him: the base game ships
a whole set of refined-silver meshes under `metal_industry/silver` to dress the Royal Silver
quest's mint, and never wraps one as an item. `merc_alx_silver` is the first, on
`silver_cake_single.cgf` — a cast cake straight off the smelter, which is what a Kuttenberg
convoy would actually be hauling. Priced at 450 against `loot_silverChalice` (650 for 0.6 kg, with
a craftsman's markup a plain ingot does not carry).

### The marker and the spawn must name the same soul

Each beat's journal marker is `Marker="alx_leader_N"`, an Objective-level marker bound to the
`SoulAsset` of that name. **That GUID has to be the soul Lua actually spawns for beat N.** When
beat 5's leader changed from the generic knight to Sir Jezhek, the asset was left on the old soul
and the marker bound to a soul nobody was carrying — no marker at all, while everything else
(the kill token, the document, the hand-off) went on working, because none of those go through the
asset. `validate.py` now checks the two one-to-one per beat; the earlier subset test passed
straight through it, since the stale GUID was still declared in `AlxLeaderSouls`.

### A road site marches

A site with a recorded `route` (`patrol_convoy`, `patrol_company`, `patrol_looters`) is not a camp
and must not stand like one. `AlxSpawnBand` strings the band out **along the road**, ~4 m apart
measured along it and alternating sides of the centreline, all of them *behind* the anchor — the
leader stands on it, and placing the others forward puts him at the back of his own column and
sends him walking through his men the moment he sets off. `AlxAssignCampRoles` then pins the
borrowed Kleinkrieg contract to a **patrol** row (contract 4) instead of a camp row, which is what
makes `AssignBanditCampRoles` hand out the marching column — one man walking the recorded route,
the rest following the man ahead — rather than sit/eat/sleep. All of it ported from the Kleinkrieg
contract's own patrol spawner, where the traps were found the hard way.

### A document is not optional

The documents are referenced **by class GUID** (`mercenaries.AlxDocs`), not by the `Name` in
`item__mercenaries.xml`. They were referenced by name, and `CreateItem` takes a class — so every
one of them silently did nothing inside its `pcall` and no leader ever carried anything. Every give
that matters now goes through `AlxGiveItem`, which reads the count back and logs loudly if it did
not land.


On a beat that carries one (2, 5, 7, 8) the kill does **not** end the beat. It raises
`alx_search` — "Search the body." — and only the document reaching the player's pack ends it:
Lua polls for it and drops that beat's `AlxDocToken`, which is what closes the objective, opens the
walk home (2, 5) or hands off to the next beat (7, 8). The document is the point of those beats and
the player could otherwise walk straight past it.

If they walk away without looting, `AlxDespawnCamp` hands the document over rather than letting it
go with the body — the same safety net `BanditCampGrantLetterFallback` is for the Kleinkrieg
letter, and without it the beat would be uncompletable. Beat 9 is excluded on purpose: its kill
ends the quest outright, and gating that on a pickup risks a quest that can never close.

### What Lua still does

Stand a camp up, dress it, give it camp roles, bring the archers down, take it away — plus the
two things Skald cannot see for itself: **the leader is down** (above) and, for beat 6, **both
documents are out of the chest**. No kill counting, no payout, no save blob.

### Henry's own thoughts — the two beats with nobody to report to

Beats 1–5 each end in a conversation. From beat 6 on Aleksej is gone, and
`voicelines/aleksej_script.md` is explicit that beats 6, 7 and 8 have **no dialogue at all**. Two
one-line thoughts stand in for the report dialogue where that silence costs something:

| Key | When | Text |
|---|---|---|
| `merc_info_alx_lodging` | beat 6, within 10 m of the chest, **before** it is looted | *Gone — bed stripped, chest left standing. Aleksej went out of here in a hurry.* |
| `merc_info_alx_raborsch` | beat 7 closing — the muster order in hand | *Raborsch is under siege. Old walls, a thin garrison — and Sigismund's colours on them.* |

Both go through `mercenaries:AlxThought(key)` → `Game.SendInfoText(key, false, 0, 8)`, the mod's
own channel for this (~90 call sites, localisation key in, HUD line out). In practice an info line
reads at about **80 characters**; the longest one the mod already ships is 87.

**The lodging line is anchored on the chest, not on Aleksej's spot.** Beat 6 opens the instant the
beat-5 report ends, and that conversation happens where he stands — anchoring there as well would
fire the line the moment he vanishes, with the player rooted to the spot and nothing discovered.
The chest sits ~16 m off and 6 m up from him, clear of the radius, so they have to walk to it.

**It also latches through `SaveString`, not a boolean.** Beat 6's spawn token is reissued on every
level wake and `AlxLodgingResetOnLoad` rebuilds the chest on every load, so a plain flag would
replay the line after each reload. `merc_alx_msg_reset` clears the latch.

**The Raborsch line hooks both ways a document beat can close** — the `AlxTick` poll when the
player loots the body, and the `AlxTearDown` fallback that hands the document over when they walk
away without looting. Either is the beat closing; only one of them ever runs, both guard on
`C.docNoted`. `AlxThoughts` is keyed by beat, so adding one for another beat is one table row.

Console: `merc_alx_msg_lodging`, `merc_alx_msg_raborsch`, `merc_alx_msg_reset`.

There is a Skald-native alternative worth knowing about if these ever need to be more prominent
than a HUD line: `<Function MethodName="wh::guimodule::ShowUINotification">` takes a
`LocalizedString` `Message` and a `Duration` and fires straight off a graph edge (9 vanilla uses,
e.g. `references/Quests/Final/Barbora/kutnohorsko/legacy_of_the_forge/.../memory_bench.xml:71`).
The Raborsch line could hang directly off `alx_doc_7.OnAcquire` that way, with no Lua at all. It
was not used here because the lodging line needs a proximity test that only Lua can do, and two
story beats reading in two different UI channels is worse than either channel.

### Encounter towers are not the player's towers

`TowerStations` and `ArcherCarts` are single shared lists. Breaking the player's camp — which
**fast travel does on its own** — ran `DefClearWorld` → `TowerStationClearAll` → *every* tower in
the list, so an Aleksej or Kleinkrieg camp was silently stripped of its watchtowers and archers
from the other side of the map. Both sweeps now skip stations carrying `st.group`, which only an
encounter sets (the same test `SpawnArcherCart` already budgets on).

### Beat 9

An ordinary camp like any other. Aleksej is its leader, on `soul_aleksej_double` — a mortal soul
that looks like him — and killing him ends the quest. No forced speech, no immortality, no body
double swap. `carbongo/aleksej_marsh.xml` and `merc_alx_talk` survive only as the forced-dialogue
test harness (see "Forced dialogue — the mechanism" above).

### Money

`CreatePlayerReward` with the vanilla money item class, `Amount` a constant per beat, fired by the
hand-off into the next beat. **`Amount` is in decigroschen** — vanilla's own `createmoney_player`
module takes a groschen figure and puts it through `converttodecigroshen` (a plain ×10) before
handing it to this same node on this same item class, so the constants here are the purse ×10
(3500 / 5000 / 9000 / 7000 / 12000 = 350 / 500 / 900 / 700 / 1200 gr). Pass groschen straight in
and the player is paid a tenth, silently, with the UI notification confirming the wrong number — so he settles up as the report ends. Beats 6–9 pay nothing: after
the turn he is not an employer.

`move_money` would be the obvious node and is not used, deliberately. It **moves** items between
two inventories; Aleksej is a Lua-spawned NPC carrying no coin, so it would transfer nothing and
report success — the same silent no-op class as `player.inventory:AddMoney`, which this mod has
already been bitten by twice. `CreatePlayerReward` creates.

### Aleksej himself, across a load

He is kept present by `AlxLodgingEnsure` off the logistics tick. Two things a load invalidates,
both of which used to leave him missing for the rest of the session:

- **`AlxLodgingId`.** Entity ids are recycled, and the keeper's whole test is "does this id still
  resolve". A stale id usually resolves to *something*, so it read as "he is standing there".
- **`AlxKeepLast`.** It holds `System.GetCurrTime`, which restarts on a load, so a mark cached
  from late in the previous session left `now - AlxKeepLast` negative for good.

`AlxLodgingResetOnLoad` drops both, clears his camp-role entries and sweeps his room by name so
the tick rebuilds him. That he has **left for good** from beat 6 is Skald's to remember, not
Lua's: the quest issues `TokenIDAlxLodgingGone` once `alx_beat >= 6` and again on every wake after
that.
