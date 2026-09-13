# kcdui

Build custom Scaleform UI for **Kingdom Come: Deliverance II** from Python, with no
Scaleform licence, no authoring tool and no ActionScript.

```bash
python tools/kcdui build tools/kcdui/examples/supplies.json --preview out.png
```

```
MercSupplies  155 clips, 44 unique images
  swf out/MercSupplies.swf  (78042 bytes)
  xml out/MercSupplies.xml  (155 clips)
  lua out/mercsupplies_atlas.lua  (155 clips)
  ok: the SWF, the XML and the Lua all name the same 155 clips
```

That is a working screen: art in the game's own typeface, a multi-state clip, number
columns, a corner key prompt, and a PNG of exactly what the game will draw.

---

## Why this exists

KCD2 will load a plain uncompressed `.swf` in place of a Scaleform-compiled `.gfx` when
`wh_gfx_useSWF` is set, and `UIAction` — the Lua bridge — is live in retail. So custom UI is
possible. It is just that every single step of it fails **silently**: no error, no log line,
no missing-texture marker. A clip in the wrong place, a clip that does not exist, a keypress
that never arrives and a screen that draws nothing all look identical from the outside.

This package is the parts that are the same for every screen. It is **not** a UI framework
and it will not write your screen for you — see "What this does not do" at the bottom, which
is the honest half of the pitch.

## Install

Copy `tools/kcdui/` into your project. It needs Python 3.8+ and Pillow. Copy
`runtime/kcdui.lua` in beside your mod's scripts and `LoadScript` it before any screen.

For the game's own typefaces it also wants `tools/kcd_font.py` next to the package and the
game installed; without those, text falls back to a system font with a warning. Check with:

```bash
python tools/kcdui fonts
```

## The shape of a screen

Four pieces, three of them generated:

| | what | from |
| --- | --- | --- |
| `Libs/UI/<Element>.swf` | the art, one MovieClip per thing that can move | `kcdui` |
| `Libs/UI/UIElements/<Element>.xml` | declares those clips to the engine | `kcdui` |
| `Scripts/mods/<x>_atlas.lua` | clip sizes, layout constants, content tables | `kcdui` |
| `Scripts/mods/<x>_ui.lua` | the driver: state, layout, input | **you** |

The atlas is what stops the art and the code drifting apart. The driver never hard-codes a
size, a position or a list of items; it reads them from the generated table. Skip that and
the first rebuild scatters your screen.

**Both generated Lua files must be in your mod's `LoadScript` list, atlas first.** An
unloaded atlas is not an error — the table is simply nil, and every keypress silently does
nothing. That shipped once and looked exactly like a dead feature.

## Two names, and the mistake everyone makes first

`Atlas.clip(name, key, img, center)`:

- **`name` is the INSTANCE** — what `UIAction.SetPos` can move, and what your driver
  addresses. Two places showing the same picture are **two instances**.
- **`key` is the IMAGE**, shared freely between instances.

Address an image name and you get nothing on screen, with no complaint.

**`center`** decides where the clip registers: `True` at its middle, `False` at its
top-left. The flag is emitted into the Lua as `c` and `Screen:place` converts, so a driver
can always say where the *middle* goes. Get it wrong and every uncentred clip sits half its
own size down and to the right, which reads as a layout bug and is not one.

## Numbers need one instance per character POSITION

An instance can only be in one place at a time, so a figure built from a shared set of ten
digit clips asks the single `0` instance to be in two places when it draws `500`. Every
figure that can be on screen beside another one gets its own column:

    n_<field>_<pos>_<glyph>

`Atlas.digits()` builds them and `Screen:digits()` walks them. Include **every separator the
field can ever print** — `/`, `%`, `+`, `-`, `,`, a space. A character with no clip is
silently skipped, which is how `2 / 6` once rendered as `2 6`.

Build the glyphs with `art.glyph_set()`, not one `art.text()` call each. Cropping every
glyph to its own ink and then centring them all — the obvious thing to do — throws away the
baseline, and a comma ends up floating where an apostrophe goes:

![2'000 versus 2,000](../out/comma_baseline.png)

That is not hypothetical. It shipped in this repo's own camp screen, in the war chest and
every price, until this package was written and the comparison above was rendered.

## Text

- **Pad by a constant in stage units**, never by a fraction of the size. Padding by
  `px // 4` put a 9px label and a 19px title on rails 2.7 units apart and nothing in a
  column lined up.
- **Crop standalone labels to their ink**; advancing by a padded clip width puts six units
  of air between every character.
- Set type in the game's own faces. A mod UI in Segoe reads as a mod however good the
  layout is.

## Driving it from Lua

```lua
local S = KCDUI.screen(MyScreenAtlas, "MyScreenDeferred")
MyScreenDeferred = function() S:layout() end     -- a GLOBAL: the timer takes a NAME

S.onLayout = function(s)
    local L = s.atlas.layout
    s:place("panel", L.panelX, L.panelY)
    s:digits("food", tostring(food), L.valueX, L.rowY0, 1.0, nil, "right")
    s:state("state_dot", food > 0 and "ok" or "out")
end

S:show()        -- element up, first layout deferred
S:hide()
```

- `SetScale` and `SetAlpha` are **percent**, and the atlas bakes a `1/ss` shrink into every
  clip's authored matrix; a scale call must re-apply it or the clip jumps to `ss` times its
  size. `Screen:place` does this for you.
- **Defer the first layout.** The movie is built on first display; transforms sent in the
  same call address clips that do not exist yet and silently no-op. `Screen:show` handles it,
  which is why it needs the name of a global function — `Script.SetTimerForFunction` takes a
  function *name*, not a function.
- **Diff frames.** `begin()` … `place()` … `sweep()` hides whatever was up last frame and is
  not up this one. Redrawing everything every frame both costs more and flickers.

## Input is the hard part

This took more attempts than everything else combined, and `kcdui` does **not** solve it —
it is per-mod. In order of what is known to work:

1. **Borrow keys that already work.** If you already have one screen with working keys, have
   the second one hold the first's binds and forward. Proven, and it inherits the quick-slot
   filter below.
2. **Console binds** (`System.ExecuteCommand("bind 5 mycmd")`). These work for some screens
   and, in one case in this repo, did not work for another and was never explained — the bind
   went out, the command existed and ran when called directly, and the key did nothing. If
   you bind your own, prove it with a self-test that calls the command through the console.
3. **`Player.OnAction`.** Two traps: the activation word is **`"press"`**, not `"onPress"`;
   and **consuming an action in Lua does not stop the engine acting on it** — returning true
   only skips the rest of the Lua chain.

### The number row draws weapons

Keys 1-4 are `action_qam_1..4`, and the only thing that stops the draw is the vanilla
`no_qam_weapons` action filter — which blocks the same action you need to receive. You cannot
have both through `OnAction`. Take the keys by console bind, which the filter does not touch,
and hold the filter at the same time. Lua cannot enable a filter directly; drive it with a
weightless marker item and a Skald `FilterInput` node, and clear it unconditionally at
gameplay start or a crash leaves the player unable to draw a weapon.

The engine only delivers the number row as `action_qam_1..8` — **9 and 0 have no action at
all**, so a row wider than eight cannot be driven that way.

## Put the key prompt somewhere the game does not write

A screen nobody can find is a screen nobody uses, so put a prompt in a corner saying which
key opens it — and make **where** a player setting from the start. The bottom right is where
KCD2 draws its own pickup and objective messages *and* its interaction prompts; a prompt
parked on top of those is the first complaint you will get.

Lay it out the way the game lays out its own: **the word first, the key cap second**, the row
anchored on its **right edge** so the caps line up in a straight column whatever the words
do. `KCDUI.cornerXY` and `Screen:nudge` take the anchors from your atlas, so two screens'
prompts stack as one column in any corner. The key letter belongs baked into the cap art —
the key a screen opens on is fixed at build time, so there is nothing to compose at runtime
and a separate letter clip is one more thing to position wrongly.

Better still, borrow the cap itself: `Textures/buttons/key.dds` is the game's own, and
`buttons.gfx` carries the exact type size and colour that goes on it.

## Check it

`python tools/kcdui check <file.swf> --xml <file.xml> --lua <atlas.lua>` parses the SWF back
and cross-checks all three. `build` runs it automatically. It catches the whole class of
failures that produce no error at all: a clip in the Lua that is not in the SWF, a clip in
the SWF that the XML never declared, a duplicate instance name.

It cannot see a clip placed at the wrong coordinates. That is what `--preview` is for.

## What this does not do

Worth being blunt, because it is most of the work:

- **It does not write your driver.** The Lua that decides what to show, when, and what each
  key does is where a screen actually lives. The two screens in this repo are 1,000 and
  1,400 lines and almost none of it is layout.
- **It does not solve input.** See above. Budget more time for this than for the art.
- **No mouse, no buttons, no hit testing.** These movies contain no ActionScript, so nothing
  clicks. Mouse-driven UI means either AS2 bytecode in the SWF (not implemented here) or
  reusing a vanilla element that already has it — the "KCD2 Companion" mod drives the
  vanilla `Menu` element that way, which is a completely different and much cheaper approach
  if a list of buttons is all you need.
- **No vector shapes, no text fields, no masks.** Everything is a bitmap. `DefineEditText`
  would make live text possible without digit columns and is the obvious next thing to try,
  but it is untested against Scaleform here — do not plan around it until someone has.
- **Multi-frame clips are emitted but unproven in game.** `Atlas.states` writes real
  `FrameLabel` tags and `UIAction.GotoAndStopFrameName` is in the retail Lua bridge, so it
  should work. It has not been run in the game yet. Treat it as promising, not as done.

## Credits and licence

Extracted from the Mercenaries mod for KCD2. The SWF writer, the font extraction and every
trap above were paid for in failed attempts; take them and do something better with them.

Use it for anything. No warranty — it writes binary files for a game engine with no error
reporting, and you should check what comes out.
