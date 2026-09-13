# Custom UI

KCD2's interface is **CryEngine's Scaleform Flash UI**, and the whole of it - including the
Lua bridge - is compiled into the shipping `WHGame.dll`. A mod can drive existing screens
from Lua, and can ship screens of its own.

This is not theory. `UIAction` is present in a live runtime dump of retail `release_1_5`,
and a published KCD2 mod already builds a working command menu with it.

---

## The stack in one paragraph

Every screen is a Flash movie (`Data/Libs/UI/*.gfx`) bound to the engine by an XML contract
(`Data/Libs/UI/UIElements/*.xml`) that declares the element's name, the ActionScript
functions the engine may call, the events Flash fires back, the shared arrays, and the named
MovieClips the engine may move. Lua talks to all of it through the `UIAction` scriptbind.
`Data/Libs/UI/` ships **loose on disk** (also mirrored inside `IPL_GameData.pak`), so a mod
folder overrides it the way it overrides anything else - this mod already ships `.dds` into
`Libs/UI/Textures/Icons/Buffs` successfully.

The `.gfx` files are `CFX` (zlib-compressed Scaleform export), SWF version 8, and
**ActionScript 2** - no `DoABC` tag exists in any of the 38 files. AS2 matters: it is what the
free tooling can read and write.

---

## The Lua API

`CScriptBind_UIAction` registers the global `UIAction`. All 33 methods appear verbatim in
`references/kcd2-mod-docs-main/lua_dump_state/LuaState_Sorted.txt` - the output of
`lua_dump_state` run inside a loaded save on retail - so this is not a "should exist" list.

```lua
-- element lifecycle
UIAction.ShowElement   (elementName, instanceID)   -- creates the instance if absent
UIAction.HideElement   (elementName, instanceID)
UIAction.RequestHide   (elementName, instanceID)   -- lets the movie fade itself out
UIAction.ReloadElement (elementName, instanceID)
UIAction.UnloadElement (elementName, instanceID)

-- talk to ActionScript
UIAction.CallFunction  (elementName, instanceID, functionName, ...)
UIAction.SetVariable   (elementName, instanceID, varName, value)
UIAction.GetVariable   (elementName, instanceID, varName)
UIAction.SetArray      (elementName, instanceID, arrayName, table)
UIAction.GetArray      (elementName, instanceID, arrayName)

-- move MovieClips directly, no ActionScript involved
UIAction.SetPos / GetPos           (elementName, instanceID, mcName, vPos)
UIAction.SetScale / GetScale       (elementName, instanceID, mcName, vScale)
UIAction.SetRotation / GetRotation (elementName, instanceID, mcName, vRotation)
UIAction.SetAlpha / GetAlpha       (elementName, instanceID, mcName, fAlpha)
UIAction.SetVisible / IsVisible    (elementName, instanceID, mcName, bVisible)
UIAction.GotoAndPlay / GotoAndStop (elementName, instanceID, mcName, frameNum)
UIAction.GotoAndPlayFrameName / GotoAndStopFrameName (elementName, instanceID, mcName, frameName)

-- input coming back from Flash
UIAction.RegisterElementListener    (table, elementName, instanceID, eventName, callbackName)
UIAction.RegisterActionListener     (table, actionName, eventName, callbackName)
UIAction.RegisterEventSystemListener(table, eventSystem, eventName, callbackName)
UIAction.UnregisterElementListener  (table, callbackName)   -- and the other two variants

-- UIAction flowgraphs (Libs/UI/UIActions/*.xml)
UIAction.StartAction  (actionName, argumentsTable)
UIAction.EndAction    (table, disable, argumentsTable)
UIAction.EnableAction (actionName) / UIAction.DisableAction(actionName)
```

`instanceID` is documented in the binary as *"Instance ID for the element, -1 = all instances
(lazy init), -2 = all initialized instances"*. **Pick your own number and you get your own
private instance of a vanilla element** - that is how a mod puts its own content on the main
menu without fighting the game's copy.

Listener callbacks arrive as `callback(func, elementName, instanceId, eventName, argTable)`
and `argTable` is **0-indexed** (`argTable[0]`, `argTable[1]`, ...).

No shipped base-game `.lua` calls `UIAction.*` - Warhorse drives it from UI flowgraph XML and
from the ActionScript side instead. That is why the mod precedent below matters so much.

### Other confirmed Lua UI entry points

| Call | Notes |
|---|---|
| `Game.ShowTutorial(text[, id])`, `Game.ShowOverlayTutorial(text)`, `Game.HideTutorial()` | proven in `player.lua` |
| `Game.ShowNotification(msg)`, `Game.SendInfoText(...)`, `Game.ShowCaptionObjectMessage(...)` | HUD toasts |
| `Game.ShowItemsTransfer(classId, amount)`, `Game.ShowStatCheckResult(stat, ok)` | proven in `ItemUtils.lua` / `DialogUtils.lua` |
| `actor:OpenInventory(entityId, mode, otherInventoryId, filter)` | opens the real inventory screen |
| `actor:OpenItemTransferStore(id, otherInventoryId, filter, header)` | proven in `AnimStash.lua` |
| `HUD.SetObjectiveStatus/SetObjectiveEntity/...` | exists, but base game always nil-guards it (`if (HUD) then`) - it is not a permanent table, so nil-check it |
| `Movie.PlaySequence/StopSequence/IsPlaying(name)` | TrackView sequences |

**Absent** (checked against the doc set, the runtime dump and the DLL): `System.Draw2DImage`,
`System.GetScreenSize` (use `System.GetViewport()` -> `{x,y,width,height}`), `ShowSubtitle`,
`ShowMessage`, and any `CScriptBindHud` class. `wh::guimodule::ShowUINotification` is an RTTR
function for Skald only - it is not on any Lua table.

---

## Proof it works

`references/bodyguards` is the shipped "KCD2 Companion" mod. It builds a full paged,
mouse-driven command menu out of the vanilla `Menu` element on its own instance id:

```lua
kcdcompanion.MenuPID = 47001

UIAction.HideElement("hud", -1)
UIAction.CallFunction("Menu", pid, "ClearAll")
UIAction.CallFunction("Menu", pid, "PreparePage", 0, math.floor(screenY * frac), shown, title, 1)
ActionMapManager.EnableActionMap("menu", true)
UIAction.CallFunction("Menu", pid, "SetActiveUser", "")
for i, el in ipairs(B) do
    UIAction.CallFunction("Menu", pid, "AddBasicButton", "cmp_"..i, 0, el.label, el.tooltip, el.disabled)
end
UIAction.ShowElement("Menu", pid)
UIAction.RegisterElementListener(self, "Menu", pid, "OnButton", "MenuOnButton")
UIAction.CallFunction("Menu", pid, "ShowPage")
```

Closing is `ClearAll` / `HideElement` / `ShowElement("hud", 0)` /
`EnableActionMap("menu", false)`. Escape is caught through
`PlayerEventDispatcher:Register("OnActionEvent", ...)` watching for the `menu_back` action.
Navigation between pages is deferred by one tick (`Script.SetTimerForFunction(1, ...)`)
because rebuilding the page from inside its own button callback does not take.

That mod also ships an edited `libs/UI/Menu.gfx`. A tag-level diff against vanilla shows
**one** changed tag out of 386 - a single `DefineSprite`'s frame script grew by 510 bytes of
AS2 - i.e. a surgical edit with a tag editor, not a Flash re-export.

---

## Measured in-game, first run

| Result | |
|---|---|
| `UIAction` live, 34 methods | **confirmed in retail** |
| A `Menu` page on our own instance: title, buttons, tooltips, page navigation, `AddConfirmation` | **all work**, styled like the vanilla menu |
| `OnButton` / `OnConfirm` events back into Lua | **work** |
| `ApseModalDialog` with Lua-authored text | **renders**, but nothing dismisses it - `[F]`/`[Esc]` are drawn, not wired |
| `SetSubtitles` / `ShowTutorial` with HTML colour tags | **work** |
| `ShowNotification` / `ShowInfoText` / `SendInfoText` | **work** |
| `<img src='img://...'>` inside that HTML | **no image appeared** |
| `PlayerEventDispatcher`, `HUD`, `System.DrawTriStrip` | **do not exist** |
| `SetBubbleText` + `SetPos` on `bubble1..16` | **text appears on screen** - the overlay layer works |
| `r_enableAuxGeom` / `r_auxGeom` | already **1**; drawing failing was the frame hook, not the renderer |
| Viewport | 3840 x 2160 |

`SetBubbleText` restarts the bubble's appear animation, so calling it every tick makes the
text strobe. Send the string only when it changes and call `SetPos` every tick.

`System.ProjectToScreen` on an on-screen NPC returned `x=437 y=404 z=0.989` at a 3840x2160
viewport - so it is neither percent nor backbuffer pixels. Its space has to be measured, which
is what `merc_ui_proj` does: it projects a point ten metres dead ahead of the camera, and
whatever that returns *is* the centre of the screen.

`references/mods/curaequi` is worth reading as a second opinion. It drives the HUD through
`UIAction` the same way, and differs in three details: it names the element **`"HUD"`** rather
than `"hud"`, it passes **eight** arguments to `ShowTutorial`
(`Id, Text, DurationMs, InDialogue, Priority, Layout, ActionHintEnable, OverlayLink`), and it
uses `UIAction.RegisterEventSystemListener(t, "System", "OnGameplayStarted", cb)` to hook
engine lifecycle events. Its "Horse Status" card is a multi-line stats panel built entirely
out of `ShowTutorial` text - a cheap pattern for the logistics screen if a real chart proves
out of reach.

Mixing `containerIndex` 0 and 1 on one page makes the rows overlap - put everything in
container 0.

**Only two elements in the entire game declare `<MovieClips>`**: `hud` (71 clips) and
`LockPicking` (6). Those 77 sprites are the complete set of Flash objects Lua can move
without shipping a `.swf`, and only 16 of them (`bubble1`..`bubble16`) carry arbitrary text.
`UIAction` has no `CreateMovieClip` either — dynamic sprite creation exists, but only as a UI
flowgraph node, not on the Lua table.

## What you get with no new assets at all

### `Menu` - a native-looking list screen

From `UIElements/Menu.xml`:

```
PreparePage(ButtonXPos:int, ButtonYPos:int, MaxButtons:int, header:string, buttonHalfWidth:int)
ShowPage(userName:string) / ClearAll(type:int)
AddBasicButton  (id, containerIndex, uiText, tooltip, disable)
AddValueButton  (id, containerIndex, uiText, value, min, max, tooltip, disable)   -- slider
AddChoicesButton(id, containerIndex, uiText, tooltip, disable)  + AddChoiceOption(...)
AddConfirmation (confirmationId, uiQuestion, uiAnswer0, uiAnswer1, defaultAnswer, backAnswer)
SetDisable / SetValue / GetValue / SetChoice / GetChoice / SelectButton
events: OnButton(Id) OnInteractiveValue(id, value) OnInteractiveChoice(id, choiceId) OnConfirm(id, res)
```

Buttons, tooltips, sliders, dropdowns, confirmations, a title, vanilla styling. The ceiling
is that it is a **vertical list** - no free layout, no per-row icons.

### `hud` - overlays on top of gameplay

`hud` is always loaded, so nothing here needs a screen transition.

- `SetBubbleText(Id 1-16, Text, SpeakerName, PlayerDistance)` plus MovieClips
  `bubble1`..`bubble16` (`cccursor.bubbles.mc_speachText1`...). **Sixteen free-text labels you
  can position anywhere on screen** with `UIAction.SetPos`. A ready-made unit-label layer.
- `SetSubtitles(Text, SpeakerName, IsPlayer)` and
  `ShowTutorial(Id, Text, Duration, InDialogue, Priority, Layout)` - the XML annotates both
  `Text` params **"(can be HTML)"**, so styled multi-line markup goes straight through.
- `ShowInfoText(Text, Priority, Duration, Background)`, `ShowNotification(infoText)`,
  `ShowGameLog(Type, Level, Text)`.
- `AddCompassMarker(MarkerID, MarkerType, MarkerState, QuestColor, ObjectiveNumber, Distance,
  Frame, IsInsideArea)` / `RemoveCompassMarker` / `ResetCompassMarkers`, backed by the
  `CompassMarkers` (`g_CompassMarkersA`) array.
- `MasterSwitch` (instancename `all`), `Vignette`, `Fader`, `RatioStrips` and ~70 other named
  MovieClips to hide, move, scale or fade.

### `ApseModalDialog` - free-text popups

`OpenQuestionDialog(Question, ActionConfirm, ActionCancel, HintConfirm, HintCancel)`,
`OpenInfoDialog(Info, Action, Hint)`, `OpenAmountDialog(Min, Max, Def, Step, ...)`,
`OpenRandomEventDialog(Caption, Description, IconId, HasTimer, ...)`. Plain strings, no enum
gating on the content.

### Images

The engine registers Scaleform image protocols - `img://TEXID:%i` and `img://Libs/UI/qr:` are
both in the binary. Custom `.dds` under `Libs/UI/Textures/Icons/<category>/` is already proven
in this mod (the squad status buff icons); `TexturePreload.xml` globs those folders wholesale.

---

## Shipping your own screen

Three files:

1. `Data/Libs/UI/<Name>.gfx` (or `.swf` - see below)
2. `Data/Libs/UI/UIElements/<Name>.xml`
3. Lua calling `UIAction.ShowElement("<Name>", myInstanceId)`

`LockPicking.xml` is the whole template, and it is the entire file:

```xml
<UIElements name="Menus">
  <UIElement name="LockPicking" controller_input="1">
    <GFx file="LockPicking.gfx" layer="10">
      <Constraints>
        <Align mode="dynamic" valign="center" halign="center" scale="1" max="0" />
      </Constraints>
    </GFx>
    <functions></functions>
    <events></events>
    <MovieClips>
      <MovieClip name="LockPick" instancename="mc_LockPick" />
      <MovieClip name="Cursor"   instancename="mc_LockPick.mc_Cursor" />
      <MovieClip name="Point"    instancename="mc_LockPick.mc_Cursor.mc_Point" />
      <MovieClip name="Lock"     instancename="mc_LockPick.mc_Lock" />
      <MovieClip name="Pin"      instancename="mc_LockPick.mc_Lock.mc_Inside.mc_Pin" />
      <MovieClip name="Debug"    instancename="mc_LockPick.mc_Debug" />
    </MovieClips>
  </UIElement>
</UIElements>
```

**Lockpicking declares zero functions.** The entire minigame is driven from outside by moving
named MovieClips. That is the template for a mod screen: dumb art in the Flash file, named
clips, everything driven from Lua. It is also the answer to "can I set individual pixels" -
yes, if a pixel is a MovieClip.

Root attributes the parser accepts (from the binary): `layer`, `fullscreen`, `basedOnSpec`,
`screen_resize`, `shared_rt`, `halign`, `valign`, `mouseevents`, `keyevents`, `cursor`,
`console_cursor`, `console_mouse`, `controller_input`, `events_exclusive`, `render_lockless`,
`force_no_unload`, `fixed_proj_depth`, `lazy_update`, `is_Hud`; child tags `functions`,
`events`, `variables`, `arrays`, `MovieClips`, `templates`.

Layers, for stacking: `Overlay` 5, `LockPicking` 10, Apse detail panes 20, `hud` 25,
`Pickpocketing` 27, `HorseInspect` 30, `SkipTime` 35, `ApseModalDialog` 36, `GameOver` 40,
`Menu` 45, `LoadingScreen` 50, `Progress` 80.

### Authoring the Flash file

- **No Scaleform licence needed.** Warhorse added a cvar `wh_gfx_useSWF` -
  *"Loads .SWF if .GFX not found"* - so a plain SWF is accepted.
- **JPEXS Free Flash Decompiler** (GPLv3) has explicit *"GFX Scaleform and Iggy"* support and
  can open and re-save `.gfx`. It is the tool named in the community's KCD/KCD2 HUD guides,
  and the byte fingerprint of the Companion mod's edited `Menu.gfx` matches what it produces.
- Everything is AS2 (SWF 8). Stay on AS2.

### Two things still unproven

- That a **new** `UIElements/*.xml` auto-registers. The engine scans a folder with `%s/*.xml`
  and there is no master index file, so it should - but every UI mod found so far *overrides*
  an existing element rather than adding one. Cheapest test: copy the 3 KB `ForgeBuilderPlan`
  pair under a new name and see whether `UIAction.ShowElement` finds it.
- That `wh_gfx_useSWF` really loads a hand-built SWF. The cvar says so; nobody has published
  a mod that relies on it.

---

## What Skald can and cannot do

The master list of quest-graph node types is **`Data/Libs/concept/definitions.xml`** (1.65 MB),
not the `Libs/Tables/skald/` folder - those are casting/voice lookup tables. Nodes are grouped
by a `Category="wh::<module>"` attribute.

`wh::guimodule` is the whole UI namespace and it is nine nodes:
`ShowUINotification` (arbitrary text toast), `ClearUINotifications`,
`BlockUINotifications` (fixed HUD categories), `ShowMapMarker` (fixed 19-value icon enum on an
entity), `CutsceneHandler`, `PlayTrackView`, `ApseViewTrigger` (only *observes* the player
opening a native screen), `InteractorOverride` and `InfiniteHoldInteractionTrigger` (arbitrary
"press/hold E" prompt text). There is no `ShowImage`, `ShowVideo` or custom-panel node.

Beyond that: `DisplayTutorial` against rows in `Libs/Tables/ui/tutorial.xml`
(`PopupTutorial` takes arbitrary text and a mod can add its own rows; `OverlayTutorial` is
locked to a fixed ~90-name list of native screens), `CreateItemDelivery` /
`ItemDeliveryHandler` (the trade widget, with arbitrary `Labels` text),
`AddShopDefaultItem` (stocks a shop, draws nothing), and `MakeTracker(Current, Total)` - the
only numeric widget Skald has, an "x / y" counter on a journal objective.

The practical ceiling for a Skald-only menu is the `Dialogue Type="chat"` pattern this mod
already ships as the order wheel (see `docs/order-wheel.md`): arbitrary option text,
conditional entries, nested submenus, four slots per level. **For anything with a layout -
graphs, grids, icons, a map - Skald is the wrong tool and `UIAction` is the right one.**

---

## Immediate-mode drawing (no Flash at all)

A sweep of the live Lua state for every function whose name contains draw/render/screen/
texture/font found **exactly five** that put anything on screen. This is the entire
immediate-mode toolkit, there is nothing else:

```lua
System.Draw2DLine(x1, y1, x2, y2, r, g, b, a)   -- 2D line. A 1px line IS a pixel.
System.DrawText(x, y, text [, size])            -- 2D text; used by CrimeDebugger.lua
System.DrawLine(vFrom, vTo, r, g, b, a)         -- 3D world-space line
System.DrawLabel(vPos, fSize, text, r, g, b, a) -- 3D world-anchored text; Comment.lua
System.ProjectToScreen(vWorld)                  -- world -> screen, for anchoring 2D to 3D
```

Support cast: `System.GetViewport()` → `{x,y,width,height}`, `System.SetScissor`,
`System.LoadFont`, `System.ScreenToTexture`.

**Confirmed absent in retail** (both were in the generic scriptbind docs, neither is on the
live table): `System.DrawTriStrip` and `Game.DebugDrawText`. So there are **no filled
polygons and no image primitive** — lines and text only. A filled shape has to be built out
of adjacent lines.

Two gates:

1. These are one-frame calls, so they need a real per-frame `OnUpdate`. The mod's own loops
   are ~100 ms timers, which is not enough. `mercenaries_UIDraw` exists for this — and a
   custom entity class needs **both** a `Scripts/Entities/<Name>.lua` **and** a
   `data/Entities/<Name>.ent` registration file, or `System.SpawnEntity` throws.
2. They render through CryEngine's **aux geometry** buffer, gated by `r_enableAuxGeom` /
   `r_auxGeom`. **Both measured as already `1` in retail**, so this is not the blocker it
   looked like. (`WHGame.dll` does contain a `CAuxGeomCB_Null` stub that the renderer swaps
   in at init when the cvar is off, so it is still worth checking first on another machine.)

### The frame hook, and the trap in it

A custom entity class needs **both** files or `System.SpawnEntity` throws:

```
data/Scripts/Entities/<Name>.lua      the script
data/Entities/<Name>.ent              the registration
```

And then the real trap: **the update handler must live in the `Client` or `Server`
sub-table.** A function called `OnUpdate` on the entity table itself is never called, and
nothing warns you - the entity spawns, `Activate(1)` succeeds, and the handler simply never
runs. Vanilla does it as `AnimDoor.Server:OnUpdate(dt)`. `mercenaries_UIDraw` now defines
both and logs which one fires.

That was the actual reason the first draw test showed nothing: not the renderer, not the
coordinate space, just a handler in the wrong table.

### Verdict: `Draw2DLine` is unusable, `DrawText` is a pixel plotter

`merc_ui_draw_space` drew one line per candidate coordinate space in a single frame - NDC
`-1..1`, `0..1`, `0..100`, `800x600`, and raw `3840x2160` pixels, five colours. **None of them
appeared.** Feeding it raw pixels or normalised values makes no difference: it emits
world-space geometry into the aux buffer either way (the "white pyramid"). There is no screen
space that makes `System.Draw2DLine` draw in 2D in this build. Stop trying.

`System.DrawText` is the one immediate-mode primitive that works. **The 2012 scriptbind doc
gives the wrong signature for this build.** The doc says
`(x, y, text, font, size, p2y, r, g, b, alpha)`; passing that shifts every argument along by
two and everything renders magenta - `size` swallows the font string, `r` gets the size
(clamped to 1), `g` gets the `p2y` 0, `b` gets the red. The real one, confirmed against the
base game's own call in `CrimeDebugger.lua` (`System.DrawText(x, y, str, 3)`), is:

```lua
System.DrawText(x, y, text, size, r, g, b, alpha)
--               ^screen pixels   ^decimals ok   ^0..1
```

Confirmed: arbitrary screen pixel position, arbitrary colour per call, arbitrary size. That
makes it a **plotter** - one call places one coloured mark anywhere on screen. It is not a
framebuffer, and every mark costs a draw call, so treat the glyph count as a budget.

Two things worth knowing before shrinking glyphs:

- **Leave `r_AuxGeomAutoScaleOver1080pWH` at 1.** Setting it to 0 does not shrink the font,
  it makes `DrawText` stop rendering entirely. Measured.
- `size` accepts **decimals**, and that is the way to get small: `merc_ui_px 0.5 2` and
  similar. Sub-1 sizes work.
- Draw a horizontal run in **one** call with `string.rep(glyph, n)` rather than n calls. Only
  vertical and diagonal runs need one call per point.

### The two primitives use different coordinate spaces

Measured on a 3840x2160 viewport:

- **`System.DrawText` takes real backbuffer pixels.** Labels asked for at `(400,300)`,
  `(960,540)`, `(1820,1020)` landed exactly there. It goes through the font renderer, not aux
  geom, which is why it works even when lines do not.
- **`System.Draw2DLine` does not.** It goes through aux geom with 2D render flags, where
  coordinates are **normalised 0..1**. Feeding it pixel values throws the geometry off toward
  infinity — the symptom is not "nothing draws", it is a large white shape apparently floating
  in the world.

So the wrapper for a pixel-space API is:

```lua
local vp = System.GetViewport()          -- {x, y, width, height}
local function line(x1, y1, x2, y2, r, g, b, a)   -- pixels in
    System.Draw2DLine(x1/vp.width, y1/vp.height, x2/vp.width, y2/vp.height, r, g, b, a)
end
local function dot(x, y, r, g, b, a) line(x, y, x + 1, y, r, g, b, a) end
```

`merc_ui_draw pixels` is the proof: a checkerboard of individual 1px dots, a 256-pixel colour
gradient one pixel at a time, and a 1px diagonal. `merc_ui_draw raw` is the control that
reproduces the pyramid.

---

## The battle command interface

`mercenaries_cmdui.lua` is the Bannerlord-style order UI, currently a **visual prototype** -
the orders light up and log, nothing is wired to the squad yet.

It is drawn entirely with `DrawText`, so it demonstrates the whole technique:

- **A panel is rows of a repeated glyph.** `fill()` emits one `DrawText` per row with
  `string.rep(glyph, n)`, so a 250x140 card costs ~10 calls, not 3500. A border is four thin
  fills. There is no rectangle primitive, and this is the substitute.
- Because panels are glyph grids, `cellW`/`cellH` must match the font's actual advance and
  line height. `merc_cmd_cal` draws a 10px-tick ruler plus a 20-glyph run and a 6-row stack;
  read the real numbers off the screen and set them with `merc_cmd_cell <w> <h>`. Rows are
  stepped at `cellH * rowStep` (0.8) so they overlap slightly and a fill has no seams.
- **The debug font is ASCII only.** Measured with `merc_cmd_chars`: `U+2588` full block, all
  three shade densities, both half blocks and `U+25A0` render as empty tofu boxes. There is no
  block-drawing character to build panels from. The usable fill is **`_`** - a run of
  underscores is an unbroken line, so a filled rectangle is rows of underscores a few pixels
  apart (`merc_cmd_row <px>`). `=` gives a striped fill; `# @ 8` are dense but gappy.
- A border is drawn with the same `fill`, so it is **one glyph row thick** whatever thickness
  you ask for - `fill` cannot draw anything thinner than one glyph.
- Layout is authored at 1080p and multiplied by `S = viewportHeight / 1080`.

Controls follow Bannerlord's two-level scheme: **one key opens an order category, then the
same keys pick the order inside it**, dispatched on whether a category is open. Numpad 1-4
toggles a formation, numpad 0 selects all. F9 hides, F10 releases the keys.

Three function keys are unavailable and the layout works around them: **F1** is reserved by
the game, **F12** is Steam's screenshot key, and **F5** is left alone so quicksave keeps
working. The usable slots are therefore `F2 F3 F4 F6 F7 F8 F11`, held in `CMD.keys` as
`{binding, label}` pairs so the on-screen hints and the actual bindings cannot drift apart -
change that one table to relayout the whole interface.

`merc_cmd_keys` binds everything and turns it on.

### Tuning it without a human at the keyboard

`tools/uitune.ps1 -Setup` launches the game windowed and loads a save. That step needs the
keyboard, because the save has to be picked off the main menu, and it takes the foreground
while it does. **Everything after that is keyboard-free.**

The trick is that the console cannot be driven by SendInput at all - typed characters go to
gameplay instead (an "m" opens the map), and on a non-US layout shift+minus yields `?` not
`_`. So the mod arms its own poll instead: `merc_cmd_remote` re-runs
`exec merc_ui_ctl.cfg` from the game root once a second, and the host script drives the
running game purely by writing that file. Two consequences worth knowing:

- **Every command the loop sends must be idempotent**, because the file re-executes every
  second. That is why there is `merc_cmd_on` and `merc_cmd_cat <n>` (setters) alongside the
  toggles a human uses.
- A load-time timer will not do: timers do not survive loading a save. The poll is armed
  from the engine's `OnGameplayStarted` event instead.

`tools/uicycle.sh <out.jpg> "<cmd>" ...` is one full cycle - push commands, screenshot,
copy it out. It waits for the screenshot file size to stop changing before copying, because
the game writes a 5 MB JPEG progressively and grabbing it early yields a half-grey image.

The whole layout is live-tunable (`merc_cmd_lay <key> <value>`, `merc_cmd_lay_dump`), so a
tuning session is one launch and then N screenshot/adjust cycles with no relaunch.

## What the disassembly settles

Two questions were left open by the file-and-runtime work above, and both are answered from
`WHGame.dll` (build `release_1_5_1308617_856`) using the corpus in `E:\kcd2_disasm` - see
`docs/disassembly.md` and `tools/disasm_query.py`.

### A mod CAN add its own element - the folder really is scanned

`CFlashUI::vf4` calls `sub_19A6FF8` (RVA `0x19A6FF8`), which builds `<base>/UIElements` and
scans it with the wildcard `*.xml`. The scan runs through **CryPak**: `CCryPak` vtable slots
63/64/65 - `FindFirst` / `FindNext` / `FindClose` - called with `bAllowUseFileSystem = 0`, so
loose mod folders and mod `.pak` archives are both on the search path, exactly like every
other `Data/*` file the mod already ships.

`CFlashUI::vf11` (RVA `0x563AE0`) then parses each file it finds:

```
00563B14  call [r8 + 0x418]    ; LoadXmlFromFile
00563B37  lea rdx, "name"      ; GetAttr("name")   <- a RUNTIME STRING
00563BBA  call sub_4F75C0(0x250)   ; new CFlashUIElement
00563BF1  ...                      ; insert, keyed by that name
```

The element's identity comes from the XML `name=` attribute at load time and goes into
`GUIModule`'s `UIElementsByName` map. **Nothing in that path resolves a name against a
compiled-in list**, so a new name works. `data/libs/UI/UIElements/MercTest.xml` is the
standing proof-of-concept - it binds a new element to a *vanilla* movie so the test isolates
"does a new element register?" from "can we author a `.gfx`?". Run `merc_ui_elem`, which
probes the new name, a known-good vanilla name, and a deliberately bogus name as a control.

### A hand-built `.swf` loads - `wh_gfx_useSWF` is real

Registered at RVA `0x16F2BE8` with **default 0 and `nFlags = 0`** - a normal cvar, not cheat-
or dev-gated, so it is settable in retail. It has exactly one read site, `sub_88FBA8 + 0x91`
(RVA `0x0088FC39`), inside the per-element movie loader:

```
0088FC39  cmp dword ptr [wh_gfx_useSWF], 0
0088FC40  je  ...              ; 0 -> never try .swf at all
```

With it set, the loader takes the declared movie name, strips the three characters `gfx` and
appends the literal `"swf"` (`.rdata:0x3DF38B8`), then asks CryPak `IsFileExist`. Resolution
order for a movie declared as `Foo.gfx`:

1. `<gfx_uiaction_folder>/Foo.swf` - only if `wh_gfx_useSWF` is non-zero
2. `<gfx_uiaction_folder>/Foo.gfx` - the un-swapped name
3. bare `Foo.gfx` with no folder prefix, unconditionally, no existence check

`gfx_uiaction_folder` is itself a cvar, default `Libs/UI/`. No other extension is ever tried.
If the movie fails to load **and** the element is `Menu.gfx`, it is a fatal error.

The practical consequence: **the discontinued Scaleform exporter is not a blocker.** Set
`wh_gfx_useSWF 1`, ship `Data/Libs/UI/Foo.swf`, and ship no `Foo.gfx` of that name. A plain
SWF from JPEXS or Haxe/OpenFL is enough - keep to SWF v8 / AS2, which is what every vanilla
movie is.

### Flash can display real images

`CryGFxImageLoader::vf2` (RVA `0x80B14C`) resolves image URLs for Scaleform and understands
`://TEXID:<n>` (an engine texture by id), `img://Libs/UI/qr:<data>` (a QR code generated on
the fly, `sub_D5DF14`), `%user%` expansion, and a named lookup against
`wh::engine::C_ImageSourceManager`. That family includes **`wh::engine::C_PngImageSource`**,
so PNG decoding exists. A custom screen is therefore not limited to text and rectangles.

### A native plugin cannot invent an element - the XML is the only door

`gEnv->pFlashUI` is a plain member at **`gEnv + 0x138`** (RVA `0x492D938`), no getter. Every
one of the 28 `UIAction.*` Lua binds funnels through one helper,
`CScriptBindUIAction::ResolveElementInstance` (RVA `0x35AD414`), which does:

```
mov rcx, [gEnv+0x138]        ; IFlashUI*
mov rax, [rcx]
call [rax+0x70]              ; CFlashUI slot 14 = GetUIElement(name)
```

and **bails if that returns null**. A search for `RegisterElement` / `CreateElement` /
`UIElements.xml` finds nothing, and the only `CFlashUI` slot that touches the elements
container (slot 40) merely iterates it for memory accounting - there is no Add. So a C++
plugin buys you no new capability here: it can drive elements faster by caching the
`CFlashUIElement*` and skipping Lua marshalling, but it cannot manufacture an element that no
XML declared. **Shipping the XML is the route, not a workaround for lacking one.**

Useful slots if a plugin is ever worth it (ordinals are reliable; the names are inferred):

| Vtable | Slot | RVA | Inferred |
|---|---|---|---|
| `CFlashUI` | 14 | `0x7F4DF0` | `GetUIElement(name)` |
| `CFlashUIElement` | 4 | `0x555EE4` | `GetInstance(instanceID)` |
| `CFlashUIElement` | 28 | `0x568510` | `SetVisible(bool)` |
| `CFlashUIElement` | 59 | `0x7F6F20` | `InvokeFunction(fn, args, ret)` |
| `CFlashUIElement` | 44 / 77 / 79 | `0x35B0688` / `0x35C0C5C` / `0x35B04F4` | variable handle / set / get |
| `CFlashUIElement` | 47 / 85 | `0x359FAE8` / `0x359F788` | array handle / get |

---

## The recipe for a real custom screen

Everything above adds up to one buildable path:

1. Author a movie with free tooling - **SWF v8 / ActionScript 2**, which is what every vanilla
   `.gfx` is. JPEXS or Haxe/OpenFL both produce this.
2. Ship it as `Data/Libs/UI/MyScreen.swf`, and **no** `MyScreen.gfx` of that name.
3. Ship `Data/Libs/UI/UIElements/MyScreen.xml` declaring the element `name`, the movie, and its
   `functions` / `events` / `arrays` / `MovieClips` contract.
4. Set `wh_gfx_useSWF 1` (normal cvar, settable in retail).
5. Drive it from Lua: `UIAction.ShowElement`, `CallFunction`, `SetArray`,
   `RegisterElementListener` for input coming back.
6. Artwork via the `img://` protocols, with PNG decoding available.

The two things that would have killed this - a fixed element list, and needing the dead
Scaleform compiler - are both disproved at instruction level.

## The limits test: our own Scaleform element

`tools/make_swf.py` writes a **SWF v8 / AS2 movie from scratch, with no dependencies** - the
format is documented and the file is small, so there is no need for JPEXS or the dead
Scaleform exporter at all. It emits two files from one source so the names cannot drift:

```
data/libs/UI/MercUI.swf                 48 named sprites, zero ActionScript
data/libs/UI/UIElements/MercUI.xml      the element contract, 48 MovieClips declared
```

The movie is deliberately dumb: a solid rectangle per sprite, each placed with a
`PlaceObject2` instance **name**. That is the `LockPicking.gfx` pattern - vanilla's
lockpicking movie declares zero functions and is driven entirely from outside - so every
sprite is controlled from Lua by `SetPos` / `SetScale` / `SetRotation` / `SetAlpha` /
`SetVisible`.

**One named rectangle is the primitive we never had.** A real filled rectangle at any
position, size, rotation and opacity is exactly what the ASCII-underscore panel hack was
faking, badly and at ~1600 draw calls.

Two details the generator gets right because the disassembly said to:

- the XML declares the movie as `MercUI.gfx`, **not** `.swf` - the loader strips `gfx` and
  appends `swf` itself, so the `.gfx` name is what belongs in the contract
- no `MercUI.gfx` may exist anywhere in the VFS, or it wins the existence check first

Sanity-check the writer before spending a game launch:

```
python tools/make_swf.py --verify data/libs/UI/MercUI.swf
```

The bit-packed shape records are the only easy thing to get wrong; a round-trip decoder
confirmed one shape parses back to 4 straight edges plus an end record, consuming its tag body
exactly.

### Running it

`wh_gfx_useSWF` must be 1 and **the element list is built at `CFlashUI` init, so a new element
needs a game restart** - it will not appear live.

| Command | Tests |
|---|---|
| `merc_swf` | status: the cvar, the folder, what to run |
| `merc_swf_on` / `_off` | `ShowElement` on our own element |
| `merc_swf_grid` | `SetPos` - 48 clips on a grid, and whether the stage is 1:1 with pixels |
| `merc_swf_bars` | `SetScale` - a real bar chart |
| `merc_swf_spin` | `SetRotation` |
| `merc_swf_fade` | `SetAlpha` |
| `merc_swf_stress` | all 48 moved and rotated every frame, with an fps readout |
| `merc_swf_probe` | set a transform then read it back, **with an undeclared-element control** |

That control matters: `merc_ui_elem` came back inconclusive precisely because `GetPos` answers
`(0,0)` for an element name that does not exist, so a read-back alone proves nothing. The
probe now sets a distinctive transform and checks the value that comes back *matches*, and
runs the same calls against a bogus name to show they do not.

## Why a buff icon works and a new element does not

Worth understanding, because it is the difference between the two kinds of custom UI asset.
Traced end to end from `WHGame.dll` plus the data files.

A mod's custom buff icon reaches the screen like this:

1. **`icon_id="<name>"`** on a row in an RPG buff table (`libs/tables/rpg/buff__*.xml`). A plain
   string; the compiled `.tbl` still carries the bare id, no path, no extension.
2. The asset must be **`<name>_icon.dds` in `Libs/UI/Textures/Icons/Buffs/`** - an exact
   convention. Interestingly this string is **not in the binary at all**: an exhaustive search
   for `_icon.dds` / `Icons/Buffs` / `Buffs/%s` across all 135,611 strings returns nothing, so
   the expansion happens inside `hud.gfx`'s own compiled ActionScript.
3. `wh::rpgmodule::C_BuffManager::vf7` (RVA `0x46D6C4`) resolves the descriptor and fans out to
   `C_UIHudBuffs::AddBuff` (RVA `0xC4BAB8`) and `C_UIApseBuffs::AddBuff` (RVA `0x2AFDB4C`).
4. Those call the Flash function `AddBuff` by name through the same generic bridge Lua's
   `UIAction.CallFunction` uses - `CFlashUIElement` slot 59 `InvokeFunction` (RVA `0x7F6F20`).
   `HUD.xml` only *documents* the contract (`<function name="AddBuff" funcname="fc_addBuff">`);
   `hud.gfx` *implements* it.
5. `hud.gfx` asks for the image via `img://`, handled by `CryGFxImageLoader::vf2`
   (RVA `0x80B14C`), falling back to a string-keyed lookup in `C_ImageSourceManager`.
6. The one mandatory registration point is a **wildcard glob** already present in
   `Data/Libs/UI/TexturePreload.xml`:

   ```xml
   <Preload file="Libs/UI/Textures/Icons/Buffs/*"/>
   ```

   Any `.dds` a mod drops in that folder is swept up at startup. No per-file entry anywhere.

**So the mod supplies data and an asset, and nothing else.** Every Flash-side step -
`fc_addBuff`, the `<id>_icon.dds` expansion, the image resolution - was compiled into
`hud.gfx` by Warhorse and comes free.

A brand-new element has no equivalent free ride. Registration is genuinely open (proved
above), but **a `UIElements` XML only describes which movie to bind and which entry points to
expose - it cannot manufacture the movie's content.** That is the whole difficulty: we are not
blocked on the engine accepting our element, we are blocked on authoring Flash content it will
render.

## CONFIRMED: a mod can ship its own Scaleform UI

A hand-written SWF, generated by `tools/make_swf.py` with no authoring tool, **rendered in
game**. The full chain works:

1. `data/libs/UI/UIElements/MercUI.xml` - a mod-supplied element registers under its own name
2. `wh_gfx_useSWF = 1` in `user.cfg` - set before anything loads, or the loader never tries
   the `.swf` (it is read inside the loader, so setting it from the console is too late)
3. `data/libs/UI/MercUI.swf` - SWF v8 / AS2, `FileAttributes` first, solid shapes wrapped in
   `DefineSprite`s, each placed with a `PlaceObject2` instance name
4. `UIAction.ShowElement("MercUI", 0)` from Lua

**`SetScale` and `SetAlpha` are in PERCENT, not multipliers.** Flash's `_xscale`/`_yscale` are
100 = natural size and `_alpha` is 0..100. An untouched clip reads back as
`scale=(100,100) alpha=100`. Passing `1` therefore means **one percent** - a hundredth-size,
1%-opaque clip. On screen that is indistinguishable from the UI being hidden or unloaded a
moment after it is laid out, which is exactly what it looked like for several rounds. `SetPos`
is *not* a percentage; it is in stage units. Wrap them:

```lua
local function setscale(i, sx, sy)   -- sane multipliers in, percent out
    UIAction.SetScale(el, 0, clip(i), { x = sx * 100, y = sy * 100, z = 100 })
end
local function setalpha(i, a)        -- 0..1 in, 0..100 out
    UIAction.SetAlpha(el, 0, clip(i), a * 100)
end
```

Two more things the first successful render taught us, both of which had been masking as
failure:

- **The stage is the authored size and is scaled to the backbuffer.** A 1280x720 stage on a
  3840x2160 screen renders everything at 3x. `SetPos` takes **stage units**, not pixels -
  `(640, 360)` is screen centre regardless of resolution, which is a *better* deal than the
  `DrawText` path where every number had to be scaled by hand.
- **The movie is built when the element is first displayed**, so it is still worth deferring
  the first layout by a frame or two rather than issuing it in the same call as `ShowElement`.
- A one-frame timeline **loops** and re-executes its `PlaceObject2` tags, re-placing every
  clip at its authored matrix. `tools/make_swf.py` emits a `DoAction`/`ActionStop` on the root
  and inside each sprite to prevent that.

**How this was actually found, because the method mattered more than any of the theories.**
Four successive explanations - cvar timing, call ordering, tests overwriting each other, the
looping timeline - were all wrong, and each cost a game restart. The symptom ("appears, then
disappears") is produced identically by a reverted transform, a hidden clip and an unloaded
element. Polling the element every 250ms and logging `pos/scale/vis/alpha` separated them in
one run:

```
t=0.25s  pos=(20,20)    scale=(100.00,100.00)  vis=true  alpha=100   <- authored
t=0.50s  pos=(120,120)  scale=(1.00,1.00)      vis=true  alpha=1     <- after layout
t=6.00s  pos=(120,120)  scale=(1.00,1.00)      vis=true  alpha=1     <- stable
```

Nothing reverted, nothing hid, nothing unloaded - the state was correct and stable the whole
time. The clips were simply 1% of their size at 1% opacity. `merc_swf_watch` is kept for
exactly this reason: when a UI symptom has several indistinguishable causes, measure the state
instead of reasoning about it.

The practical upshot: **real filled rectangles at any position, scale, rotation and opacity**,
which is the primitive the ASCII-underscore panel hack existed to fake. The command UI can be
rebuilt on this instead.

## Recommendations for the three screens

### Camp upgrades - use `Menu` on a private instance, today

`AddBasicButton` + `AddValueButton` + `AddConfirmation` gives a native-looking, paged,
mouse-driven purchase screen with tooltips and prices in the label, and the Companion mod is a
working reference implementation to copy. No new assets, no Flash editing, no risk. It will
not look like the forge plan screen - it is a list, not a diorama - but it ships immediately.

If the list is not enough, build a custom element with a background plate, an icon grid and a
detail pane. **`ForgeBuilderPlan` is a bad donor**: its contract is `FillData(Type:int)`
against an internal enum plus opaque slot/asset id strings, and the real work happens in
`hud.gfx`'s `SetForgeBuilderSlots` / `SetForgeBuilderAssets`. Build your own instead.

### Logistics with graphs - `System.Draw2DLine` first, custom element second

Morale, tiredness, food, drink, coffer and wages are already tracked in
`mercenaries_logistics.lua`. Ring-buffer a few hundred samples and draw them with
`Draw2DLine` + `DrawText` from an `OnUpdate` - a real line chart in an afternoon, and it tells
you whether the feature earns a Flash implementation. A custom element then buys proper axes,
fills and mouse hover.

### Bannerlord command screen - the ambitious one, and tractable in pieces

It decomposes into parts that already exist:

- **Unit markers over the battlefield**: `SetBubbleText(1..16)` + `UIAction.SetPos` on
  `bubble1..16`. The engine ships a flownode that converts a world position to flash stage
  coordinates with 2.5D depth scaling, so the projection maths is solved.
- **Order issuing**: `Menu` on a private instance, or the existing chat order wheel.
- **Input capture**: `ActionMapManager.EnableActionMap("menu", true)` plus
  `PlayerEventDispatcher:Register("OnActionEvent", ...)`, exactly as the Companion mod does.
- **A tactical map view**: the one part that needs a custom element - a top-down plate plus
  one MovieClip per squad, positioned from Lua. `LockPicking` proves an element with zero
  ActionScript can be driven entirely by `SetPos`/`SetRotation`.

Sequence it: markers and orders on vanilla elements first, custom map element last.

---

## Dead ends

- **Persistent Debug (`pd_*`)** is not compiled into this build - zero matching strings in the
  DLL.
- **`Libs/UI/Textures/Dynamic/`** is not a writable canvas; it is ~150 pre-baked `.dds`
  referenced by path from vanilla screens.
- **Render-to-texture from Lua** does not exist. The only RTT mechanism found
  (`FlashDynTexture`) is Scaleform again.
- **A grid of textured quads as a pixel display** is a draw-call trap - see
  `docs/performance.md`. One quad with a baked texture beats N quads every time.
- **The world map tables** (`ui_map_label.xml`, `ui_local_maps.xml`) are level-baked and
  GUID-keyed; replacing them to host custom content means shared-table conflicts.

---

## The test bench

`data/Scripts/mods/mercenaries_uitest.lua` is a set of dev commands that each answer one
question. Type `merc_dev` first (they are dev-gated), then `merc_ui` for the list.
**`merc_ui_off` is the panic button** - it restores the HUD and the action map if a test
leaves the screen wedged.

| Command | Question it answers |
|---|---|
| `merc_ui_probe` | Which UI APIs exist in this build, and what is the viewport/stage size |
| `merc_ui_menu` | Can we build an interactive screen? Buttons, a slider, a dropdown, a confirmation, page navigation - all with click events coming back to Lua |
| `merc_ui_modal` | Does `ApseModalDialog` take arbitrary strings, and does its answer come back |
| `merc_ui_book` | Can `AlchemyBook` be used as a two-page text panel |
| `merc_ui_array` | Can Lua push rows into a bound flash array (`SetArray`/`GetArray`) - the gate on reusing any vanilla list screen |
| `merc_ui_text` | Which of the four toast channels actually appear |
| `merc_ui_html <s>` | Does HTML markup render in subtitles/tutorials, and does `img://` load a texture |
| `merc_ui_bubbles` | Place 8 HUD bubbles at known coordinates |
| `merc_ui_gpos <n>` | Read a bubble's real position back - this is how you learn the stage coordinate space |
| `merc_ui_bpos <n x y>`, `merc_ui_stage <w h>` | Calibrate that space by hand |
| `merc_ui_track` | The overlay core: project every merc's world position to the screen and label it. Needs a squad - with zero mercs it draws nothing and says so |
| `merc_ui_lock` / `merc_ui_lockpos <clip> <x> <y>` | Show `LockPicking` and move its clips. The cleanest test of "can Lua put a Flash sprite anywhere", because unlike the HUD nothing else is fighting for those positions. It also dumps the clips' real coordinates, which is how you learn the stage space |
| `merc_ui_draw_calib` / `_pixels` / `_graph` / `_world` / `_raw`, `merc_ui_draw` to stop | Immediate-mode, from a real per-frame `OnUpdate`, with `r_enableAuxGeom`/`r_auxGeom` forced on and logged. `calib` draws one rectangle per candidate coordinate space (0-100, 800x600, 1280x720, 1920x1080, 3840x2160) - exactly one will frame the screen; `pixels` is a dense dot grid; `world` uses the 3D primitives, which take a different renderer path, so if those draw and the 2D ones don't the fault is the 2D path specifically. It logs a heartbeat every second so you can tell "not rendering" from "not running" |
| `merc_ui_keys` | Bind F6-F9 and drive the overlay from the keyboard |
| `merc_ui_ov` / `_next` / `_cmd` | The Bannerlord-style loop: command mode on, cycle selection, issue an order |

`merc_ui_draw` spawns `mercenaries_UIDraw` (in `data/Scripts/Entities/`), an invisible entity
that exists only for its `OnUpdate` - `System.DrawText` and `System.Draw2DLine` last exactly
one frame, and the mod's own loops are ~100 ms timers.

### Suggested order

1. `merc_ui_probe` - if `UIAction` is nil nothing else will work.
2. `merc_ui_menu` - the single most informative test; if buttons come back to Lua, the camp
   upgrade screen is a solved problem.
3. `merc_ui_bubbles` then `merc_ui_gpos 1` - learn the stage coordinate space.
4. `merc_ui_track` with a squad out - the Bannerlord overlay in miniature.
5. `merc_ui_proj` - measure the ProjectToScreen space before trusting `merc_ui_track`.
6. `merc_ui_draw_pixels`, screenshot - decides whether graphs need Flash at all.

### Test in the dev build and read *its* log

The modding-tools build keeps its own log at `KCD2Mod\kcd.log`, entirely separate from the
retail one, and it is the only place Lua errors from console commands surface:

```
[Warning] Validator: [Lua Error] Error executing lua [string ""]:1: ')' expected near 'pixels'
```

The retail build swallows that silently - the symptom there is a command that does nothing and
logs nothing at all. A whole test round was lost to it.

The cause in that case: a command body must use **single** quotes around `%line`
(`"mercenaries:Foo('%line')"`). Escaped double quotes are stripped by the console tokenizer, so
the engine receives two bare identifiers. Worse, it can look like a success - a bare
`merc_ui_draw` parsed as `UIDraw(merc_ui_draw)`, which is valid Lua evaluating to `nil`, so the
function's own `mode or "calib"` default made the argument look honoured while it was never
being read. See `docs/console.md`.

### Raw one-liners

If you would rather not deploy the bench:

```
merc_lua System.LogAlways("UIAction=" .. tostring(UIAction))
merc_lua UIAction.CallFunction("hud", -1, "ShowNotification", "hello")
merc_lua UIAction.CallFunction("hud", -1, "SetBubbleText", 1, "Alpha squad", "", 10.0)
merc_lua UIAction.SetPos("hud", -1, "bubble1", {x=400, y=300, z=0})
```

## The game's own UI typefaces

KCD2's interface fonts are Warhorse originals and ship only inside the Scaleform font
library, never as .ttf. `tools/kcd_font.py` reads them straight out of the pak, so mod
panels are set in the same type as vanilla ones.

| logical name (fontconfig.xml) | face |
| --- | --- |
| `DefaultFont` | Kingdom Come Regular (+ bold, italic) |
| `DisplayFont` | Kingdom Come Display Md Display |
| `LightFont` | Kingdom Light Regular |
| `Manuscript` | Warhorse Manuscript |

Both font files live in `IPL_GameData.pak` under `Libs/UI/` and are `CFX` containers: a
4-byte magic, a 4-byte uncompressed length, then a zlib stream that inflates to an ordinary
SWF tag stream. The two are **not** interchangeable:

- `gfxfontlib.gfx` has the `DefineFont3` tags with their **outlines stripped** - metrics,
  code table and layout only. Parsing it gets you advances and no glyphs.
- `gfxfontlib_glyphs.gfx` has the same fonts **with** outlines (2 MB of shape data,
  `WideOffsets` set). This is the one to read.

A glyph is a plain SWF `SHAPE` record - style-change, straight-edge and quadratic-curve
records against fill style 1. Contours are filled **even-odd** so counters punch through.
Coordinates are twips of a 1024-unit em, so the em square is 20480 units.

`kcd_font.text(s, px, rgb, font="body")` returns RGBA. Its `px` is a true cap height;
`make_bl.py` scales every size through `KCD_CAP` because the same nominal size in Segoe UI
and in Kingdom Come Regular produce caps about 16% apart.

Not tried: referencing the face by name from a `DefineEditText` in a mod SWF and letting the
engine's font provider resolve it. That would give live text fields instead of baked
bitmaps, but a name that fails to resolve renders nothing at all, so it needs testing in
game before anything depends on it.

---

## Key caps, and other borrowed UI art

The game's key prompts - the `[E]` next to *Make camp here.* - are not drawn, they are a
texture plus a text field, and both are readable.

`Libs/UI/buttons.gfx` is a CFX container (4-byte magic, 4-byte length, zlib) holding a SWF
tag stream with **no embedded bitmaps at all**: 49 `DefineExternalImage2` tags naming
textures on disk under `Libs/UI/Textures/buttons/`, which ship loose. The three that matter:

| texture | size | drawn | used for |
| --- | --- | --- | --- |
| `key.dds` | 64x64 | 64 wide | one character |
| `key_middle.dds` | 128x64 | 95 wide | two or three |
| `key_long.dds` | 128x64 | 115 wide | longer, e.g. `Enter` |

All three are DXT5 and Pillow opens them directly. The cap is not a flat rounded rect: it
has a bevel and a tan **front face** along the bottom, as if seen slightly from above.

The letter comes from `DefineEditText`, which carries the exact typography:

    id=103 (single)   box 47.5 x 41.9 px, font height 600 twips = 30px, colour (0,0,0,255),
                      align=centre, leading -120 twips

and the sprite that assembles them (id=108, one frame per button type - frame 58 is the
single key) places the cap shape at 0,0 with bounds `x 0..64, y -32..32`, and the text field
at `30.30, -21.75`. So the letter is centred horizontally, and vertically it sits in the
**light face only**: rows 5..48 of the 64, centring the ink at **0.414** of the cap height.
Centring on the cap itself puts it visibly low, sitting over the front edge.

Two more things are needed before it matches, and neither is in `buttons.gfx`:

**What size to draw it.** `hud.gfx` is a **1920x1080** stage and places the button movie
(`hintIcon0`, inside `mc_ApseTopRightActionHint` and friends) at **scale 0.5**, so the 64px
cap is drawn 32px there. Against our 1280-wide stage that is 21.33 units - which happens to
be exactly its 64 authored pixels at `ss=3`, so the texture is used at native size and never
resampled at all.

**The label beside it.** `mc_ApseTopRightActionHint/text/tField` is `DefaultFont` at **22px**
in colour **(255,255,255)** - the *regular* face, not the bold one used on the cap - which is
14.67 of our units. That clip also settles the order: it puts the text at x=0 and the icon at
x=155, so the word comes first and the cap second.

**The cap is not cut out cleanly.** A couple of pixels of dark, barely-opaque edge run all
the way round the texture, and at prompt size that reads as a drop shadow. `_dekey_shadow()`
zeroes anything under alpha 40. Only the alpha needs touching: the SWF encoder stores bitmaps
alpha-premultiplied, so whatever RGB sits under a transparent pixel is multiplied away at
build time and can never smear back out at runtime.

`keycap()` in `tools/make_bl.py` reproduces all of that. The three `.dds` files are copied
into `assets/ui/keycaps/` so a rebuild does not need the game installed.

The general lesson: before drawing an imitation of a vanilla UI element, check whether it is
a texture. `buttons.gfx` gave up the art, the type size, the colour and the offsets in about
twenty minutes of parsing, and the result is exact rather than close.
