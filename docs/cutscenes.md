# Playing cutscenes from a mod

How the prerendered (`.bk2`) cutscenes work, why a mod can't play one the way
the base game does, and the runtime workaround this mod uses.

> **Status: experimental.** The last step (a runtime-spawned QSO) is unproven.
> See [Does it actually work?](#does-it-actually-work) before relying on it.

## The four layers

Playing `cin_m0110t_prepadeni__intro_cutscene.bk2` takes four separate pieces.

**1. The video is declared in a table.** `Libs/Tables/ui/cutscene.xml`:

```xml
<RenderedCutscene Name="story_switch_to_trosecko"
                  Root="videos\m01\cin_m0110t_prepadeni__intro_cutscene"
                  Subtitles="cin_m0110t_prepadeni__intro_cutscene">
  <Profiles>
    <Profile Type="Default" FileName="cin_m0110t_prepadeni__intro_cutscene" />
  </Profiles>
  <Events>
    <Event Type="SkipPoint" StartFrame="984"/>
    <Event Type="CustomText" StartFrame="158" EndFrame="336"
           StringData="cin__vypravec__o_neco_dri_Di5A" Layout="CenterBottom" />
  </Events>
</RenderedCutscene>
```

`Name` is what everything else refers to — never the `.bk2` filename. `Events`
carry the skip points and burned-in captions. Vanilla `.bk2` files already have
an entry, so you usually don't need a new one; if you do, mods can add them
additively as `Libs/Tables/ui/cutscene__<modid>.xml` (the base game does exactly
this with `cutscene__autotests.xml`).

The same table also holds `IngameCutscene`, `TrackViewCutscene`, `FaderCutscene`,
`FastTravelCutscene` and `SkipTimeCutscene`. **Everything below applies to all of
them** — the wall is not specific to prerendered video.

**2. A `CutsceneHolder` entity names the cutscene.** It's a bare data entity
(`Scripts/Entities/WH/CutsceneData/CutsceneHolder.lua`) whose only property is
`esCutsceneName`, set to the `Name` from step 1.

**3. A quest `CutsceneHandler` node plays it.**

```xml
<CutsceneHandler Name="cutscene">
  <Asset Name="CutsceneHolder" Alias="my_cutscene" />
  <Constant Name="AutoPlay" Value="false" />
  <Edge From="something.OnTrigger" To="EnqueueCutscene" />
</CutsceneHandler>
```

In: `EnqueueCutscene`, `PlayCutscene`, `FinishCutscene`, `AutoPlay`, `AutoFinish`.
Out: `OnQueued`, `BeforePlay`, `AfterPlay`, `OnFinished`. Use `BeforePlay` to set
up state (the base game starts faders and timers off it) and `AfterPlay` /
`OnFinished` to continue the quest.

**4. The asset must resolve to a real entity.** This is the wall.

## Why it's a wall

The `CutsceneHolder` port is `Type="wh::entitymodule::CutsceneHolder*"` and
`IsOptional="false"` — a required *entity pointer*. There is no variant that
takes a cutscene name as a string, and no quest node anywhere that looks an
entity up by name or GUID. The only way to get an entity into a quest is an
`<Asset>`.

Quest assets have no GUID attribute — only `Name` and an optional `Comment`:

```xml
<Assets>
  <CutsceneHolderAsset Name="my_cutscene" />
</Assets>
```

They bind through **level data**. Each quest has a `SmartObjectHolder` entity
named exactly after the quest (the "QSO" — e.g. `open_world`, `prepadeni`),
carrying one `EntityLink` per asset:

```xml
<Entity Name="prepadeni" EntityClass="SmartObjectHolder" EntityId="45923">
  <EntityLinks>
    <Link TargetId="45822" Name="asset['dogNearVoves']" />
  </EntityLinks>
</Entity>
```

The link is what binds; entity *names* are cosmetic. (`prepadeni_ dogNearVoves`
has a typo'd space in it and still works.)

**There is no Lua API for any of this.** The only movie bind is
`Movie.PlaySequence` / `Movie.StopAllCutScenes`, which drives TrackView
sequences, not Bink video. No UI bind plays a video. The video cvars
(`wh_sys_StartupVideoName`, `wh_sys_MainMenuVideoName`) only cover the startup
and main-menu videos, and `LevelSwitch.xml`'s `Video=` attribute only fires on a
level transition.

So a mod that can't ship level data has no *supported* way to play any cutscene.

## The escape hatch: asset links are runtime-mutable

Quest asset links are **not** frozen at load. The crime system rebinds a
`CutsceneHolder` from a behaviour tree right before it's needed
(`AI/crime/preparePunishmentForConcept.xml`):

```xml
<AddLink From="$qso_openworld" To="$teleportPoint"
         Tag="'asset'" Data="'punishment_teleportPoint'" LinkOpHandleMode="Success" />
```

matching a quest asset declared as:

```xml
<CutsceneHolderAsset Name="punishment_cutscene"
                     Comment="AI will link this asset right before arrest dialogue" />
```

Note the spelling. Level data writes the link name as `asset['punishment_cutscene']`;
the BT reads the same link as `Tag='asset'` + `Data='punishment_cutscene'`. From
Lua, `entity:CreateLink("asset['punishment_cutscene']", targetId)` is the same thing.

Both `CutsceneHolder` and `SmartObjectHolder` are ordinary Lua entity classes, so
`System.SpawnEntity` can create them.

## What this mod does

`mercenaries_cutscene.lua`, on every load:

1. Spawns a `CutsceneHolder` with `esCutsceneName = "story_switch_to_trosecko"`.
2. Spawns a `SmartObjectHolder` named `mercenaries_background_quest` (our QSO).
3. `qso:CreateLink("asset['qm_tutorial_cs']", holder.id)`.

The quest declares `<CutsceneHolderAsset Name="qm_tutorial_cs" />` and a
`CutsceneHandler` wired from the dialog's `quartermaster_tutorial` port. The
binding is session-only — spawned entities don't survive a save, so it reruns on
each load.

Console commands: `merc_cutscene_bind` (respawn + relink), `merc_cutscene_status`
(read the link back), `merc_cutscene_name <name>` (swap which `RenderedCutscene`
plays; respawns the holder, since `esCutsceneName` is read off the entity).

## Naming the QSO

The QSO is named after the **`<Quest>`**, not the project or file. `prepadeni` is
a `<Quest Name="prepadeni">` nested inside `trosecko.xml`, and its QSO entity is
called `prepadeni`. So ours is `mercenaries_background_quest`.

QSO entities carry **no quest GUID** — `open_world`'s whole property block is
`<Properties bSaved_by_game="0" />`. The quest↔QSO association really is just the
entity name, which is what makes a spawned QSO conceivable at all. Level-baked
QSOs additionally carry `module` links and a self-link (`asset['openworld']` →
itself); ours has neither, and whether that matters is unknown.

## Does it actually work?

The unproven step is **3 → the quest adopting a runtime-spawned QSO**. Every
vanilla QSO is baked into the level, and even the crime BT finds its QSO through
a level-authored link from `$__land` rather than by name. If the quest resolves
"which entity is my QSO" once at level load, a QSO spawned afterwards is invisible
and the `CutsceneHandler` has nothing to play.

**Status: the link verifies, but no cutscene has played yet.** Diagnostic ladder,
in order — each step rules out one layer:

1. `merc_cutscene_status` → `link -> target : MISSING (dangling)` means
   `CreateLink` silently rejected the target id (its `targetId` argument is
   *optional*, so a bad id still "succeeds"). Lua-side, fixable.
2. `merc_cutscene_test_fader` → swaps to `crime_fader`, a `FaderCutscene` with no
   video pak behind it. **If the screen fades, the entire chain works** — dialog
   port, quest, handler, asset, spawned QSO, spawned holder — and the problem is
   only which cutscene was picked. If it doesn't, the QSO isn't being adopted.
3. `merc_cutscene_name crime_pillory_kutnahora_firstRun` → a real `.bk2`
   (`videos\s99\cin_s9915k_crime__pillory_kutnahora`) from the crime video set,
   and the one vanilla plays *through a runtime-linked asset*. The closest
   working analogue there is.

Beware the default: `story_switch_to_trosecko` is a **level-switch** video, only
ever referenced from `LevelSwitch.xml`, and its `videos\m01\...` pak may not be
mounted outside Trosecko. It is a poor test subject — prefer step 3's video.

If step 2 fails, the QSO hypothesis is dead and no amount of Lua fixes it. The
only known-good alternative is shipping the `CutsceneHolder` and the asset link in
`objects_mission0.xml` with `modifies_level=true` — a 22 MB level file conflicting
with every other level-modifying mod. Weigh that against not having a cutscene.

Compare [the camp forge](camp-forge.md): another engine feature locked to
level-baked entities.
