# Building a custom UI screen for KCD2

This is how I build a screen like the command interface or the camp screen, start to finish.
It took quite a bit of research to get the first one working, so I wrote down every step and
every trap I fell into. Follow it in order and you should have something on screen in an
afternoon instead of a fortnight.

Read [ui.md](ui.md) first if you want to know what Scaleform and `UIAction` actually are.
This page assumes you don't care and just want a screen.

One warning before you start. Almost everything in this pipeline fails **silently**. No
error, no log line, no missing-texture checkerboard. A clip in the wrong place, a clip that
doesn't exist, a keypress that never arrives and a screen that draws nothing all look
identical from the outside. That's why there's a checker at the end, and why I keep telling
you to run it.

---

## Before you start

You need:

- **Python 3.8+ and Pillow.** `pip install pillow`
- **The game installed**, if you want text in the game's own typefaces. The builder reads
  them straight out of the paks. Without it you get a system font and a warning.
- **`tools/kcdui/`** from this repo. Copy the folder into your project. It's the SWF writer,
  the art helpers, the font extraction, the compiler and the Lua runtime, about 1,500 lines,
  and it's the part you really don't want to write yourself.

Check the fonts work before anything else:

```bash
python tools/kcdui fonts
```

If it says the typefaces are readable you're set. If not, fix the `GAME` path at the top of
`tools/kcd_font.py` and try again.

---

## The pieces

A screen is four files. Three are generated and one you write by hand.

| file | what it is | who makes it |
| --- | --- | --- |
| `Libs/UI/MyScreen.swf` | the art, one MovieClip per thing that can move | the builder |
| `Libs/UI/UIElements/MyScreen.xml` | declares those clips to the engine | the builder |
| `Scripts/mods/myscreen_atlas.lua` | clip sizes and layout numbers | the builder |
| `Scripts/mods/myscreen_ui.lua` | the driver: state, layout, input | **you** |

The atlas is the important one. It's what stops the art and the code drifting apart. Your
driver should never hard-code a size, a position or a list of items, it reads all of that from
the table the builder emitted. Skip that and your first rebuild scatters the screen.

**Both generated Lua files have to be in your mod's `LoadScript` list, atlas first.** If the
atlas doesn't load it isn't an error. The table is just nil, the driver logs one line, and
every keypress does nothing. I shipped that once and it looked exactly like a dead feature.

---

## Step 1 — draw something

Write a scene file. Everything in it is in stage units on a 1280x720 stage. The builder
handles supersampling, so you never think about pixels.

`myscreen.json`:

```json
{
  "element": "MyScreen",
  "table": "MyScreenAtlas",
  "out": {
    "swf": "data/libs/UI/MyScreen.swf",
    "xml": "data/libs/UI/UIElements/MyScreen.xml",
    "lua": "data/Scripts/mods/myscreen_atlas.lua"
  },
  "palette": {
    "ink":   [238, 231, 216],
    "panel": [26, 21, 15],
    "rim":   [120, 92, 45]
  },
  "layout": { "panelX": 40, "panelY": 40, "titleX": 56, "titleY": 56 },
  "clips": [
    { "name": "panel", "kind": "rounded", "w": 300, "h": 150, "r": 7,
      "rgb": "panel", "alpha": 0.93, "edge": "rim", "edgeW": 1, "center": false },
    { "name": "title", "kind": "text", "text": "Supplies", "px": 19, "rgb": "ink",
      "center": false }
  ],
  "preview": [
    { "clip": "panel", "x": 40, "y": 40 },
    { "clip": "title", "x": 56, "y": 56 }
  ]
}
```

Build it:

```bash
python tools/kcdui build myscreen.json --preview out.png
```

You get the three files plus a PNG of exactly what the game will draw, composited over a
sky-and-ground gradient so you can see whether your text survives bright terrain.

That PNG is the whole tuning loop. Use it. Alt-tabbing into the game to check a number is how
an afternoon turns into a week.

The build also parses the SWF back and cross-checks it against the XML and the Lua, so it
tells you straight away if the three disagree about a single clip name.

### Clip kinds

| kind | what you get |
| --- | --- |
| `rounded` | rounded rectangle, optional edge. Panels. |
| `rect` | flat rectangle. Bars, rules, fills. |
| `disc` | circle, optional rim. Radial menu buttons. |
| `text` | a label in the game's typeface |
| `image` | a PNG off disk, optionally scaled and tinted |
| `bar` | a two-colour bar baked at one fill level |
| `vignette` | soft dark blob to sit a radial menu on |
| `states` | one clip with several looks, swapped from Lua |
| `digits` | a column of number glyphs (Step 5) |

---

## Step 2 — get it on screen

Copy `tools/kcdui/runtime/kcdui.lua` in next to your scripts and load it **before** your
driver. Then the smallest driver that works:

```lua
-- myscreen_ui.lua
local S = KCDUI.screen(MyScreenAtlas, "MyScreenDeferred")

MyScreenDeferred = function() S:layout() end    -- has to be a GLOBAL, see below

S.onLayout = function(s)
    local L = s.atlas.layout
    s:place("panel", L.panelX, L.panelY)
    s:place("title", L.titleX, L.titleY)
end

function mercenaries:MyScreenToggle()
    if S.up then S:hide() else S:show() end
end

mercenaries:PlayerCommand("merc_myscreen", "mercenaries:MyScreenToggle()", "Show/hide it")
```

Type `merc_myscreen` in the console and it should appear.

Two things in there will bite you if you change them.

**The defer function has to be a global.** `Script.SetTimerForFunction` takes a function
*name* as a string, not a function, so the screen can't register its own callback. That's why
`KCDUI.screen` asks you for a name.

**The first layout is deferred on purpose.** The movie only gets built on first display, and
anything you send in that same call addresses clips that don't exist yet. It doesn't error,
it just does nothing, and it looks exactly like a layout bug. `S:show()` handles the wait.

---

## Step 3 — move things around

`place` puts a clip where its **middle** should go, whatever its registration point is.

```lua
s:place(name, x, y, scale, scaleY, alpha)
```

`scale`, `scaleY` and `alpha` are optional. Alpha is 0..1 here even though the engine wants
percent, the runtime converts for you.

### Every frame, in this order

```lua
s:begin()          -- start the frame
s:place(...)       -- everything you want visible
s:sweep()          -- hides whatever was up last frame and isn't now
```

`S:layout()` does all three around your `onLayout`. Don't redraw everything unconditionally,
it costs more and it flickers.

### The anchor flag

In the scene file, `"center": false` registers a clip at its **top-left** instead of its
middle. Panels and labels usually want that, discs and badges usually don't.

The builder writes that flag into the atlas as `c` and `place` reads it, so you always
position by the middle and never think about it again. If you write your own builder and
forget to emit it, every uncentred clip sits half its own size down and to the right, and
you'll spend an hour convinced your maths is wrong. It isn't.

### Clips with several looks

Something with states is **one** clip, not three:

```json
{ "name": "state_dot", "kind": "states", "frames": [
    { "label": "ok",  "kind": "disc", "d": 10, "rgb": "good" },
    { "label": "low", "kind": "disc", "d": 10, "rgb": "gold" },
    { "label": "out", "kind": "disc", "d": 10, "rgb": "bad"  }
]}
```

```lua
s:state("state_dot", food > 0 and "ok" or "out")
```

Much better than three clips you have to remember to hide. Worth saying though: this writes
real `FrameLabel` tags and `UIAction.GotoAndStopFrameName` is in the retail Lua bridge, but I
haven't shipped a screen using it yet. It should work. Check it before you build something
big on top of it.

---

## Step 4 — use the game's own art

A mod UI in Segoe UI reads as a mod however good the layout is. Two things fix that, and both
come out of the game's own files.

### Typefaces

`"kind": "text"` already uses them. The faces are `body` (DefaultFont), `bold`
(DefaultFontBold), `display` and `light`. Pick one with `"face": "bold"`.

The one thing worth knowing: the outlines only exist in `gfxfontlib_glyphs.gfx`. The
obvious-looking `gfxfontlib.gfx` has them stripped out. That's a good hour lost if you find
that one first, which I did.

### Key caps and other borrowed art

Before you draw an imitation of a vanilla UI element, check whether it's already a texture.
Usually it is.

The key prompts, the `[E]` next to *Talk*, are `Textures/buttons/key.dds` plus a text field,
and both are readable. `Libs/UI/buttons.gfx` holds no embedded bitmaps at all, just external
references to loose `.dds` files, and the `DefineEditText` beside them carries the exact
typography: 30px on the 64px cap, pure black, centred. What size it's actually *drawn* at is a
separate question and lives in `hud.gfx`, which I got wrong twice before going and reading it.

Twenty minutes of parsing beat two rounds of eyeballing. Full recipe with all the numbers in
[ui.md](ui.md#key-caps-and-other-borrowed-ui-art).

---

## Step 5 — numbers

This one is unintuitive and it cost me a debugging round, so read it before you put a number
anywhere.

A MovieClip instance can only be in one place at a time. Build `500` out of a shared set of
ten digit clips and you're asking the single `0` instance to be in two places, so only the
last one shows. Every figure that can be on screen next to another one needs its own column of
instances, one per character **position**:

```
n_<field>_<pos>_<glyph>
```

The scene file does it for you:

```json
{ "digits": "purse", "width": 8, "glyphs": "0123456789,", "px": 13, "rgb": "ink" }
```

```lua
s:digits("purse", "2,000", L.valueX, L.rowY, 1.0, nil, "right")
```

Three rules:

- **Include every separator the field can ever print.** `/`, `%`, `+`, `-`, a comma, a space.
  A character with no clip is silently skipped, which is how `2 / 6` once came out as `2 6`.
- **`width` is the longest string you'll ever draw**, not the digits in the current value.
- **Let the builder make the glyphs.** It renders the whole set against one shared baseline.
  Make them yourself and crop each glyph to its own ink, and a comma ends up floating where an
  apostrophe goes, so `2,000` prints as `2'000`. That was in my camp screen for a whole
  release before I spotted it.

---

## Step 6 — input

This took more attempts than everything else in the pipeline combined. Budget more time for it
than for the art, and go in this order.

### 1. Borrow keys that already work

If you already have one screen with working keys, have the second one hold the first's binds
and forward into it. That's what my camp screen does, it binds nothing of its own. Those keys
are proven to fire and they bring the quick-slot filter below with them.

### 2. Console binds

```lua
System.ExecuteCommand("bind 5 merc_myscreen_k1")
```

These work for the command interface. They did **not** work for the camp screen and I never
found out why. The bind went out, the command existed, running it by hand worked, and the key
did nothing. If you bind your own, write a self-test that calls the command through the
console, so you can tell "the bind never fired" apart from "the command is broken".

Whatever you bind to has to be a `PlayerCommand`. A `DevCommand` needs `merc_dev` typed first
and your screen will just sit there doing nothing.

### 3. `Player.OnAction`

Chain it, don't replace it. Two traps:

- The activation word is **`"press"`**, not `"onPress"`. Get that wrong and the action
  arrives, your handler eats it, and nothing happens.
- **Consuming an action in Lua does not stop the engine acting on it.** Returning `true` only
  skips the rest of the Lua chain.

### The number row draws your weapon

Keys 1-4 are `action_qam_1..4`, the quick slots. The only thing that stops the draw is the
vanilla `no_qam_weapons` action filter, which blocks exactly the actions you need to receive.
You can't have both through `OnAction`.

The way out is to take the keys by console bind, which the filter doesn't touch, and hold the
filter at the same time. Lua can't enable a filter directly, so I do it with a weightless
marker item and a Skald `FilterInput` node. Hold `mercenaries.BL.qamToken` while your screen
is up, release it after.

**Clear that token unconditionally at gameplay start.** If the game crashes with your screen
open, the player reloads unable to draw a weapon and has no idea why.

One more: the engine only delivers the number row as `action_qam_1..8`. **9 and 0 have no
action at all**, only the disabled `haste` cheat map, so a row wider than eight can't be
driven that way.

---

## Step 7 — tell the player it exists

A screen nobody can find is a screen nobody uses. Put a prompt in a corner saying which key
opens it, styled like the game's own `Talk [E]`: label on the left, key cap on the right, the
column anchored on its right edge so the caps line up whatever the words do.

```lua
s:nudge(L, "topright", L.hintRowDY, "hint_btn_H", "hint_lbl", L.hintGap)
```

Three things I'd do differently if I were starting again:

- **Don't put it in the bottom right.** That's where the game draws its own pickup and
  objective messages and its interaction prompts. Mine sat there for a release and the first
  thing players asked for was a way to move it.
- **Make where it sits a setting, and save it.** It's cheap and it ends the argument.
  `mercenaries:HintsSet` and `HintsPos` own both of my screens' prompts.
- **Give a route that isn't the console.** Most players never open it. The quartermaster's
  `[Mod settings]` menu takes a marker item whose *count* carries the choice, so one new item
  and one dialog hub buys a whole submenu.

If your screen's own panels cover the corner the player picked, move the Close prompt while
the screen is open rather than drawing on top of your panel. And put the anchors in the atlas,
not the driver, so two screens sharing a column can't drift apart when you rebuild one.

---

## Step 8 — check it before you launch the game

```bash
python tools/kcdui check MyScreen.swf --xml MyScreen.xml --lua myscreen_atlas.lua
```

That parses the SWF back and makes all three files agree on every clip name. `build` runs it
for you automatically.

For a real screen, copy `tools/check_campui.py` and adapt it. Every check in there exists
because that failure reached the game silently, and I proved each one by deliberately putting
the bug back:

| check | catches |
| --- | --- |
| clip names | every name the driver can build exists in the atlas **and** the XML |
| Lua parse | a broken edit. The other checks read the file as text and sail right past it |
| scope order | a local used above its declaration, which resolves to a nil global |
| functions exist | `self:Foo()` **and** `mercenaries:Foo()`, the second hides inside `pcall` |
| `PlayerCommand` | a `DevCommand` bound to a key, so the screen does nothing |
| activation words | `"onPress"` instead of `"press"` |
| boot list | both scripts loaded, atlas before driver |
| ghost meshes | every `.cgf` path exists in the paks. Three of my first six didn't |
| message keys | every `SendInfoText` key has a localisation row |

A green checker is not a working screen. It can't see a clip placed at the wrong coordinates,
that's what the preview PNG is for. What it does catch is the whole class of failures that
produce no error at all, which is most of them.

---

# Reference

The rest is stuff you'll want when you hit it, not on your first screen.

## Aim-and-click placement

`StartPlacement(spec)` in `mercenaries_tower.lua` does the ghost, the raycast, the validity
recolour and the mouse handling. A spec needs:

- `parts` — each one **must** carry `x`, `y`, `z`. They go into `HouseLocalToWorld`, and a nil
  throws inside `PlaceTick`'s `pcall`, so the ghost silently never leaves its parking spot
  50 m under the world. That one took me a while.
- `sink` — same thing, also arithmetic, also swallowed.
- `isValid` — think about which test you want. `TowerSpotIsValid` refuses anything near a camp
  prop, which is right for a watchtower and wrong for anything meant to go *inside* a camp.
- `validMaterial` — leave it nil for a multi-submaterial mesh. A single-submaterial `.mtl`
  maps onto slot 0 only and every other submesh stops drawing.

**A wall is not a placement.** `StartWallBuild` is a build *mode* and leaves `ActivePlacement`
nil the whole time, so anything asking "is a placement running?" has to test `WallBuildActive`
as well.

While the player is aiming, suppress your screen explicitly. Hiding it once isn't enough,
because other screens put themselves back up off their own prompt updates. Set a flag, have
the layout draw nothing while it's set, and clear it on confirm, on cancel, and from a capped
watchdog for placements that end through code that never calls you back.

## Messages

Anything you show with `Game.SendInfoText` needs a row in **all 16** `localization/*_xml.xml`
files. A key with no row prints the raw key on screen and warns you nowhere.

Don't borrow another system's keys because they're nearby. Moving a smithy once announced
*"Look where you want the tower and click"*, and taking one down said *"The quartermaster sets
to work on the improvement"*.

Splice rows in with a regex against `</Table>`. `ElementTree.write` drops the comments those
files carry, which is what wiped my localisation once already.

## Timers and saves

Pending `Script.SetTimerForFunction` timers get **serialised into the save**. A chain that
re-arms forever is a save-bloat bug waiting to happen, and one I've already shipped once.

Two rules: cap every watchdog, and reset the state it watches at gameplay start. I had a
placement watchdog that put the camp screen back up when a placement ended. Save while aiming,
reload, and the timer fired against a placement that no longer existed, so the screen opened
by itself a few seconds into every load.

## Things this pipeline can't do

Worth knowing before you plan around them:

- **No mouse, no buttons, no hit testing.** These movies contain no ActionScript, so nothing
  clicks. If all you want is a list of buttons, drive the vanilla `Menu` element instead, it
  already has the code for it. The KCD2 Companion mod does exactly that and it's far less
  work than this.
- **No vector shapes, no text fields, no masks.** Everything is a bitmap.
- **The driver is still yours.** This is the big one. Layout is maybe a tenth of a screen. My
  two drivers are about 1,000 and 1,400 lines and almost none of that is positioning things.
  Nothing here writes it for you.
