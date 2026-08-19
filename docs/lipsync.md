# Lipsync: making custom dialogue move the lips

For a long time this wiki said KCD2's lip sync was a proprietary pipeline we couldn't
touch. That was wrong. It is stock CryEngine facial animation, the content is plain
files in the paks, and the rule that binds a face to a line is simple enough to exploit.

## The binding rule

A line's facial animation and its voice audio are **the same name at the same relative
path**, under two different roots. Both roots are cvars in `WHGame.dll`:

| asset | cvar | root |
|---|---|---|
| voice | `wh_dlg_VoiceRoot` | `Localization/dialog` |
| facial | `wh_dlg_DBARoot` | `Animations/humans/facials/dialog` |

The filename is `<voiceAbbrev>_<StringName>`, lowercased on the facial side:

```
Localization/English/dialog/kutnohorsko/prepadeniVlasskehoDvora/bohuta__cirkevni_rada/emac_cp_t_bohuta_pl_a_byla_to__Tydj.ogg
Animations/humans/facials/dialog/kutnohorsko/prepadenivlasskehodvora/bohuta__cirkevni_rada/emac_cp_t_bohuta_pl_a_byla_to__tydj.caf
```

`voiceAbbrev` comes from the speaker's `skald_character.voice_id`, resolved through
`Libs/Tables/skald/voice.xml`. Ours: **243 = `rlaz`** (quartermaster), 239 = `jcom`,
106 = `sbar`, 132 = `phos2`. 108 = `tmck` is Henry.

This is the same rule [`tools/prefix_ogg.bat`](../tools/prefix_ogg.bat) already exploits to
make a merc "speak" a vanilla line — it just copies the `.ogg` under a new voice prefix.
The face works identically, one extension over.

**So custom lines have frozen faces for a boring reason:** nothing named
`rlaz_merc_qm_alchemy` exists in the facials set, so the lipsync provider finds no clip.

## Where the clips live

~19,800 per-line facial clips ship as `.dba` containers in
`Data/Facials/Facials_english-part0/1/2.pak`. A `.dba` is a CryEngine chunk file
(`CrCh` + version + chunk count + table offset) whose chunk data embeds the clip's path
as a **u16 length-prefixed string with no name hash anywhere**.

Both human skeletons wildcard-load the whole folder, which is why any clip in it is
addressable by name — `male.chrparams` / `female.chrparams` (in `IPL_Characters-part3/1.pak`):

```xml
<!-- Facials must be always last in the list -->
<Animation name="$TracksDatabase" path="Animations\humans\facials\*.dba" />
<Animation name="#filepath" path="Animations\humans\facials"/>
<Animation name="*" path="*\*.caf"/>
```

There is also a generic library, `Animations/humans/facials/facials.dba`, with 258 clips
loaded for every human: `fa_cin_talk_neutral_01`, `fa_cin_talk_happy_01/02/var01`,
`fa_cin_talk_drunk`, `fa_chew_loop`, `fa_open_mouth`, plus every mood idle.

## Retargeting a vanilla clip onto our line

Because the clip name is a length-prefixed string with no checksum, a vanilla single-clip
`.dba` can be re-pointed at one of our StringNames byte-wise. That is what
[`tools/facial_retarget.py`](../tools/facial_retarget.py) does:

1. Index every single-clip `.dba` in the Facials paks (1,384 of them), and get each one's
   true length by reading the Ogg granule position of its original voice line.
2. For each target StringName, estimate the spoken length from the subtitle text
   (~14.5 chars/sec) and pick the closest unused donor. The quartermaster's own voice
   actor (`rlaz`) wins ties within 0.4s, so a chunk of the set is literally his face.
3. Rewrite the embedded path to `.../mercenaries_background_quest/rlaz_<stringname>.caf`,
   patching the u16 length and — if the length changed — every affected chunk offset.
4. Write to `data/Animations/humans/facials/dialog/merc_facial_<stringname>.dba`.

```bash
python tools/facial_retarget.py
```

`--rebuild-index` rescans the game paks (a few minutes); otherwise it reuses
`tools/facial_donors.json`. `PackageMod.bat` zips `data/` wholesale, so the files land at
the right pak path with no packaging change.

The lipsync is real lipsync — just of a different sentence. It reads as someone talking,
which is the entire point; frozen lips read as broken.

### Doing it for reused vanilla audio

For barks and gossip, the mod ships *vanilla* `.ogg` files renamed with a new voice
prefix. There the original line's facial clip **already exists** — patching only the
4-character voice prefix (`emac_` → `jcom_`) is a same-length, zero-shift edit and gives
*correct* lipsync, because it is the same line. Worth doing for `voice/barks` and
`voice/gossip` if the retargeted set proves out.

## Current coverage

The 30 `merc_qm_*` quartermaster hub lines — the ones the player hits every session.
Durations match within ~0.3s. Not yet covered: `merc_provider_*`, `merc_logi_tut_*`, and
the `merc_kk_*` Kleinkrieg lines (many of those run past 9s, longer than any single-clip
donor; they need a multi-clip donor split, or the Lua fallback below).

## Fallback: force a generic talking face from Lua

`PlayFacialAnimation(name, looping)` and `EnableProceduralFacialAnimation(enable)` are
script-binds on every entity. Vanilla precedent in `Scripts/Entities/Physics/DeadBody.lua`:

```lua
self:EnableProceduralFacialAnimation(false)
self:PlayFacialAnimation("death_pose_0"..random(1,5), true)
```

So `System.GetEntity(id):PlayFacialAnimation("fa_cin_talk_neutral_01", true)` gives any NPC
a moving mouth for any line, at the cost of being obviously generic. Useful for the long
Kleinkrieg lines where no donor is long enough.

## Dead ends — don't retry these

* **FaceFX.** Not present. Zero OC3/Annosoft strings in the binaries. The
  `ShouldFaceFxOverrideHead` attribute in `dialogue_animation.xml` is a misleading
  Warhorse flag name, nothing more.
* **Procedural phoneme lipsync.** `ca_lipsync_phoneme_crossfade` / `_offset` /
  `_crossfade_attenuation` exist, but **no phoneme data ships** — legacy CryEngine cvars
  with nothing feeding them. You cannot generate lipsync from our own audio this way.
* **`facial_chewing_01`.** `BasicActor.lua` declares it as the LipSync default. It does
  not exist in KCD2 — stale KCD1 name. Use `fa_chew_loop`.
* **`Animations/DBATableFacials.json`.** An offline asset-build table; the string does not
  appear in the runtime binaries. Editing it does nothing.
* **`.fsq` / `.fxl` / morph targets.** No such format here. Heads are joint-rigged
  (`FA_LOD0_*_jnt`).

## Testing: the dev build ships no facial data

**The `KCD2Mod` dev build has no `Data/Facials` directory.** Nobody's lips move there —
not ours, not vanilla's — so any lipsync test run against it is meaningless. The tell:

```
[Localization] Facial pak can't be opened 'data/facials/facials_english.pak'
[Warning] Validator: Missing language img 'animations/FacialAnimations.img'
CharacterManager::OnFacialsPakChanged() m_LanguageGahBaseIndexStart: 0, m_LanguageGahBaseIndexEnd: 0
[Warning] Validator: Invalid anim ref 'fa_idle_neutral_01' on scope 'FacialExpression' ...
```

That last warning repeats hundreds of times — the generic library clips don't resolve
either. Retail logs none of them.

Point the dev build at the retail data with a junction (no disk cost, reversible):

```bash
mklink /J "C:\Program Files\Steam\steamapps\common\KCD2Mod\Data\Facials" "C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Data\Facials"
```

Remove it with `rmdir` (no `/S` — that would follow the link into the retail install).

The alternative is testing in retail via `PackageMod.bat`, but the release exe logs
almost nothing (~100 KB, a dozen warnings), so a failure there tells you nothing.

## Debugging

`merc_face [clip]` plays a facial animation on the quartermaster and logs whether the
script-bind exists and whether the call succeeded. It isolates the failure:

* `merc_face` — generic library clip; proves the facial pipeline runs at all.
* `merc_face rlaz_merc_qm_alchemy` — one of our retargeted names; proves the shipped
  `.dba` was loaded and registered.

`ca_DebugFacial` and `ca_lipsync_debug` draw facial playback info. Useful log strings:

```
No '%s' default animation found for face '%s'. Automatic lip movement will not work.
[DIALOG] CDialogActorContext::DoFacialExpression: %s Cannot find '%s' for Entity '%s'
```

## Related

Every `Function_speech_*` node in `data/AI/*.xml` currently passes
`animationApproach="$enum:animationApproach.dontPlayDialogAnimations"` — the most
restrictive of the four values in `ai_enums.xml` (the others being `tryDialogAnimations`,
`playDialogAnimationsIfFaderDialog`, `ingameDialogPoseAndAnimations`). That gates the
`AnimationCommand` / `FacialMoodCommand` gesture pipeline, which is separate from the
baked lipsync above. Flipping it is a one-word experiment, untested.
