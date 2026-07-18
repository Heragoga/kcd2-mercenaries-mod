# Cutscenes: why a mod can't play one

**Verdict: a mod that doesn't ship level data cannot play any cutscene. Tried,
confirmed, reverted. Don't attempt it again without reading this.**

This applies to *every* cutscene type — prerendered `.bk2` (`RenderedCutscene`),
`IngameCutscene`, `TrackViewCutscene`, `FaderCutscene`, `FastTravelCutscene`,
`SkipTimeCutscene`. They all go through the same gate.

## How cutscenes actually work

Four pieces, and the fourth is the wall.

**1. The video/scene is declared in a table** — `Libs/Tables/ui/cutscene.xml`:

```xml
<RenderedCutscene Name="story_switch_to_trosecko"
                  Root="videos\m01\cin_m0110t_prepadeni__intro_cutscene"
                  Subtitles="cin_m0110t_prepadeni__intro_cutscene">
  <Profiles><Profile Type="Default" FileName="cin_m0110t_prepadeni__intro_cutscene" /></Profiles>
  <Events>
    <Event Type="SkipPoint" StartFrame="984"/>
    <Event Type="CustomText" StartFrame="158" EndFrame="336"
           StringData="cin__vypravec__o_neco_dri_Di5A" Layout="CenterBottom" />
  </Events>
</RenderedCutscene>
```

`Name` is what everything refers to — never the `.bk2` filename. There are ~95
`RenderedCutscene` entries. Mods *can* add entries additively as
`Libs/Tables/ui/cutscene__<modid>.xml` (vanilla does it with
`cutscene__autotests.xml`). **This layer is not the problem.**

**2. A `CutsceneHolder` entity names it** — a bare data entity
(`Scripts/Entities/WH/CutsceneData/CutsceneHolder.lua`) whose only property is
`esCutsceneName`, set to the `Name` from step 1.

**3. A quest `CutsceneHandler` node plays it:**

```xml
<CutsceneHandler Name="cutscene">
  <Asset Name="CutsceneHolder" Alias="my_cutscene" />
  <Edge From="something.OnTrigger" To="EnqueueCutscene" />
</CutsceneHandler>
```

In: `EnqueueCutscene`, `PlayCutscene`, `FinishCutscene`, `AutoPlay`, `AutoFinish`.
Out: `OnQueued`, `BeforePlay`, `AfterPlay`, `OnFinished`.

**4. The asset must resolve to a real entity — and this can only happen in level
data.**

## The wall

`CutsceneHandler`'s `CutsceneHolder` port is
`Type="wh::entitymodule::CutsceneHolder*"` with `IsOptional="false"` — a
**required entity pointer**. There is no variant taking a cutscene name as a
string, and no quest node anywhere resolves an entity by name or GUID. The only
way to get an entity into a quest is an `<Asset>`.

Quest assets have no GUID attribute — only `Name` and `Comment`. They bind through
a `SmartObjectHolder` entity named exactly after the `<Quest>` (the "QSO"),
carrying one `EntityLink` per asset:

```xml
<Entity Name="prepadeni" EntityClass="SmartObjectHolder" EntityId="45923">
  <EntityLinks>
    <Link TargetId="45822" Name="asset['dogNearVoves']" />
  </EntityLinks>
</Entity>
```

The link is what binds. Entity *names* are cosmetic — `prepadeni_ dogNearVoves`
has a typo'd space and still works. QSOs carry no quest GUID either;
`open_world`'s entire property block is `<Properties bSaved_by_game="0" />`, so
the quest↔QSO association is purely the entity name.

**There is no Lua API.** The only movie bind is `Movie.PlaySequence` /
`Movie.StopAllCutScenes` — TrackView sequences, not Bink video. No UI bind plays
a video. `wh_sys_StartupVideoName` / `wh_sys_MainMenuVideoName` only cover startup
and main menu. `LevelSwitch.xml`'s `Video=` only fires on a level transition.

## What was tried, and why it failed

Vanilla proves asset links are **runtime-mutable**: the crime system rebinds a
`CutsceneHolder` from a BT right before use
(`AI/crime/preparePunishmentForConcept.xml`):

```xml
<AddLink From="$qso_openworld" To="$teleportPoint"
         Tag="'asset'" Data="'punishment_teleportPoint'" />
```

against `<CutsceneHolderAsset Name="punishment_cutscene"
Comment="AI will link this asset right before arrest dialogue" />`. Level data
spells that same link `asset['punishment_cutscene']`; from Lua it's
`entity:CreateLink("asset['punishment_cutscene']", targetId)`. Both
`CutsceneHolder` and `SmartObjectHolder` are plain Lua-spawnable classes.

So the attempt was: spawn a `CutsceneHolder`, spawn a `SmartObjectHolder` named
`mercenaries_background_quest`, link them, and let the quest resolve it.

**Every part verified except the one that mattered:**

```
qso name        : mercenaries_background_quest   <- correct name
qso links       : 1
link            : asset['qm_tutorial_cs']
link -> target  : MercQmTutorialCutsceneHolder   <- real target, not dangling
esCutsceneName  : story_switch_to_trosecko       <- property set
```

Nothing played — not a `RenderedCutscene`, not `crime_pillory_kutnahora_firstRun`
(a real `.bk2` vanilla plays *through a runtime-linked asset*), and not
`crime_fader`, a `FaderCutscene` with no video pak behind it at all. A fader
failing rules out video packing/streaming entirely and indicts the binding.

**Why it can't work.** The quest activates from `<Edge From="OnWake" To="run" />`
— at *level wake*. Assets resolve then. Lua can't spawn anything that early
(`OnGameplayStarted` is already too late), so the QSO never exists when the quest
looks for it. Vanilla's runtime `AddLink` only ever *re-points* an asset on a QSO
that was **baked into the level**; it never conjures the QSO. Every vanilla QSO is
level-baked, and even the crime BT finds its own QSO via a level-authored link
from `$__land` rather than by name.

Dead ends ruled out along the way, so nobody re-checks them:

* Not the dialog: `EndType="GoTo"` + `<Triggers>` is valid — 953 vanilla GoTo
  sequences do exactly that.
* Not the quest structure: `drak` (~10 cutscenes) uses the same
  assets-on-the-`<Quest>` + `Alias`-on-the-node shape.
* Not the QSO name: `prepadeni` is a `<Quest>` nested in `trosecko.xml` and its
  QSO is named `prepadeni` — the Quest name, which is what we used.
* Not the link: read back and verified non-dangling. (Watch out — `CreateLink`'s
  `targetId` is *optional*, so a rejected id yields a dangling link that still
  looks like success. Always read it back with `GetLinkTarget`.)

## What would actually work

Ship the `CutsceneHolder` **and** the `asset['...']` link on a quest-named
`SmartObjectHolder` in `objects_mission0.xml`, with `modifies_level=true`. That's
a 22 MB level file that conflicts with every other level-modifying mod. For a
tutorial cutscene that trade is not worth it — the tutorial stayed as spoken
dialog.

Same class of wall as [the camp forge](camp-forge.md): an engine feature locked to
level-baked entities.
