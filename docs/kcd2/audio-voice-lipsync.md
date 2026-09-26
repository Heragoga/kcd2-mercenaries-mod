---
title: Audio, voice lines and lipsync
summary: How KCD2 finds and plays a dialogue voice line (format, naming, paks, voice ids, fallbacks), how facial lipsync binds to it and how a mod bakes its own, how barks work, and where sound and music hooks live.
tags: [audio, skald, assets]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# Audio, voice lines and lipsync

## TL;DR

- A voice line is an **Ogg Vorbis, mono, 48 kHz** file named `<voiceAbbrev>_<StringName>.ogg` at `dialog/<namespace path>/` inside a `Localization/<language>.pak` (retail paks, measured). `voiceAbbrev` comes from the speaker's `skald_character.voice_id` → `Libs/Tables/skald/voice.xml` `abbreviation` (lipsync.md, retail binary).
- The face is found **by the same name**: `<voiceAbbrev>_<stringname>.caf` (lowercased) under `Animations/humans/facials/dialog/<same path>`, resolved only through the global index `Animations/FacialAnimations.img` (lipsync.md, retail binary).
- Custom lines get a frozen face unless you ship a baked clip **and** a full replacement index. The index is one global file: a mod's copy replaces vanilla's, so ship a complete one and regenerate it after game updates (lipsync.md, verified in game).
- Reusing a vanilla `StringName` gets the subtitle in all languages but **not** the audio: copy the `.ogg` into your own VO folder (kleinkrieg-voice-lines.md, verified in game).
- Audio middleware is **FMOD Studio** (`fmod.dll`, `Sounds.pak` → `Sounds/fmod/Build/pc/*.bank`) behind CryEngine's ATL layer (`Libs/GameAudio/*.xml`). Lua can fire existing ATL triggers; adding new FMOD events or banks is unexplored (retail binary; unverified for mods).
- Nothing plays in the Modding Tools dev build's faces: it ships no `Data/Facials` (lipsync.md).

Guides: voice-acting.md (recording), voice-mastering.md (matching vanilla loudness and tone). War stories: lipsync.md, kleinkrieg-voice-lines.md, squad-orders.md.

## File format, naming and lookup

| Property | Value | Source |
|---|---|---|
| Codec | Ogg Vorbis, mono, 48,000 Hz | vanilla `english-part0.pak` samples, measured |
| Loudness target | about -22.3 LUFS integrated, -4.2 dB true peak; long-term spectrum about +5.5 dB at 100 Hz and -21 dB at 5 kHz relative to 1 kHz (348-file vanilla sample) | voice-mastering.md (measured, community) |
| File name | `<voiceAbbrev>_<StringName>.ogg`; vanilla StringNames carry a 4-character hash suffix (`bark_henry_dokonano_jest_9xDV`) | lipsync.md; vanilla |
| Folder | `dialog/<namespace path>/` inside the voice pak, e.g. `dialog/kutnohorsko/kralovskeStribro/`, `dialog/fandici_barky/` | vanilla paks |
| Root | cvar `wh_dlg_VoiceRoot` (`Localization/dialog`) | retail binary; [console-variables.md](console-variables.md) |
| Vanilla paks | `Localization/english-part0..3.pak` (65,535 entries each), plus `IPL_english.pak` | retail install |
| Mod pak | `Localization/english.pak` (Mercenaries ships `dialog/mercenaries_background_quest/*.ogg`, 1,084 files) | mod `PackageMod.bat` (verified in game) |
| Subtitle length | `Response ReferenceLength` = `ceil(seconds)` of the take; without audio the engine estimates from character count (too fast for Chinese) | voice-mastering.md, [add-dialog.md](../skald/add-dialog.md) |

**The namespace path.** Skald nodes with `VoiceNamespace="true"` contribute their name to the VO folder: vanilla `Dialog Name="fandici_barky" VoiceNamespace="true"` → `dialog/fandici_barky/`; the `kutnohorsko` level plus quest `kralovskeStribro` → `dialog/kutnohorsko/kralovskeStribro/`. Vanilla sets `VoiceNamespace="true"` 254 times, `"false"` 4 times. The Mercenaries level files set `VoiceNamespace="false"` on `<Level>`, and its lines resolve at `dialog/mercenaries_background_quest/` (the quest name alone). So: levels and quests count by default, `false` drops a node from the path (inferred from vanilla data and the working mod; the exact default rule is unverified). If a line plays silently, the folder is the first thing to check.

**Other languages.** Vanilla has one voice pak family per spoken language, chosen by `g_languageAudio` (defaults to `g_language`). Mods typically ship `english.pak` only; what a player with another audio language hears for mod lines is untested (unverified).

## Voices: which one plays, and fallbacks

- The speaker's soul → `skald_character_name` → `skald/skald_character.xml` `voice_id` → `skald/voice.xml` row: `abbreviation` (file prefix), `voice_technical_name`, `fallback_voice_id`, `fallback_voice_level`, `voice_groups` (93 voices). Examples: 108 `tmck` Henry (Tom McKay), 239 `jcom`, 243 `rlaz` (vanilla `voice.xml`; lipsync.md).
- Custom string ids for an NPC's voiced lines must carry that voice's abbreviation as the file prefix, or the line plays silently ([add-new-npc.md](../xml/add-new-npc.md)).
- `skald_character.voice_categories` is a fallback when the voice lacks a line for a situation ([add-new-npc.md](../xml/add-new-npc.md), claimed). For metarole barks the engine falls back to an acoustically similar voice, so spot-check per voice ([talking.md](../behaviour-trees/talking.md)).
- A dialogue whose role has no recorded voice-over needs a `SelectedSouls` block and `VoiceoverFallbackLevel` on the `Decision`, or the request stalls until timeout. `Voice` accepts the abbreviation or the technical name (both appear in working mod data):

```xml
<SelectedSouls>
  <SelectedSoul Role="role_aleksej" Voice="jcom" Type="Wave" Language="ENG" />
  <SelectedSoul Role="HENRY" Voice="tomMcKay" Type="Wave" Language="ENG" />
</SelectedSouls>
<Decision Name="dec_aleksej" Priority="General" VoiceoverFallbackLevel="2" VoiceoverFallbackLevelRoles="role_aleksej HENRY">
```

(mod: `data/Quests/mercenaries/kutnohorsko/mercenaries_background_quest/aleksej_dialog.xml`, verified in game; vanilla uses `VoiceoverFallbackLevel="2"` 241 times.)
- `wh_dlg_EnableFallbackVoice` (default 1) "controls usage of generated dialogue voiceovers when the actual ones are" missing (cvar help text, retail binary; behaviour unverified).

## Reusing vanilla lines

- Point a `<Text StringName>` at a vanilla id to get the subtitle in all 16 languages. Then copy the vanilla `.ogg` **byte for byte** into your own VO folder under the same name; without it the line is a silent subtitle (kleinkrieg-voice-lines.md, aleksej.md, verified in game).
- To make your NPC "say" a vanilla line in its own voice, copy the file under your voice's prefix (`tools/prefix_ogg.bat` copies each `.ogg` as `jcom_`, `phos2_`, `sbar_`). **Check the source actually has a take by that actor.** A line recorded by one actor, copied under three prefixes, makes all three sound like that actor, even a woman's voice from a man; compare the files byte for byte (squad-orders.md, verified in game).
- Extract vanilla takes from `Localization/english-part*.pak`; the file name prefix tells you the actor, e.g. `jcom_...` (voice-mastering.md).

## Recording and mastering your own

- Short ambient lines: 5-10 words fit a speech bubble (voice-acting.md, claimed).
- Record each line to its own file named after its string id; export `.ogg` at 48 kHz (voice-acting.md).
- `tools/voice_master.py` (repo) denoises, dereverbs, EQ-matches to a vanilla actor's spectrum and levels to vanilla loudness, and reports `ceil(seconds)` per file for `ReferenceLength` (voice-mastering.md). Vanilla actors differ a lot in bass (+2 dB `gand` to +17.5 dB `tmck` at 100 Hz); master against the actor you are replacing.
- Some Mercenaries takes ship at 96 kHz and play; 48 kHz matches vanilla (retail mod pak, measured).

## Lipsync (facial animation)

KCD2 lipsync is stock CryEngine facial animation, not FaceFX or a proprietary pipeline (lipsync.md, retail binary).

| Piece | Where | Note |
|---|---|---|
| Per-line clips | `Data/Facials/Facials_english-part0..2.pak`, ~19,800 `.dba` containers | CryEngine chunk files; the clip path is a u16 length-prefixed string, no hash |
| Lookup root | cvar `wh_dlg_DBARoot` (`Animations/humans/facials/dialog`) | retail binary |
| **Index** | `Animations/FacialAnimations.img`: `CrChF` + u8 version + u32 count + u32 record size, then 16-byte records `(tag, id, size, offset)` into a blob carrying pose data and the `.caf` path; 295,556 entries in 1.4 | the index, not the folder, decides; a clip it does not name is unreachable |
| Generic library | `Animations/humans/facials/facials.dba`, 258 clips loaded for every human (`fa_cin_talk_neutral_01`, `fa_cin_talk_happy_01`, `fa_chew_loop`, mood idles) | usable by name from Lua |
| Skeleton hookup | `male.chrparams` / `female.chrparams` (in `IPL_Characters-part3/1.pak`) wildcard-load `Animations\humans\facials\*.dba` | why any indexed clip is addressable |

### Baking your own (the route that ships)

Warhorse's phoneme recogniser ships in the Modding Tools; the community [KCD2 Lipsync Tool](https://www.nexusmods.com/kingdomcomedeliverance2/mods/3648) drives it. Mercenaries wraps it in `tools/build_facials.ps1` (lipsync.md, verified in game: all 44 of Aleksej's lines have correct lipsync).

- **Stage the audio at its shipped path.** The tool derives each index path from the file's path relative to `--audio`; a flat folder produces `animations/humans/facials/<name>.caf`, which nothing requests, and the build still reports success. Verify the last index entry's path.
- **Pass a transcript** (`--text` pointing at the English localization XML) for forced alignment; a transcript that does not match the take silently falls back to textless recognition. The wrapper uses the English lexicon for every dub.
- Output is two paks in `Data/`: the clips (~1 MB for 44 lines) and the **whole-game** index (~124 MB raw, ~7 MB deflated). Keep the index in its own deflated pak rather than your store-only data pak.
- **Ship both or neither.** An index naming clips you did not ship costs vanilla NPCs their lipsync too; `PackageMod.bat` fails the build if only one is present.
- **Two mods that each ship an index cannot coexist**; load order picks one ([mod-structure.md](mod-structure.md#load-order)).
- **Regenerate after every game update** that adds dialogue.

The superseded alternative, byte-patching a vanilla single-clip `.dba` to point at your StringName (`tools/facial_retarget.py`), still needs an index entry, so it saves nothing over baking (lipsync.md).

### Fallback: a generic moving mouth from Lua

`entity:EnableProceduralFacialAnimation(false)` then `entity:PlayFacialAnimation("fa_cin_talk_neutral_01", true)` gives any NPC a talking face for any line, obviously generic ([Entity.PlayFacialAnimation](api/Entity.md#playfacialanimation), [Entity.EnableProceduralFacialAnimation](api/Entity.md#enableproceduralfacialanimation); vanilla precedent `Scripts/Entities/Physics/DeadBody.lua`).

### Dead ends

- FaceFX: absent (no OC3/Annosoft strings); `ShouldFaceFxOverrideHead` is only a flag name.
- Procedural phoneme lipsync: `ca_lipsync_phoneme_crossfade` / `_offset` / `_crossfade_attenuation` exist but no phoneme data ships.
- `facial_chewing_01` (declared in `BasicActor.lua`) does not exist in KCD2; the real clip is `fa_chew_loop`.
- `Animations/DBATableFacials.json` is build-time only; the runtime never reads it.
- No `.fsq`/`.fxl`/morph targets; heads are joint-rigged (`FA_LOD0_*_jnt`).

All from lipsync.md (retail binary).

### Testing and debugging lipsync

- The dev build has no `Data/Facials`: logs `[Localization] Facial pak can't be opened`, `Missing language img 'animations/FacialAnimations.img'`, and hundreds of `Invalid anim ref ... on scope 'FacialExpression'`. Junction the retail folder in: `mklink /J "<KCD2Mod>\Data\Facials" "<KCD2>\Data\Facials"`; remove it with plain `rmdir`, never `rmdir /S` (lipsync.md).
- Cvars `ca_DebugFacial`, `ca_lipsync_debug`. Log strings: `No '%s' default animation found for face '%s'. Automatic lip movement will not work.`, `[DIALOG] CDialogActorContext::DoFacialExpression: %s Cannot find '%s' for Entity '%s'`.
- Separate from lipsync: `Function_speech_*` BT calls take `animationApproach` (`dontPlayDialogAnimations`, `tryDialogAnimations`, `playDialogAnimationsIfFaderDialog`, `ingameDialogPoseAndAnimations`, from `ai_enums.xml`), which gates the gesture and facial-mood commands of a dialogue (lipsync.md).

## Barks

- Vanilla barks are per-voice line pools addressed by **metarole** (`SAMOMLUVA`, `BATTLE_IDLE_BARK`, `GOSSIP`, `NPC_VYHRALO_SKIRMISH`, ...), played from a BT with `Function_speech_schedulerMonolog(metarole=...)`. Catalogue with English glosses: [talking.md](../behaviour-trees/talking.md).
- Custom barks are `ingame monolog` dialogues addressed by `alias` ([skald-quests-dialog.md](skald-quests-dialog.md#monologs-and-barks)); they follow the same file-naming rule, so each voice that can speak one needs its own `.ogg`.
- **Combat hit, death and wounded lines are gendered Storm roles, not a node.** Vanilla `Libs/Storm/roles/world/combat.xml`
  hands `<isMan/>` souls the `_MUZ` roles (`ZASAH_ZBRANI_SILNY_MUZ`, `RANENY_NA_ZEMI_MUZ`, `SMRTELNY_ZASAH_MUZ`, ...) and
  `<isWoman/>` souls the `_ZENA` twins, and gender comes from the soul archetype. A soul of archetype 0 (male) given a
  female voice therefore draws `_MUZ` lines its voice never recorded; swap the roles with a Storm rule. A voice with no
  recording for a role falls back along `voice.xml`'s `fallback_voice_id` chain, which is reported never to cross gender,
  so the worst case for the ungendered grunts is silence (vanilla roles; fallback behaviour claimed from
  female-mercenaries.md, not confirmed by ear).
- Bubble text above heads is governed by `wh_dlg_ChatBubbles*` cvars (distance, offsets, scale) (retail binary; [console-variables.md](console-variables.md)).
- A bark loop gated by a BT `Wait timeType="GameTime"` free-runs during sleep or time skip and produces a bark storm; use real time (interior-detection.md, verified in game).

## Sound effects and music

- Middleware: FMOD Studio (`fmod.dll` imports, `CWh_AudioImplFmod`, `FMOD version` log line) behind CryEngine ATL. The `s_AudioSystemImplementationName` help text still says `CryAudioImplWwise` (stock CryEngine leftover) (retail binary).
- Banks: `Data/Sounds.pak` → `Sounds/fmod/Build/pc/*.bank` (345 files). ATL controls: `IPL_GameData.pak` → `Libs/GameAudio/*.xml` (`ui.xml`, `combat.xml`, `quests.xml`, `music*.xml`, ...), each `<ATLTrigger atl_name="..">` wrapping an FMOD event name (retail paks).
- Lua, vanilla pattern (`Scripts/Utils/AudioUtils.lua`, entity audio scripts): [Sound.GetAudioTriggerID(name)](api/Sound.md#getaudiotriggerid) → [entity:ExecuteAudioTrigger(id, entity:GetDefaultAuxAudioProxyID())](api/Entity.md#executeaudiotrigger), stop with [StopAudioTrigger](api/Entity.md#stopaudiotrigger); RTPCs via [Sound.SetAudioRtpcValue](api/Sound.md#setaudiortpcvalue) or [entity:SetAudioRtpcValue](api/Entity.md#setaudiortpcvalue), switches via [entity:SetAudioSwitchState](api/Entity.md#setaudioswitchstate). The legacy CryEngine `Sound.Play`/`Sound.PlayEx`/`Entity.PlaySound` binds are documented but have no retail confirmation on their API pages; prefer the ATL route.
- Skald: `wh::soundmodule` has `AudioOneShot`, `AudioSustainedEffect`, `AudioRtpc`; `wh::musicmodule` has `MusicEvent`, `MusicState` (retail `definitions.xml`). Lua: `MusicLogic.SendEvent`/`SetEvent` are documented only (API pages).
- Data: the `music/*` and `GameAudio/SkaldAtlTrigger` / `SkaldAtlRtpc` tables are "unsupported, must replace whole"; `rpg/rpg_sound` is an old table (official wiki KM-A-12; [data-tables.md](data-tables.md#table-generations-and-what-a-patch-must-contain)).
- New sounds: no mod has been documented adding its own FMOD bank or ATL trigger. A script-extender route exists (KCD2ModLoader hooks FMOD `getevent` for replacement; its bank loading is "untested") ([sources.md](sources.md), community). Treat custom SFX as unverified territory. Replacing an existing event's audio requires overriding a whole `.bank`.
- Area labels include ~40 `music_*` labels on level trigger areas, readable like `interior` (interior-detection.md).

## Gotchas

- **Custom line shows a subtitle but is silent:** wrong folder (namespace path), wrong prefix (not the speaker's `voice.xml` abbreviation), or you reused a vanilla StringName without copying its `.ogg` (kleinkrieg-voice-lines.md, [add-new-npc.md](../xml/add-new-npc.md)).
- **Dialogue with an unvoiced role hangs, then times out:** add `SelectedSouls` and `VoiceoverFallbackLevel` (mod `aleksej_dialog.xml`).
- **Every merc sounds like the same actor (or a woman):** a borrowed line exists as one take copied under several prefixes (squad-orders.md).
- **Custom line plays with a frozen face:** no facial clip of that name in the index (lipsync.md).
- **After installing your mod, vanilla NPCs' lips stop moving:** you shipped an index without its clips, or a partial index (lipsync.md).
- **Lipsync build "succeeds" but nothing moves:** audio was staged flat, so index paths point nowhere (lipsync.md).
- **No lipsync at all while testing in the dev build:** it has no `Data/Facials`; junction it or test in retail (lipsync.md).
- **New vanilla dialogue lost its face after a game patch:** your shipped index predates it; regenerate (lipsync.md).
- **A female-voiced NPC is silent when hit or killed:** its soul is archetype 0, so Storm gives it the
  `_MUZ` combat roles; swap them for the `_ZENA` twins (female-mercenaries.md).
- **Barks spam after sleeping:** `GameTime` waits expire instantly during time skips (interior-detection.md).
- **Subtitles run too fast or cut off:** `ReferenceLength` missing or shorter than the take; recompute after trimming audio (voice-mastering.md).

## See also

- [skald-quests-dialog.md](skald-quests-dialog.md): dialogue structure, monologs, forced dialogue.
- [data-tables.md](data-tables.md): `skald_character`, `voice.xml`, soul rows.
- [mod-structure.md](mod-structure.md): where the voice and facial paks go.
- Public guides: voice-acting.md, voice-mastering.md, [talking.md](../behaviour-trees/talking.md).
