---
title: Scaleform UI
summary: How to put anything on screen in KCD2 - the UIAction Lua bridge, vanilla elements you can drive, shipping your own .swf, map/compass markers, immediate-mode drawing, fonts and metrics, and input for custom screens.
tags: [ui, lua, engine, assets]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# Scaleform UI

## TL;DR

- The whole UI is CryEngine **Scaleform Flash** (SWF v8 / **ActionScript 2**, no AS3 anywhere) driven from Lua by the
  **`UIAction`** scriptbind. Every screen is `Libs/UI/<Name>.gfx` + a contract `Libs/UI/UIElements/<Name>.xml`
  (verified in game; retail binary).
- Pick **your own `instanceID`** and you get a private instance of any vanilla element (e.g. `Menu`) that does not
  fight the game's copy (verified in game; KCD2 Companion mod).
- A mod **can** register a brand-new element and ship a plain **`.swf`** when `wh_gfx_useSWF = 1` is set in
  `user.cfg` *before launch* - no Scaleform licence or exporter needed (retail binary + verified in game).
- **`SetScale`/`SetAlpha` take percent** (100 = natural), `SetPos` takes **stage units**; a movie is only built on
  first display, so defer the first layout (verified in game).
- Almost every failure is **silent** (no log, no checkerboard). Validate offline (`tools/kcdui check`) and poll
  element state rather than guessing.
- Immediate mode is five `System.Draw*` calls, lines and text only, and needs a per-frame `OnUpdate` in an entity
  `Client`/`Server` sub-table (verified in game).

## The stack

| Piece | Where | Notes |
| --- | --- | --- |
| Movie | `Data/Libs/UI/*.gfx` | `CFX` container: 4-byte magic, 4-byte length, zlib stream of an ordinary SWF tag stream; SWF 8, AS2, 38 files, no `DoABC` (verified: ui.md) |
| Contract | `Data/Libs/UI/UIElements/*.xml` | element `name`, `GFx file`/`layer`, `functions`, `events`, `variables`, `arrays`, `MovieClips`, `templates` (vanilla: `Libs/UI/UIElements/`) |
| Lua bridge | `UIAction` table ([api](api/UIAction.md)) | `CScriptBind_UIAction`; no shipped vanilla `.lua` calls it - Warhorse drives UI from UI flowgraph XML and ActionScript, so there is no vanilla example to copy (vanilla Scripts grep) |
| Loose on disk | `Data/Libs/UI/` also mirrored in `IPL_GameData.pak` | a mod folder overrides it like any other `Data/*` path |

Root attributes the element parser accepts (retail binary): `layer`, `fullscreen`, `basedOnSpec`, `screen_resize`,
`shared_rt`, `halign`, `valign`, `mouseevents`, `keyevents`, `cursor`, `console_cursor`, `console_mouse`,
`controller_input`, `events_exclusive`, `render_lockless`, `force_no_unload`, `fixed_proj_depth`, `lazy_update`, `is_Hud`.

Vanilla layers (vanilla: `Libs/UI/UIElements/*.xml`, `GFx layer=`):

| Layer | Element(s) |
| --- | --- |
| 0 | `ApseMap`, most Apse list screens, `AlchemyBook`, `GeneralBook`, `ForgeBuilderPlan` |
| 5 | `Overlay` |
| 10 | `LockPicking` |
| 20 | Apse detail panes (`ApseCharacter`, `ItemTransfer`, `ItemSelection`, ...) |
| 25 | `hud` |
| 27 / 30 / 35 / 36 | `Pickpocketing` / `HorseInspect` / `SkipTime` / `ApseModalDialog` |
| 40 / 45 / 50 / 80 | `GameOver` / `Menu` / `LoadingScreen` / `Progress` |

## UIAction - the Lua bridge

Full signatures: [api/UIAction.md](api/UIAction.md). The load-bearing ones:

| Group | Calls |
| --- | --- |
| Lifecycle | [`ShowElement`](api/UIAction.md#showelement) (creates the instance if absent), [`HideElement`](api/UIAction.md#hideelement), [`RequestHide`](api/UIAction.md#requesthide) (movie fades itself), [`ReloadElement`](api/UIAction.md#reloadelement), [`UnloadElement`](api/UIAction.md#unloadelement) |
| ActionScript | [`CallFunction`](api/UIAction.md#callfunction), [`SetVariable`](api/UIAction.md#setvariable)/[`GetVariable`](api/UIAction.md#getvariable), [`SetArray`](api/UIAction.md#setarray)/[`GetArray`](api/UIAction.md#getarray) |
| Clip transforms (no AS needed) | [`SetPos`](api/UIAction.md#setpos), [`SetScale`](api/UIAction.md#setscale), [`SetRotation`](api/UIAction.md#setrotation), [`SetAlpha`](api/UIAction.md#setalpha), [`SetVisible`](api/UIAction.md#setvisible), `Get*`/[`IsVisible`](api/UIAction.md#isvisible), [`GotoAndStopFrameName`](api/UIAction.md#gotoandstopframename) |
| Events in | [`RegisterElementListener`](api/UIAction.md#registerelementlistener), [`RegisterEventSystemListener`](api/UIAction.md#registereventsystemlistener) (e.g. `"System"`, `"OnGameplayStarted"`), [`RegisterActionListener`](api/UIAction.md#registeractionlistener), matching `Unregister*` |
| UI flowgraphs | [`StartAction`](api/UIAction.md#startaction), [`EndAction`](api/UIAction.md#endaction), `EnableAction`/`DisableAction` (`Libs/UI/UIActions/*.xml`) |

Rules (all verified in game unless noted):

- **`instanceID`**: `-1` = all instances (lazy init), `-2` = all initialised instances (retail binary help string).
  Any other number = your own instance. The Companion mod uses `47001` for `Menu`.
- **Listener callbacks are methods**: declare `function handler:Cb(elementName, instanceId, eventName, argTable)`.
  Declaring with a dot shifts every argument by one. `argTable` is **0-indexed**.
- **Unregister before re-registering.** Listeners registered on every `OnGameplayStarted` stack up;
  `UIAction.UnregisterElementListener(table, "")` drops all of that table's callbacks (script_bind docs; not in any
  element XML).
- **Units**: `SetScale`/`SetAlpha` are Flash `_xscale`/`_alpha` - **percent**. Passing `1` gives a 1%-size, 1%-opaque
  clip that looks exactly like a hidden or unloaded element. `SetPos` is in stage units of the movie.
- **`GetPos` on a non-existent element answers `(0,0)`** and `GetArray` returned 0 values even right after a
  `SetArray` that visibly worked - read-backs prove nothing without a control (verified in game: map-marker.md, ui.md).
- Method count: the official docs list 38, the runtime dump shows 33, 28 binds funnel through one native resolver
  (`CScriptBindUIAction::ResolveElementInstance`); the difference is docs-only/flowgraph helpers, not missing features
  (retail binary; runtime dump).

## Choosing an approach

| Need | Use | Cost |
| --- | --- | --- |
| One line of feedback | `Game.SendInfoText` / `ShowNotification` | needs a loc row in **every** `localization/*_xml.xml` or the raw key shows |
| Multi-line styled text panel | `hud` `ShowTutorial` / `SetSubtitles` with HTML | no assets |
| A list of buttons, sliders, confirms | vanilla **`Menu`** on a private instance | no assets; vertical list only |
| Labels over world objects | `hud` **`bubble1..16`** + `SetPos` | 16 max |
| Free layout, bars, icons, grids, a map | **your own `.swf` element** | tooling + a hand-written driver |
| Debug overlay | `System.DrawText` from an `OnUpdate` | one draw call per call |
| Quest-only, no Lua | Skald nodes / `Dialogue Type="chat"` menu | text only |

## Vanilla elements worth driving

### `Menu` - a native list screen for free

From `UIElements/Menu.xml` (vanilla), proven end to end by the KCD2 Companion mod (`references/bodyguards`):
`PreparePage(ButtonXPos, ButtonYPos, MaxButtons, header, buttonHalfWidth)`, `ShowPage(userName)`, `ClearAll(type)`,
`AddBasicButton(id, containerIndex, uiText, tooltip, disable)`, `AddValueButton(...)` (slider),
`AddChoicesButton` + `AddChoiceOption`, `AddConfirmation(...)`, `SetDisable/SetValue/GetValue/SetChoice/GetChoice/
SelectButton`; events `OnButton(Id)`, `OnInteractiveValue`, `OnInteractiveChoice`, `OnConfirm(id, res)`.

```lua
local pid = 47001
UIAction.HideElement("hud", -1)
UIAction.CallFunction("Menu", pid, "ClearAll")
UIAction.CallFunction("Menu", pid, "PreparePage", 0, y, shown, title, 1)
ActionMapManager.EnableActionMap("menu", true)
UIAction.CallFunction("Menu", pid, "AddBasicButton", "b1", 0, "Label", "Tooltip", false)
UIAction.ShowElement("Menu", pid)
UIAction.RegisterElementListener(self, "Menu", pid, "OnButton", "MenuOnButton")
UIAction.CallFunction("Menu", pid, "ShowPage")
```

Close with `ClearAll` / `HideElement` / `ShowElement("hud", 0)` / `EnableActionMap("menu", false)`. Everything goes
in **container 0** (mixing 0 and 1 overlaps rows). Rebuild a page one tick later via `Script.SetTimerForFunction(1, ...)`,
never from inside its own button callback. The Companion mod ships a surgically edited `Menu.gfx` (one `DefineSprite`
frame script changed, via a tag editor such as JPEXS) (verified: ui.md).

### `hud` - always loaded overlay

`hud` never needs a screen transition (vanilla: `UIElements/HUD.xml`, layer 25):

- `SetBubbleText(Id 1-16, Text, SpeakerName, PlayerDistance)` + MovieClips `bubble1..bubble16`: sixteen free-text
  labels positionable with `SetPos`. `SetBubbleText` **restarts the appear animation** - call it only when the text
  changes, `SetPos` every tick (verified in game).
- `SetSubtitles(Text, SpeakerName, IsPlayer)`, `ShowTutorial(Id, Text, Duration, InDialogue, Priority, Layout)` - the
  XML marks `Text` "(can be HTML)"; colour tags work, `<img src='img://...'>` inside them did **not** render (verified
  in game). One community mod passes 8 args to `ShowTutorial` (`..., ActionHintEnable, OverlayLink`) and names the
  element `"HUD"` (community: `references/mods/curaequi`).
- `ShowInfoText(Text, Priority, Duration, Background)`, `ShowNotification(infoText)`, `ShowGameLog(Type, Level, Text)`.
- `AddCompassMarker` / `RemoveCompassMarker` / `ResetCompassMarkers` - see [Compass markers](#compass-markers).
- The engine also ships a FlowGraph node that projects a world position to flash stage coordinates with 2.5D depth
  scaling (ui.md, node name not recorded). FlowGraph is out of a mod's reach; from Lua,
  project with [`System.ProjectToScreen`](api/System.md#projecttoscreen) and move a bubble with `SetPos`.
- ~70 other named clips (`MasterSwitch` = instancename `all`, `Vignette`, `Fader`, `RatioStrips`, ...) to hide/move/fade.

Only **two** elements declare `<MovieClips>` at all: `hud` (71) and `LockPicking` (6). Those 77 clips are everything Lua
can move without shipping a movie, and `UIAction` has no `CreateMovieClip` (flowgraph-only) (vanilla files).

### Others

- **`ApseModalDialog`** (layer 36): `OpenQuestionDialog`, `OpenInfoDialog`, `OpenAmountDialog`, `OpenRandomEventDialog`
  take plain strings and render, but `[F]`/`[Esc]` are only drawn - nothing dismisses it (verified in game).
  Signatures (vanilla: `Libs/UI/UIElements/ApseModalDialog.xml`): `OpenQuestionDialog(Question, ActionConfirm,
  ActionCancel, HintConfirm, HintCancel)`, `OpenInfoDialog(Info, Action, Hint)`, `OpenAmountDialog(Min, Max, Def, Step,
  ActionConfirm, ActionCancel, HintConfirm, HintCancel)`, `OpenRandomEventDialog(Caption, Description, IconId, HasTimer,
  HasHoundmasterPerk)`, plus `OpenItemDialog(Info)`, `OpenHealingDialog(Amount, Title, ActionConfirm, ActionCancel,
  HintConfirm, HintCancel)`, `OpenCombineDialog(...)` and a `Close...Dialog` for each.
- **`LockPicking`** declares zero functions and zero events: the minigame is driven purely by moving named clips. It is
  the template for a mod screen - dumb art, named clips, all logic in Lua (vanilla: `UIElements/LockPicking.xml`).
- **`ForgeBuilderPlan`** is a poor donor: `FillData(Type:int)` against an internal enum; the real work lives in
  `hud.gfx` (`SetForgeBuilderSlots/Assets`) (vanilla files).

## Other Lua UI entry points

| Call | Notes |
| --- | --- |
| [`Game.ShowTutorial`](api/Game.md#showtutorial), [`ShowOverlayTutorial`](api/Game.md#showoverlaytutorial), [`HideTutorial`](api/Game.md#hidetutorial) | vanilla `player.lua`; accepts `<font>`-tag HTML, usable as a crude multi-line dev panel (claimed: old context doc; HTML colour verified in game) |
| [`Game.ShowNotification`](api/Game.md#shownotification), [`SendInfoText`](api/Game.md#sendinfotext), [`ShowCaptionObjectMessage`](api/Game.md#showcaptionobjectmessage) | HUD toasts (verified in game) |
| [`Game.ShowItemsTransfer`](api/Game.md#showitemstransfer), [`ShowStatCheckResult`](api/Game.md#showstatcheckresult) | vanilla `ItemUtils.lua` / `DialogUtils.lua` |
| [`actor:OpenInventory`](api/Actor.md#openinventory), [`OpenItemTransferStore`](api/Actor.md#openitemtransferstore) | real inventory / stash screens (vanilla `AnimStash.lua`) |
| `HUD.SetObjectiveStatus/...` | exists but vanilla always nil-guards `HUD`; do the same |
| [`Movie.PlaySequence`](api/Movie.md#playsequence) / `StopSequence` / `IsPlaying` | TrackView sequences |
| [`System.GetViewport`](api/System.md#getviewport) | `{x, y, width, height}` - the screen size |

**Absent** in retail (docs vs runtime dump vs binary): `System.Draw2DImage`, `System.GetScreenSize`, `ShowSubtitle`,
`ShowMessage`, any `CScriptBindHud`, `PlayerEventDispatcher` (measured nil in retail although the Companion mod
references it for Esc handling - presumably supplied elsewhere, (unverified)). `wh::guimodule::ShowUINotification` is
Skald-only RTTR.

## Map POI markers (`ApseMap`)

The world map has **no game system** a mod can call: no `Map` global, `C_ScriptBind_Map` only has `CallScript`,
`UIMap` only `GoToCheckpointMark`, `QuestSystem` absent, no `LocationPoint` entities in Kuttenberg, and a Skald
`ShowMapMarker` on a Lua-spawned NPC showed no icon in play-tests (aleksej.md; conflict:
bandit-camp-quest.md ships one and marks it unverified). It is driven purely
through the `ApseMap` movie (verified in game):

```lua
UIAction.SetArray("ApseMap", -1, "PoiMarkers",
    { 9001, "MY_KEY", "my_loc_key", "camp", 1, false, 0, worldX, worldY })
UIAction.CallFunction("ApseMap", -1, "AddPoiMarkers")
```

| # | Field | Notes |
| --- | --- | --- |
| 1 | Id | also sets clip depth - use **9001+** (see Gotchas) |
| 2 | unique key | `FocusOnUniquePoi` / `GetByKey` |
| 3 | UI text key | localisation row; the tooltip |
| 4 | icon name | `Libs/UI/Textures/Icons/Map/<name>[_undiscovered]_icon.dds` + `<name>_sh_icon.dds` shadow |
| 5 | discovered | `0` requests the `_undiscovered` texture |
| 6 | is fast travel | `false` unless adding a travel point |
| 7 | unused | `0` |
| 8, 9 | **world** X, Y | not map coordinates; the movie transforms them |

`AddPoiMarkers` (`fc_addPoiMarkers`) and `RemovePoiMarkers` (`fc_removePoiMarkers`) take no parameters and act on the
`PoiMarkers` array (`g_PoiMarkersA`) set just before. The `PoiMarker` class's `SetData` reads `Id`, `m_UiName`,
`m_IconName`, `m_IsFastTravel` and `m_Position` (vanilla: `Libs/UI/UIElements/ApseMap.xml`; `Libs/UI/ApseMap.gfx`
decompresses with zlib past its 8-byte header and the AS2 constant pool is readable; map-marker.md).

- Push on every `ApseMap` **`OnShow`** (`RegisterElementListener(t, "ApseMap", -1, "OnShow", "Cb")`): the movie's
  `fc_open` clears its containers each time the map closes, so this cannot duplicate.
- One marker per `SetArray` + `AddPoiMarkers` call; push once per opening.
- A vanilla icon name (`camp`, `weaponsmiths`, `home`, ...) needs no art. Custom icons: ship `<name>_icon.dds` and
  `<name>_sh_icon.dds` in `Libs/UI/Textures/Icons/Map/`; that folder is already globbed by `TexturePreload.xml`.
- Size: only a hardcoded list of type names (`PoiTipster`, `QuestGiver`, `Hub`, `FastTravel*`, `DLC0-3`, `Nest`, ...)
  gets `POI_IMPORTANCE_HIGH`. The mod-reachable lever is the texture's **native pixel size** (stock icons are 64x64;
  a 100x100 icon draws proportionally larger) (vanilla: `ApseMap.gfx` AS2; community: `references/ddv_hc_map_marker`).
- Trosecko and Kutnohorsko share one coordinate space: a marker from a saved position drawn on the wrong level lands
  somewhere arbitrary - only draw markers for things on the current level (see [world-and-physics.md](world-and-physics.md#levels-and-regions)).

Full history and the crash bisection: map-marker.md.

## Compass markers

A separate system on `hud` (vanilla: `UIElements/HUD.xml`; field order from `hud.gfx` `CompassMarker`, claimed):

```lua
-- AddCompassMarker(MarkerID, MarkerType, MarkerState, QuestColor, ObjectiveNumber, Distance,
--                  Frame, IsInsideArea, IsInsideArea2D, NearThreshold, LayerThreshold, FarThreshold)
UIAction.SetArray("hud", -1, "CompassMarkers", { 1, id, -1, dist, bearing, 0, false, false })
UIAction.CallFunction("hud", -1, "UpdateCompass", 0)
```

The update array after the leading value is: id, quest colour, distance, **angle**, angle pitch, is-inside-area,
is-inside-area-2D - so HUD.xml's `Frame` parameter is `m_Angle`. `MarkerID` may be a **string key** (e.g. `"MERC_CAMP"`):
the same key goes in the update array and is the argument of `RemoveCompassMarker(key)`. The last three
`AddCompassMarker` values are distance thresholds in metres - full alpha inside `NearThreshold`, a layer switch at
`LayerThreshold`, still drawn out to `FarThreshold`; the Mercenaries camp marker uses 3 / 50 / 5000 (mod:
`mercenaries_mapmarker.lua`, meanings from its comments, opt-in feature). Icons come from the same
`Icons/Map/<type>_icon.dds` path (quest markers add a `quest_` prefix), so every map icon is a compass type.
The bearing's zero and direction are **(unverified)**: the one working example reverses it and adds 45 degrees, and it
may differ per level. Unlike a map POI it needs a redraw ~4x/second while shown (map-marker.md).

## Shipping your own element

### Registration and the `.swf` loader (retail binary, then verified in game)

- `CFlashUI` scans `<base>/UIElements/*.xml` through **CryPak** (`FindFirst/FindNext/FindClose`,
  `bAllowUseFileSystem = 0`), so loose mod folders and mod `.pak`s are both searched. Each file's `name=` attribute is
  read at runtime and inserted into a name-keyed map - **no compiled-in element list**; a new name registers.
  The list is built at `CFlashUI` init, so a new element needs a **game restart**.
- `wh_gfx_useSWF` (default 0, flags 0 - a normal, non-cheat cvar) has one read site in the per-element movie loader.
  For a movie declared as `Foo.gfx` the loader tries, in order: `<gfx_uiaction_folder>/Foo.swf` (only if the cvar is
  non-zero), `<folder>/Foo.gfx`, then bare `Foo.gfx` (no existence check). `gfx_uiaction_folder` defaults to `Libs/UI/`.
  A failing load of `Menu.gfx` specifically is fatal.
- A native plugin gains nothing here: every `UIAction` bind resolves the element name via `IFlashUI` (`gEnv + 0x138`,
  `CFlashUI` vtable slot 14 `GetUIElement`) and bails on null; there is no Add/Create entry point. Shipping the XML
  is the only door (details: ui.md).

Recipe (confirmed rendering in game with a from-scratch generated SWF):

1. `Data/Libs/UI/MyScreen.swf` - SWF v8 / AS2, `FileAttributes` first, bitmaps/shapes in `DefineSprite`s, each placed
   with a **`PlaceObject2` instance name**; and **no** `MyScreen.gfx` anywhere in the VFS (a `.gfx` wins the lookup).
2. `Data/Libs/UI/UIElements/MyScreen.xml` declaring the movie as **`MyScreen.gfx`** (the loader swaps the extension)
   and every clip under `<MovieClips>`.
3. `wh_gfx_useSWF = 1` in `user.cfg` (setting it from the live console is too late).
4. `UIAction.ShowElement("MyScreen", 0)`; drive clips with `SetPos/SetScale/SetAlpha/SetVisible/SetRotation`.

### Authoring constraints

- **Stop the timeline.** A timeline loops and re-executes `PlaceObject2`, resetting every transform Lua applied;
  emit `DoAction`/`ActionStop` on the root and in every sprite (verified in game).
- **The stage is scaled to the backbuffer.** Author at e.g. 1280x720; `(640, 360)` is screen centre at any resolution.
  Supersample bitmaps (e.g. 3x) and bake a `1/ss` shrink into each clip's matrix for 1:1 pixels at 4K; then every
  runtime `SetScale` must re-apply that shrink (verified in game: command-ui.md).
- **No ActionScript means no mouse, no buttons, no hit-testing**; no vector shapes, no live text fields, no masks in
  the generated pipeline - everything is a bitmap. Mouse-driven lists: drive vanilla `Menu` instead.
- **A clip instance is one object in one place.** A number needs one instance per character *position*
  (`n_<field>_<pos>_<glyph>`), sized to the longest string, with a clip for every separator it can print.
- **Registration point**: a centre-registered clip is placed by its middle, a top-left one by its corner; the driver
  must know which (emit it into the atlas).
- Multi-frame state clips (`FrameLabel` + `GotoAndStopFrameName`) are emitted by the tooling but **unproven in game**.
  `DefineEditText` live text referencing the game's font by name is **untested**.
- Two loaded elements on the **same layer** did not coexist (the second drew wrong); keep one element per layer or
  unload the other (verified in game: command-ui.md).
- Keep the movie small: a full-screen frame supersampled 3x is ~7 Mpx stored whole (an 11 MB SWF); cut chrome at 1:1
  and draw it scaled, cut icons once (new-skalitz mod: `docs/mercenaries/ui/ui.md`).

### Runtime rules

- The movie is **constructed on first display**. Transforms sent in the same call as `ShowElement` address clips
  that do not exist and no-op. Defer the first layout (~600 ms used in practice), park clips off-stage rather than
  hiding them, and keep the element **loaded** while closed so re-opening is instant.
- `Script.SetTimerForFunction` takes a function **name**, so the deferred-layout callback must be a global.
- Diff frames: hide what was shown last frame and is not now, instead of redrawing everything (flicker + cost).
- When a symptom ("appears, then disappears") has several indistinguishable causes, poll and log
  `pos/scale/vis/alpha` every 250 ms - that ended a four-restart guessing game in one run (verified in game).

### Tooling in this repo

| Tool | Job |
| --- | --- |
| `tools/kcdui` | scene JSON -> `.swf` + element XML + Lua atlas + preview PNG; `check` cross-validates all three; `runtime/kcdui.lua` gives `place/digits/state/sweep` |
| `tools/make_swf.py` | minimal dependency-free SWF v8 writer; `--verify` round-trips shape records |
| `tools/check_uistate.py`, `check_blstate.py`, `check_campui.py` | run drivers in a real Lua (lupa) with the engine stubbed; press keys; assert clip names, `PlayerCommand`s, load order, loc rows |
| `tools/kcd_font.py`, `tools/gfx_metrics.py` (new-skalitz) | read vanilla fonts / `DefineEditText` metrics out of the paks |

Step-by-step guide: ui-building.md. Driver written by hand is the bulk of the work (1,000-1,400 lines per screen
here); layout is maybe a tenth.

## Images and icons

- Scaleform image URLs are resolved by `CryGFxImageLoader`: `img://TEXID:<n>` (engine texture id),
  `img://Libs/UI/qr:<data>` (generated QR), `%user%` expansion, and `wh::engine::C_ImageSourceManager` lookups including
  a PNG decoder (retail binary). `img://` inside tutorial HTML did not render (verified in game).
- `Libs/UI/TexturePreload.xml` preloads whole folders by glob: `Icons/Buffs/*`, `Icons/Map/*`, `Icons/Items/*`,
  `Icons/Perks/*`, ... - a `.dds` dropped into one needs no registration (vanilla files).
- **Buff icons with zero UI code**: `icon_id="<name>"` on a buff row -> `hud.gfx`'s `fc_addBuff` expands it to
  `Libs/UI/Textures/Icons/Buffs/<name>_icon.dds`. That naming convention exists only in the compiled AS2 (the string is
  not in `WHGame.dll`) (retail binary + verified in game).
- **DDS format matters**: stock map icons are `BC7_UNORM`, `arraySize = 1`. Pillow's `BC3` writer emits
  `BC3_TYPELESS` with `arraySize = 0` - it renders **nothing**. Write legacy DXT5 (no DX10 header) instead and compare
  headers against a vanilla file (`tools/gen_map_icons.py --verify`) (verified in game).
- Scaleform stores bitmaps **alpha-premultiplied**: to remove a dark fringe, zero low-alpha pixels at build time.
- `Libs/UI/Textures/Dynamic/` is ~150 pre-baked `.dds`, not a writable canvas; there is no Lua render-to-texture.

## Fonts, metrics and colours

Vanilla faces ship only inside Scaleform font libraries in `IPL_GameData.pak` (vanilla `fontconfig.xml` names):
`DefaultFont` = Kingdom Come Regular (+bold/italic), `DisplayFont` = Kingdom Come Display, `LightFont` = Kingdom Light,
`Manuscript` = Warhorse Manuscript.

- `gfxfontlib.gfx` has `DefineFont3` **metrics only** (outlines stripped); `gfxfontlib_glyphs.gfx` has the outlines
  (2 MB). Glyphs are SWF `SHAPE` records, even-odd fill, 1024-unit em in twips (20480) (verified: `tools/kcd_font.py`).
- Scale text by **cap height**, not nominal size: Segoe UI and Kingdom Come Regular at the same size differ ~16%.
- Vanilla UI is authored on a **1920x1080** stage; divide by 1.5 for a 1280x720 mod stage (new-skalitz `docs/ui-metrics.md`,
  measured from `DefineEditText` records):

| Vanilla px | 1280-stage | Use |
| --- | --- | --- |
| 50 / 44 | 33.3 / 29.3 | screen title / section heading |
| 41-42 | 27.3-28 | **list row text - the dominant size** |
| 40 / 38 / 30 | 26.7 / 25.3 / 20 | body / secondary / captions |
| row box 56 / 70 | 37.3 / 46.7 | standard / tall list row height |

Colours: primary text **`255,255,255`**, highlight `255,238,153`, headings `221,192,120`, secondary `204,204,204`, text
on gold `42,42,42`. Text at half vanilla size is the loudest "this is a mod" tell.

**Key caps are textures, not drawings**: `Libs/UI/buttons.gfx` holds only `DefineExternalImage2` references to loose
`Libs/UI/Textures/buttons/key.dds` (64x64), `key_middle.dds` / `key_long.dds` (128x64), all DXT5, plus a
`DefineEditText` (30 px black, centred; ink centred at 0.414 of cap height). `hud.gfx` draws them at **scale 0.5** on
its 1920 stage, word first then cap, label `DefaultFont` 22 px white. The drawn size lives in the *consumer* movie,
not the asset (verified: ui.md). Panels can be cut from
`Libs/UI/Textures/Apse/item_selection.dds` (red damask bands, blue field, carved rails) (new-skalitz mod: `docs/mercenaries/ui/ui.md`).

## Immediate-mode drawing

Exactly five calls put anything on screen (verified in game, sweep of the live Lua state):

| Call | Space | Notes |
| --- | --- | --- |
| [`System.DrawText(x, y, text, size, r, g, b, a)`](api/System.md#drawtext) | **backbuffer pixels** | font renderer, not aux geom. The docs' `(x, y, text, font, size, p2y, r, g, b, alpha)` signature is **wrong** for this build and renders magenta garbage. `size` accepts decimals; colours 0..1 |
| [`System.Draw2DLine(x1, y1, x2, y2, r, g, b, a)`](api/System.md#draw2dline) | **normalised 0..1** | pixel values fly off toward infinity as a large "white pyramid" in the world. Divide by `GetViewport().width/height` |
| [`System.DrawLine(vFrom, vTo, r, g, b, a)`](api/System.md#drawline) | world | 3D line |
| [`System.DrawLabel(vPos, fSize, text, r, g, b, a)`](api/System.md#drawlabel) | world | 3D anchored text (`Comment.lua`) |
| [`System.ProjectToScreen(vWorld)`](api/System.md#projecttoscreen) | neither % nor pixels | returned `x=437 y=404` for an on-screen NPC at 3840x2160 - measure it (project a point 10 m ahead = screen centre) |

- No filled polygons, no images: `System.DrawTriStrip` and `Game.DebugDrawText` are absent in retail. A filled panel is
  rows of `string.rep("_", n)` - the debug font is ASCII-only, block glyphs render as tofu; a border is one glyph row thick.
- Calls last one frame: they need a real per-frame hook. That means a custom entity class with **both**
  `Data/Scripts/Entities/<Name>.lua` and `Data/Entities/<Name>.ent` (else `System.SpawnEntity` throws), with the update
  handler in **`Client`/`Server` sub-tables** (`X.Client:OnUpdate(dt)`); a top-level `OnUpdate` is never called.
- Keep `r_AuxGeomAutoScaleOver1080pWH = 1`; `0` makes `DrawText` stop rendering entirely. `r_enableAuxGeom`/`r_auxGeom`
  were already 1 in retail. When aux geometry is off at init the renderer swaps in a `CAuxGeomCB_Null` stub, so on a
  machine where nothing draws check those two cvars first (retail binary: ui.md).
- Support binds that exist in retail but draw nothing themselves: [`System.SetScissor(x, y, w, h)`](api/System.md#setscissor),
  [`System.LoadFont(name)`](api/System.md#loadfont), [`System.ScreenToTexture()`](api/System.md#screentotexture)
  (API index: docs, binary and runtime dump; behaviour untested).
- Conflict note: ui.md first concluded `Draw2DLine` is unusable in any space; the later measurement (normalised
  0..1, pixel checkerboard drawn) supersedes it.

## Input for custom screens

Gameplay keys are CryEngine **action maps** (`Libs/Config/defaultProfile.xml`, priority tiers + `exclusivity`), mapped
to keys via `Libs/Config/keybindSuperactions.xml` (vanilla files). Routes, in order of reliability:

1. **Borrow keys from a screen whose binds already work** and forward into the new screen.
2. **Console binds**: `System.ExecuteCommand("bind 5 my_cmd")`. The bound command must be registered **unconditionally
   at load** - a key bound to an unknown (e.g. dev-gated, lazily registered) command does nothing, silently. Binds worked
   for one screen and inexplicably not another; self-test through the console. The bind table keeps no history, cannot
   be read back, and a second `bind` silently overwrites another mod's (verified in game).
3. **`Player.OnAction` chaining**: the activation word is **`"press"`**, not `"onPress"`; returning `true` only stops the
   Lua chain - the engine still acts on the input.

Suppression:

- [`ActionMapManager.EnableActionMap`](api/ActionMapManager.md#enableactionmap) is live. Maps with priority
  **`pure_include`** (e.g. `open_menu`, `open_apse_keyboard`) cannot be toggled; the enable-able ancestor is `player`,
  which also owns the camera (mouse look dies with it). Re-enable on hide **and** unconditionally at `OnGameplayStarted`.
- **Action filters cannot be enabled from Lua**: `EnableActionFilter` was removed before release (absent from
  `WHGame.dll`, "removed" in Warhorse's 2023 scriptbind changelog); only
  [`IsFilterEnabled`](api/ActionMapManager.md#isfilterenabled) survives, and it reports *enabled*, not *present*. The live
  route is the Skald primitive **`FilterInput`** (`Filters` array + `IsActive`) fed from Lua by a weightless marker item
  -> `ItemDescriptorTrigger` -> `State` (verified in game; vanilla uses it 94 times). A custom filter loaded with
  [`LoadFromXML`](api/ActionMapManager.md#loadfromxml) reported success and had no effect; naming vanilla `no_qam_weapons`
  worked. Filter state is not ref-counted: last writer wins.
- Number row: `1-4` are `action_qam_1..4` and **draw the quick-slot weapon**; `no_qam_weapons` blocks them but also
  blocks `OnAction` delivery, so take them by console bind while the filter is held. `9`/`0` have no action at all (only
  the disabled `haste` cheat map). `I`, `P`, `J` open inventory/player/questlog over your screen; `F1` is reserved, `F12`
  is Steam's screenshot, `ESC` still opens the pause menu under a bind. Engine key names are US scancodes (`y`/`z` swap
  on German layouts). Keys KCD2 never binds: **H, U, Y, O** - avoid `Y` for badges anyway (verified in game: command-ui.md).
- Mouse clicks as `attack_primary_mouse` / `block` live in `combat_base` and fire only with a weapon drawn.
- **KCD2 Keybinder** (community, Nexus 2447) merges mod commands annotated `--- @bindingMap` / `--- @bindingCommand` into
  generated action-map data so players rebind them in the game's own options.

## What Skald can draw

The master node list is `Data/Libs/concept/definitions.xml` (1.65 MB), grouped by `Category="wh::<module>"`.
`wh::guimodule` is nine nodes: `ShowUINotification` (text toast), `ClearUINotifications`, `BlockUINotifications`,
`ShowMapMarker` (fixed 19-value icon enum, on an entity), `CutsceneHandler`, `PlayTrackView`, `ApseViewTrigger`
(observes a native screen opening), `InteractorOverride`, `InfiniteHoldInteractionTrigger` (arbitrary hold-E text).
Beyond it: `DisplayTutorial` (rows in `Libs/Tables/ui/tutorial.xml`; `PopupTutorial` takes custom rows,
`OverlayTutorial` is locked to ~90 native screens), `CreateItemDelivery`/`ItemDeliveryHandler`, and `MakeTracker(Current,
Total)` - the only numeric widget (vanilla files). No image, video or panel node exists. The ceiling for pure Skald is a
`Dialogue Type="chat"` menu (four slots per level, nested) - see order-wheel.md and the quest page when present.

## Dead ends

- Persistent Debug (`pd_*`) is not compiled in (no strings in the DLL).
- No render-to-texture from Lua (`FlashDynTexture` is Scaleform again); a grid of textured quads as a pixel display is a
  draw-call trap (performance.md).
- Replacing world-map tables (`ui_map_label.xml`, `ui_local_maps.xml`) is level-baked and GUID-keyed - conflict-prone.
- Driving the console with synthetic keystrokes (`SendInput`) fails: characters go to gameplay (`m` opens the map) and
  layouts remap punctuation. Instead have the mod `exec` a `.cfg` on a timer armed from `OnGameplayStarted` and rewrite
  the file from outside; every command in it must be idempotent (verified in game: ui.md).

## Gotchas

- UI element appears then "disappears" -> you passed a multiplier to `SetScale`/`SetAlpha`; they take percent (100 = 1.0).
- Layout calls do nothing the first time a screen opens -> the movie is built on first display; defer the first layout.
- Your `.swf` never loads -> `wh_gfx_useSWF` was not set in `user.cfg` before launch, the XML names `.swf` instead of
  `.gfx`, or a `.gfx` of the same name exists in the VFS; new elements also need a full restart.
- Clips snap back to their authored place a moment after you move them -> the SWF timeline loops; add `ActionStop`.
- Only the last digit of `500` shows -> one clip instance was placed twice; use one instance per character position.
- `2 / 6` renders as `2 6` -> the glyph set lacks a clip for that separator (it is silently skipped).
- Every uncentred clip sits half its size down-right -> the driver assumed centre registration.
- Listener gets garbage arguments -> callback declared with `.` instead of `:`; `argTable` is 0-indexed.
- Marker added twice / handlers fire twice -> listeners re-registered each `OnGameplayStarted` without `UnregisterElementListener`.
- Game crashes on opening the map -> two POI markers with low ids (1, 2) and loading textures; use ids 9001+, one per call.
- All vanilla map POIs vanish -> `RemovePoiMarkers` takes no argument and clears the whole container.
- Custom map icon draws nothing -> DDS is `BC3_TYPELESS` / `arraySize 0`; write legacy DXT5 or BC7.
- `SendInfoText` prints the raw key -> the key needs a row in all `localization/*_xml.xml` files (and `ElementTree.write`
  strips their comments - splice rows textually).
- `DrawText` renders magenta nonsense -> you used the documented 2012 signature; use `(x, y, text, size, r, g, b, a)`.
- `Draw2DLine` draws a huge white shape in the world -> it wants normalised 0..1 coordinates, not pixels.
- `DrawText` stopped rendering -> `r_AuxGeomAutoScaleOver1080pWH` was set to 0.
- Immediate-mode drawing shows nothing -> `OnUpdate` defined on the entity table instead of `Client`/`Server`, or the `.ent` is missing.
- `SetBubbleText` strobes -> it restarts the bubble animation; only call it when the text changes.
- Keys bound to a screen do nothing -> the command is a dev-gated/lazily registered command, or a `DevCommand`.
- Pressing 1-4 on your screen draws a sword -> hold `no_qam_weapons` via Skald `FilterInput` while the screen is up.
- Player can't draw weapons / move after a crash -> a filter token or disabled action map leaked; clear both
  unconditionally at every `OnGameplayStarted`.
- Suppressing `open_menu` does nothing -> `pure_include` maps cannot be toggled; only `player` can, and it takes mouse look.
- A screen reopens by itself after loading a save -> a pending `SetTimerForFunction` watchdog was serialised into the
  save; cap watchdogs and reset their state at gameplay start.
- Second custom screen draws wrong once the first has been opened -> both elements sit loaded on the same layer.
- Text in panels looks thin and "moddy" -> vanilla list rows are ~27 units on a 1280 stage, body text pure white.

## See also

- Mod war stories: ui.md (research + disassembly), ui-building.md (step-by-step), map-marker.md,
  command-ui.md, camp-ui.md.
- [assets-pipeline.md](assets-pipeline.md) for textures/DDS in general; [world-and-physics.md](world-and-physics.md) for
  levels and raycasts used by aim-and-click placement.
- Cvars: [console-variables.md](console-variables.md) (`wh_gfx_useSWF`, `gfx_uiaction_folder`, `t_GameScale`).
