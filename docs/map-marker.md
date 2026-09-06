# Putting your own marker on the world map

**Short version:** the map is a Scaleform movie, not a game system with a script binding.
`UIAction` talks to Scaleform. Nine values in an array and two calls, and there is a POI on
the map at any world position you like.

```lua
UIAction.SetArray("ApseMap", -1, "PoiMarkers",
    { 1, "MERC_CAMP", "merc_ui_camp_marker", "camp", 1, false, 0, worldX, worldY })
UIAction.CallFunction("ApseMap", -1, "AddPoiMarkers")
```

That is the whole mechanism. In this mod it lives in
`data/Scripts/mods/mercenaries_mapmarker.lua` and draws the standing camp
(`merc_camp_marker 0 | 1`).

---

## Why this took so long to find

Everything the mod had previously concluded about map markers is still true, and all of it
was looking in the wrong place:

* there is no `Map` global in the live Lua state, and `C_ScriptBind_Map` exposes only
  `CallScript`;
* `UIMap` is `{ GoToCheckpointMark() }` and nothing else;
* `LocationPoint` self-registers through `RPG.AddLocationPoint`, but Kuttenberg's level data
  contains **zero** LocationPoint entities while its map is full of POIs, so map places do
  not come from world entities;
* `QuestSystem` is absent, so `RegisterQuestEntity` is unreachable;
* a Skald `ShowMapMarker` on a Lua-spawned NPC never renders — see
  [aleksej.md](aleksej.md) and [bandit-camp-quest.md](bandit-camp-quest.md).

None of that matters, because the map does not need a game system. It needs the UI.

## Where the contract is written down

Two files in the base game, both worth reading before changing any of this.

**`Libs/UI/UIElements/ApseMap.xml`** — the element's public surface:

```xml
<function name="AddPoiMarkers"    funcname="fc_addPoiMarkers" />     <!-- no parameters -->
<function name="RemovePoiMarkers" funcname="fc_removePoiMarkers" />  <!-- no parameters -->
...
<array name="PoiMarkers" varname="g_PoiMarkersA" />
```

Neither function takes an argument: both act on the `PoiMarkers` array you set first.

**`Libs/UI/ApseMap.gfx`** — the `PoiMarker` class. It is a compiled Scaleform movie, but it
decompresses with `zlib` past the 8-byte header and the ActionScript constant pool is
readable. `SetData` reads `Id`, `m_UiName`, `m_IconName`, `m_IsFastTravel` and `m_Position`,
then builds a texture path:

```
Libs/UI/Textures/Icons/Map/<iconName>[_undiscovered]_icon.dds
Libs/UI/Textures/Icons/Map/<iconName>_sh_icon.dds        (the drop shadow)
```

## The nine values

| # | Meaning | Notes |
|---|---|---|
| 1 | Id | `1` is what the shipped mods send |
| 2 | Unique key | what `FocusOnUniquePoi` and the map's `GetByKey` look up |
| 3 | UI text key | a row in your `localization/*_xml.xml`; the tooltip |
| 4 | Icon name | resolved to the `.dds` above — **this is where the icon comes from** |
| 5 | State | discovered; `0` asks for the `_undiscovered` texture instead |
| 6 | Is fast travel | `false` unless you are adding a travel point |
| 7 | — | `0` in both shipped mods |
| 8 | World X | not map coordinates; the movie transforms them |
| 9 | World Y | |

**The icon needs no art if the base game already has one.** `camp_icon.dds`,
`camp_sh_icon.dds` and `camp_undiscovered_icon.dds` all ship in
`Libs/UI/Textures/icons/Map`, so `"camp"` is enough. To use an icon of your own, ship
`<name>_icon.dds` and `<name>_sh_icon.dds` in that path and pass `<name>` — that is what
`references/ddv_hc_map_marker` does, and what this mod now does.

## Making a marker bigger — and the texture format trap

Two things decide a POI's rendered size, and only one of them is available to a mod.

`PoiMarker.SetScale` asks `GetPoiImportance(type)`, and a **fixed list** of type names gets
`POI_IMPORTANCE_HIGH`: `PoiTipster`, `QuestGiver`, `ActivityGiver`, `Hub`, `FastTravel`,
`FastTravelLevel`, `FastTravelSedlec`, `DLC0`–`DLC3`, the `DLC2_*` set, and `Nest`.
Everything else shrinks sooner as you zoom out. A mod cannot join that list without shipping
a texture under one of those names, which would replace the vanilla icon everywhere it is
used — a dead end for custom markers.

**The texture's native size is the lever.** The movie scales the loaded clip with
`_xscale`/`_yscale`, which are percentages of native size. Every stock map icon is 64×64
— *including the quest markers*, so a quest marker looks bigger only because of the scale
its own class applies, not because of its art. `ddv_hc_map_marker` ships a 100×100 icon and
it renders proportionally larger.

### The trap (measured, 2026-09-06)

Shipping 128×128 icons was tried and **reverted: all three markers drew with no texture at
all.** The route was fine; the files were not.

| field | vanilla `camp_icon.dds` | Pillow `pixel_format="BC3"` |
|---|---|---|
| `dxgiFormat` | 98 (`BC7_UNORM`) | 76 (`BC3_TYPELESS`) |
| `arraySize` | 1 | **0** — invalid, D3D requires ≥ 1 |
| `flags` | `0x1007` | `0x81007` — claims `DDSD_LINEARSIZE`… |
| `pitch` | 0 | 524 — …with a wrong value |

Two independent faults: a *typeless* format, and `arraySize = 0`. **Stock map icons are BC7,
not BC3**, and Pillow cannot write BC7 at all (`cannot write pixel format BC7`).

So: if a custom map icon renders as nothing, suspect the DDS header before anything else,
and dump `dxgiFormat`/`arraySize` first — `python tools/gen_map_icons.py --verify` prints
them next to vanilla's.

`tools/gen_map_icons.py` now writes **legacy DXT5** instead — fourcc in the old header with
no DX10 extension block, so none of those fields can be got wrong. It is written and
documented but **not wired in**: `MapMarkerRows` passes vanilla icon names, which cannot fail
this way. If the bigger icons are wanted, run the tool, point one row at its output, and
confirm in game before doing the other two.

```bash
python tools/gen_map_icons.py 2.0      # build at 2x
python tools/gen_map_icons.py --verify # compare headers against vanilla
```

## When to push it

Register for the map's own show event and add the marker then:

```lua
UIAction.RegisterElementListener(mercenaries, "ApseMap", -1, "OnShow", "CampMapMarkerShow")
UIAction.RegisterElementListener(mercenaries, "ApseMap", -1, "OnHide", "CampMapMarkerHide")
```

The movie's `fc_open` teardown clears the marker containers when the map closes, so every
opening starts empty and the game re-pushes its own POIs. Adding yours on each `OnShow` is
therefore both necessary and sufficient, and it cannot accumulate duplicates.

**Do not call `RemovePoiMarkers`.** It takes no argument and clears the whole container —
the game's own POIs with it. `ddv_hc_map_marker` calls it three times a second because it
is redrawing a marker that moves while the map is open; that is a trade worth making only
if you actually need one.

Both shipped reference mods re-register their listeners on every `OnGameplayStarted` rather
than once per session, and neither drops the old registration first — so both are one stacked
listener away from adding their marker twice. There is no need to live with that. The
scriptbind docs give a matching unregister, which the element XMLs do not mention:

```lua
UIAction.UnregisterElementListener( table, callbackFunctionName )   -- "" drops all of them
```

Drop each callback before re-registering it and only one is ever live.

**The callback is invoked as a method**, despite the docs writing it as
`CallbackName(elementName, instanceId, eventName, argTable)`. Declare it with a colon:
`function handler:Cb(elementName, instanceId, eventName, argTable)`. Both reference mods
depend on this — one reads `elementName` correctly, the other assigns to `self` — and
declaring it with a dot would silently shift every argument by one.

## It can crash the game — mind the marker Id

Pushing two markers with ids `1` and `2`, both with real vanilla textures, **crashed the game
on opening the map**. Three runs bound it:

| markers | ids | textures | result |
|---|---|---|---|
| 1 | 1 | load | fine, all session |
| 2 | 1, 2 | fail to load | fine, clean exit |
| 2 | 1, 2 | load | **crash on the first opening** |

So it needs more than one marker *and* the icons actually resolving. No callstack was
produced, so the cause is not proven — but `PoiMarker` derives its clip depth from the Id
(`GetDepth`, `MAX_DEPTH`, `attachMovie`), and `1` and `2` are exactly where the game's own
POIs are likeliest to sit. Attaching over a live clip would leave a dangling reference.

This also retires the id-versus-count question for the leading array value: a leading *count*
of 666 would leave `ddv_hc_map_marker` visibly broken for everyone running it, so the leading
value is an **Id**, and that mod picking 666 out of the air looks like the same defence.

Three rules follow, and they are cheap enough to just keep:

1. **Use a high Id.** This mod uses 9001+.
2. **Push one marker per `SetArray` + `AddPoiMarkers` call.** Every call is then the exact
   shape of the single-marker push that is known to work, and the stride of a multi-record
   array never has to be guessed at.
3. **Push once per opening.** Re-adding the same markers repeatedly buys nothing once they
   render, and stacks clips at the same depths.

`merc_camp_marker 0` disables the whole thing, and the setting is read before anything is
pushed.

## The compass

Same idea, different element. `Libs/UI/UIElements/HUD.xml` documents it properly:

```
AddCompassMarker(MarkerID, MarkerType, MarkerState, QuestColor, ObjectiveNumber,
                 Distance, Frame, IsInsideArea, IsInsideArea2D,
                 NearThreshold, LayerThreshold, FarThreshold)
RemoveCompassMarker(MarkID)
UpdateCompass(Frame)
```

with an array `CompassMarkers` (`g_CompassMarkersA`) for the per-tick update:

```lua
UIAction.SetArray("hud", -1, "CompassMarkers", { 1, id, -1, dist, bearing, 0, false, false })
UIAction.CallFunction("hud", -1, "UpdateCompass", 0)
```

`hud.gfx`'s `CompassMarker` class carries `m_Id, m_Type, m_State, m_Angle, m_AnglePitch,
m_Distance, m_NearThreshold, m_LayerThreshold, m_FarThreshold, m_QuestColor,
m_ObjectiveNumber, m_IsInsideArea`, which the update array maps onto in order after the
leading value: id, quest colour, distance, **angle**, angle pitch, is-inside-area,
is-inside-area-2D. So the parameter HUD.xml calls `Frame` is `m_Angle`.

**The compass takes its icon from the same place the map does** — the class loads
`Libs/UI/Textures/Icons/Map/<type>[_undiscovered]_icon.dds`, with a `quest_` prefix only for
quest markers. Anything valid as a map POI icon is valid as a compass marker type, `camp`
included; there is no separate compass icon set to add art to.

**The one genuinely unverified thing is what that angle is measured from.** Nothing in the
UI data says. The one working example
(`references/NoHorseTeleportMapMarkersOnly`) takes the bearing *backwards* and adds 45°, its
author noting it "seems like the complete opposite of what it should be mathematically but
ok whatever". That is very likely a world-to-map rotation, and it may well differ between
Trosecko and Kutnohorsko.

So the camp's compass marker is **opt-in** (`merc_camp_compass 1`) and the fudge is a live
knob: `merc_camp_compass_offset <degrees>` (dev) turns it while you watch the compass.
Whoever settles the correct value per level should write it down here.

Unlike the map marker, the compass marker costs a repeating redraw — four times a second
while it is up — which is the other reason it is off by default.

## What this mod draws

Three POIs, all from one array in one push, each present only when it has somewhere to
point (`mercenaries.MapMarkerRows`):

| Marker | Icon | Where it points |
|---|---|---|
| The camp | `camp` (tents) | `CampBuildOrigin`, while a camp is standing |
| Mercenaries waiting | `weaponsmiths` (crossed blades) | `HoldAnchor` under a "wait here" order, else the men's centroid while idle. Not drawn while they are in camp |
| Aleksej | `weaponsmiths` (crossed blades) | Aleksej's live entity, found by id or by the name persisted in `AlxLodgingName` |

All three are vanilla icon names, so all three are certain to have art. `campEnemy` is
deliberately avoided for the waiting men — skull and red tent, it reads as hostile — and
nothing else uses a tent, so no marker can be mistaken for the camp. Aleksej shares the
crossed blades rather than taking `poiTipster`: that one is a map-pin shape and sits oddly
beside icons that are drawn objects. He and the waiting men are told apart by their labels.

Pushing three at once is also what settled the **id-versus-count** question about the
leading array value: nine values per record with the record's own Id first. `UIAction.GetArray`
does *not* settle it and should not be reached for — it returns 0 values every time,
including immediately after a `SetArray` that visibly drew a marker.

The camp is drawn only when it is **actually standing**, and this is deliberate. The save records the
camp's coordinates but not which level it stood on, and Trosecko and Kutnohorsko are
separate worlds sharing one coordinate space; a marker drawn from the saved origin alone
would land somewhere arbitrary on the other map. `CampActive` means a camp is up on the
level the player is looking at, so its origin is the right place to draw. No camp here, no
marker.

## Commands

| Command | What it does |
|---|---|
| `merc_camp_marker <0/1>` | Show the standing camp on the world map. Default on, saved |
| `merc_camp_compass <0/1>` | Also point at it on the compass. Default off, saved |
| `merc_camp_compass_offset [deg]` | **dev** — turn the compass bearing offset; no argument reports |

## References

* `references/NoHorseTeleportMapMarkersOnly` — map POI **and** compass marker for the
  player's horse; the clearer of the two, and the source of the compass parameter names.
* `references/ddv_hc_map_marker` — map POI only, refreshed while the map is open, with a
  custom icon texture pair.
