# The command interface

A Bannerlord-style battle order UI drawn with real Scaleform clips: squad cards down the
left edge, a row of order buttons above the health vignette, and a radial submenu that pops
up above whichever button owns it.

Geometry and palette are measured off the screenshots in `references/bannerlord ui`, not
guessed. For how custom Scaleform gets into KCD2 at all, see [ui.md](ui.md).

## Using it

**No `merc_dev` needed.** The interface registers its own commands through
`mercenaries:PlayerCommand`, which calls `AddCCommand` straight away, rather than
`DevCommand`, which only *collects* a command until someone types `merc_dev`. A key bound to a
command the console does not know does nothing at all and says nothing about why, so the whole
interface silently failed for anyone who had not run `merc_dev` first. `check_blui.py` asserts
every key-bound command is registered unconditionally.

Only the two pure diagnostics - `merc_bl_filter` and `merc_bl_demo` - are still behind
`merc_dev`.

```
merc_bl_keys     bind the keys and show the interface
merc_bl          show / hide
merc_bl_off      hide it and release the keys
merc_bl_slowmo   time scale while it is up: <0.05-1.0>, 1 = off
merc_bl_modal    toggle modal input (ON by default): suppress the base player map
merc_bl_hint     toggle just this screen's nudge
merc_hints       both screens' corner nudges: <on|off>, blank toggles
merc_hints_pos   move them: <compass|topright|topleft|bottomright|bottomleft> or <x> <y>
merc_bl_demo     cycle the placeholder squad roster, to exercise the card states
```

| Key | Row (no wheel open) | Wheel open |
|---|---|---|
| 5 6 7 8 9 0 | Movement, Formation, Toggle, Weapons, Clothing, To Camp | pick order 1-6 |
| H | show / hide | back out of the wheel |

```
  5 6 7 8 9 0   orders        H  open / close / back
```

The interface is **on from the start** - it re-arms itself on every gameplay start, so
`merc_bl_keys` is not needed. Closing it with `H` latches until the next load.

`H` is the open / close / back key, so the wheel's Return slot badges as `H`.

Six keys is the hard ceiling on a wheel: **no wheel may hold more than six orders plus
Return**, because that is how many order keys exist. `check_blui.py` asserts it.

It also asserts that **every Toggle-wheel slot has a branch in `BLToggleApply`** - the wheel is
data and the handler is code, so adding a toggle without wiring it leaves a button that cycles
its own icon and changes nothing.

And that **every `mercenaries:BLxxx` the driver dispatches to is actually
defined**. The driver calls handlers behind `if mercenaries.BLFoo then ... end` guards, so a
handler lost to a bad edit does not error - the button just quietly stops doing anything,
which reads as a behaviour bug and is not one. That is exactly how the formation wheel came to
do nothing: `BLFormation` had been deleted by an unrelated edit and nothing said so.

### Why these keys

The company fields at most four squads, so squad picking never needed a row of its own - it
became a wheel, and the whole order row fits in **5-0**. One contiguous run, right where the
left hand already sits, and no F-keys.

What the game does with them:

| Keys | Bound to |
|---|---|
| 9, 0 | the `haste` cheat map only - free outright |
| 5, 6, 7, 8 | `qam_5`..`qam_8`, which have no field action |
| **1, 2, 3, 4** | `qam_1`..`qam_4` - these **draw the weapon in that quick slot**. Unusable. |
| H | nothing, ever |

Squad selection originally sat on 1-4 and had to move: pressing `1` unsheathes the sword.
It lives in its own wheel now, which costs no keys at all.

`H` matters more than it looks: the interface is on permanently, so it holds its keys
permanently, and `H` is the only one held even while the interface is **hidden**. It has to be
a key KCD2 never wants. Only **H, U, Y and O** qualify.

An earlier attempt put the order slots on `T U I O P J`. It failed: **I, P and J open the
inventory, player and questlog screens right over the interface**, and the only map that could
stop that is `player` - which owns the camera, so suppressing it costs mouse look.

**ESC is deliberately not taken** for the same reason: a console bind on it closes the
interface but the pause menu still opens underneath.

**Y and Z are avoided.** Engine key names are US scancodes, so engine `y` is the top-row key a
German keyboard prints as **Z** and engine `z` is the bottom-left key it prints as **Y**;
whichever badge we drew would be wrong on one layout.

To rebind, edit `BIND` in `tools/make_bl.py` and rebuild; the driver reads the binding out of
the generated table, so the badge on a button is always the key that fires it.

## The idle hint

### The marker

One flag **per squad**, since several can be under ground orders at once; index 0 is the
preview that tracks the crosshair before an order is confirmed. A squad's flag is cleared when
it arrives or when its order changes, so markers do not pile up on the field.

The check runs on **its own one-second chain**, not on the squad tick. That rides
`LogiUpdateStatusBuffs`, which runs on the logistics cadence - far too slow for a marker, and
a flag left standing for minutes after the men arrive reads as the order never having
finished. The chain only runs while a flag exists, and gives up after five minutes: a timer
chain left in flight gets serialised into saves, which is how this mod once shipped a save
carrying thousands of pending timers.

A small chip-and-label nudge sits in a screen corner in both states, saying what `H` does
now: **`[H] Command`** while the interface is closed and **`[H] Close`** while it is open.
It is **not** gated on having men - it is how you find the interface at all, and gating it
made it vanish between hirings, after losses and on a fresh save.

It rides `LogiUpdateStatusBuffs` rather than a timer of its own - that already runs on every
squad-state change, and a repeating timer would be serialized into saves (see
[performance.md](performance.md)).

The Scaleform element is shared: it stays up whenever either the interface or the nudge wants
to draw, and is torn down only when neither does.

### Where it sits, and turning it off

The camp screen draws its own nudge directly above this one, so the two are one column. Where
that column goes is a **player setting**, shared by both screens and saved with the game -
it shipped in the bottom right, which is where KCD2 puts its own pickup and objective
messages, and players were losing game text behind it.

    merc_hints on|off
    merc_hints_pos compass | topright | topleft | bottomright | bottomleft
    merc_hints_pos <x> <y>          anywhere, in stage units on the 1280x720 stage

The default is **`topright`**, right edge at x=1262.

It is laid out like KCD2's own action hint and built from the same art: the **word first,
the cap second**, the column anchored on its **right edge** so the caps line up in a
straight column whatever the words do.

Every number in it is read out of the game rather than matched by eye - see
[ui.md](ui.md#key-caps-and-other-borrowed-ui-art). In short: `hud.gfx` is a 1920x1080 stage
and places the button movie at scale 0.5, so a 64px cap draws 32px there, which is 21.33 of
our units - **exactly its 64 authored pixels at ss=3, so the texture is never resampled**.
The label beside it is `DefaultFont` at 22px in that stage, pure white, which is 14.67 of
ours - and the *regular* face, not the bold one the rest of this UI uses.

One thing that cannot be matched: on a display wider than 16:9 the Scaleform stage is
letterboxed while vanilla's HUD is not, so vanilla's own prompt column sits a little further
out than anything we can draw. `merc_hints_pos <x> <y>` is the escape hatch.

### Only the camp screen's Close prompt moves

This screen's prompts **stay where the player put them** when it opens: the cards are down
the left edge and the button row is at the bottom, so the chosen corner is still free, and a
prompt that jumps for no visible reason is worse than one that sits still.

The camp screen is the one that has to dodge - both of its modes fill the top right from
y=20 down, so the chosen corner would put Close half on top of the logistics panel. It moves
to **beside the compass**, right edge x=865, y=32, so the row spans 795..865. That gap is
free: the compass bar ends at x=749 and the camp's own panels leave 326..954 empty. The
command interface's prompt is suppressed entirely while the camp screen is up, so only one
prompt is ever there.

`mercenaries:HintOpenXY` owns that position. `hintRowDY` is ignored in it on purpose: with
only one prompt on screen there is no column for it to be the second row of.

Also in the quartermaster's dialogue under **[Mod settings]**, which is where most players
will find it; that route is a marker item whose count carries the choice, exactly like the
HUD-icons setting (see [quartermaster.md](quartermaster.md)).

The four corner anchors live in **both atlases** (`hintLeftX`, `hintRightX`, `hintTopY`,
`hintBottomY`), and each screen's `hintRowDY` says which row of the column it is - camp 0,
command 26. Keeping the anchors in the atlas rather than the driver is what stops the two
nudges drifting apart when one screen is rebuilt and the other is not;
`tools/check_campui.py` fails if either atlas loses an anchor or the two claim the same row.

Turning them off hides the **idle** nudge only. While a screen is actually open its corner
still says what `H` or `U` closes it, because at that point the screen is already covering
the view and there is no other on-screen way out.

The left-hand corners put the nudge over the command interface's squad cards and the camp
screen's header while those screens are open. That is the player's choice to make, but it is
why the right-hand corners are the two offered in the quartermaster's menu.

## Taking keys the game already owns

KCD2's gameplay keys are **not** console binds. They are CryEngine action maps, declared in
`Libs/Config/defaultProfile.xml` with a priority tier and an `exclusivity` flag, and resolved
to physical keys through `Libs/Config/keybindSuperactions.xml`.

| Key | Superaction | Fires |
|---|---|---|
| `1`-`8`, `np_1`-`np_8` | `qam_1`..`qam_8` | `action_qam_N` in map `qam_init` **and** `weapon_slot_N` / `food_slot_N` in map `apse_qam_slots` - measured not to fire bare in the field |
| `escape`, `backspace` | `back` | `open_menu`, `open_pause_menu`, and a dozen context-specific closers |

`ActionMapManager.EnableActionMap` is a confirmed-live retail script bind, so the interface
disables the maps that own the competing actions for as long as it is up. `BL.suppress` holds
them - though in practice only one map matters, for the reason below. **Leaking that state is the serious failure mode**, so they are re-enabled on hide and
unconditionally on every `OnGameplayStarted`.

Action *filters* would have been tidier but are query-only: the string `EnableActionFilter`
does not appear anywhere in WHGame.dll, even though Warhorse's own C++ header documents it.

### Measured: `pure_include` maps cannot be suppressed

`EnableActionMap` does nothing to a map whose priority is `pure_include`. The name is
literal - those maps exist only to be `<include>`d into others and are never enabled as
units. Confirmed three times in game: suppressing `open_menu` / `open_pause_menu` did not
stop ESC, and suppressing `open_apse_keyboard` did not stop `I` and `P` opening the
inventory and player screens.

Every one of them chains upward into **`player`** (priority `default`), which is therefore
the only enable-able map that actually owns those keys:

```
open_apse_keyboard -> open_apse -> open_ui -> player
qam_init           -> interaction          -> player
```

### Modal mode - off by default

Suppressing **`player`** does work, and it takes ESC's pause menu and the quick-access number
row with it in one move. But `player` also owns the camera, so it takes **mouse look** with
it, which is why it is off by default and why the order keys have to be keys the game does
not want in the first place.

`merc_bl_modal` turns it on if you want the fully modal feel.

`BL.modalMaps` holds it, and like the time scale it is restored on hide and unconditionally
on every `OnGameplayStarted` - leaking a disabled `player` map would leave the player unable
to move.

## Squads

The mod has always fielded one blob - `ActiveMercs` with a single formation leader. Squads sit
on top of that in `mercenaries_squads.lua` without replacing it: a squad is a set of WUIDs, and
an order issued to a squad binds exactly those men.

Squads have **fixed roles**: 1 and 2 are melee, 3 and 4 are archers. A man is only ever dealt
into a squad of his own kind and is moved out if he ends up in the wrong one, so a company with
no archers fields two empty archer cards rather than diluting the melee line - and the player
always knows which card is which. Within a role, men go to the thinner of the two squads, so
the pair stays even.

The deal is **stable**: men are sorted by WUID and keep their squad across re-deals, so a
casualty does not reshuffle the whole company and make the cards jump. Re-dealt on the same
squad-state tick the interface's idle hint rides.

```
merc_squads          print the division
merc_squads_rebuild  re-deal from scratch
```

The cards read off this - troop glyph from the squad's role, count from the living, health
from the mean, order from `SquadOrder[i]`.

## Orders

`mercenaries_blorders.lua` translates interface state into behaviour. Almost none of it is new:
the mod already knows how to hold ground, follow, form up and pick an engagement stance.

| Order | What it does |
|---|---|
| Move to Position | enters placement mode - see below |
| Follow Me | `HoldEnd` - back to following |
| Stop | `HoldBegin()` with no anchor, which is stand-fast on the ground each man is already on |
| Charge | **kill everything in sight** for 30s, and see much further - below |
| Retreat | move away from the fight and stand - see below |
| Formation | `SetFormationShape`, which resolves the preset name on the spot |
| Fire at Will / Holding Fire | `SetArcherStance` skirmish / hold |
| (the wheel is addressed by SLOT) | a toggle entry's action is its **slot** - `fire`, `mount`, `engage`, `swarm` - never the state it is currently showing |
| Mounted / Dismounted | `HorsesSet` |
| Engagement | `SetEngageStance` - mirrors `EngageOrder` |
| Swarm | `SetAggroPreset` - mirrors `AggroOrder` |
| Weapons | `EquipMercenaryWeapon` per man, over the selected squads |
| Clothing | `EquipMercenary` per man, over the selected squads |
| To Camp | see below |

Orders bind the **selected** squads (1-4). With nothing selected they go to the whole company,
which is what a player who never touched the number row expects.

### Charge

Two halves. `SetEngageStance("viking", true)` is the *acceptance* half - it is
`EngageOrder`'s top rung, and it **does not care who anybody is**. A charge ordered
within `BLChargeRadius` (140m) of a village is an order to sack the village; `BLCharge`
raises the same `VikingWarn` that picking the stance by hand does. The *seeing* half is the scan radius: `mercenaries_perf.lua` picks it as
"alerted and `EnemyAlertRadius`, or `EnemyScanRadius`" (60m vs 18m), so a charge forces the
alert on and raises the radius to `BLChargeRadius` (140m) for `BLChargeSecs` (30s).

The alert's own clock is `_alertAt` + `EnemyAlertHoldSecs`, stamped on contact - a charge
stamps it too, so the ordinary decay cannot close the alert mid-advance. The radius is put
back to `EnemyAlertRadiusDefault` on a generation-guarded timer: a 140m query left running is
the expensive one.

**Both halves are temporary, and the stance half did not used to be.** The timer restored
the radius alone, so one charge left the company on "attack on sight" for the rest of the
session — and `SetEngageStance` persists the stance, so across saves too. The player
charged a camp, won, rode into town, and had no idea his standing order had changed. The
timer now puts the stance back as well, and only if the charge's own `viking` is still
the one in force (a stance the player picked himself mid-charge means that and is not
overruled 30s later). The charge's stance change is `transient` — it is deliberately not
written to the save, because `SetTimerForFunction` timers **do not survive a save load**
while a saved string does, so a save taken mid-charge used to come back on `viking` with no
timer left to put it right.

### Retreat

The squad runs from nearby men who are **not on our side and actually fighting**
(`soul:IsInCombatDanger`), to `EnemyAlertRadius + 20 m` away. The combat test matters: without
it a squad "retreats" from a passing villager and just wanders off.

With nothing fighting them there is nothing to run from and no direction to run in, so they
rally on the player instead of marching 80m into empty country.

Note `PerfNpcsNear`'s third argument is the cache's **max age in milliseconds**, not a count,
and it returns nil when the cached sweep does not cover the ground being asked about - so the
scan falls back to `GetPhysicalEntitiesInBoxByClass`. Getting that wrong finds zero hostiles
every time and the retreat picks an arbitrary direction.

Arriving **is** the wait: the retreat is a ground order, and a ground order stands them there
until they are told otherwise.

And they **stay** there. The hold leash decides how far from his station a man will claim a
target, and the ordinary 30m had a retreated squad claim something the moment it arrived and
walk straight back into the fight it was pulled out of. A retreat sets a per-man override
(`HoldSetLeash`, `BLRetreatLeash` = 5m), so they only fight what comes within arm's reach.
The override is cleared by any order that ends the retreat, and by a plain move order, which
is not a retreat and should not inherit its caution.

Fallback is gone - Retreat covers it.

### Placing a move order

Picking **Move to Position** enters placement mode: a flag
(`common_decorations/flags/flag_spear.cgf`) tracks the ground under your crosshair, **left
click** sets it and issues the order, `H` cancels. The ray is cast from the *view* camera, so
it follows the crosshair in both first and third person.

Left click has to plant the flag without also swinging, so placement mode enables the game's
`no_attack` filter - the same marker-item + `FilterInput` route as the quick-slot block, with
its own token. Placement mode is cleared unconditionally on load: waking up inside it after a
crash would leave the player unable to attack.

The order itself is a **hold with a chosen anchor**. `HoldBegin(pos, facing)` already walks
every man to a station around a point and keeps him there; `HoldFormUp` is forced on so they draw up in line at the
marker rather than standing where they stopped.

The member set is passed **into** `HoldBegin(pos, facing, members)` rather than applied after
it. `HoldBegin` used to fill `HoldMembers` with the whole company and station them immediately,
so narrowing the set afterwards left every unselected man already walking - the whole company
moved on an order given to one squad.

### Moving during a fight

A plain ground order waits for combat to end. The scheduler's nav arm is gated on `~$inCombat`
and fires at priority **150**, under the attack interrupt's **160** - so a man told to move
mid-fight finishes the fight first, which is not what an order to move means.

A forced order gets its own arm at **170**. `mercenaries_scheduler.xml` now carries a second
`IfCondition` beside the original, on `$navOrderGo & $navOrderForce & $inCombat`, firing
`nav_goto` above the attack interrupt. The original arm is untouched, so anything that is not a
forced order behaves exactly as before.

Two things have to be true together or it stalls a metre later:

- **`navOrderForce`** is set per man (`MarchForce`) by a move or retreat order, so the
  interrupt outranks the fight.
- **Combat claims are refused** while he is marching, in `TryClaimTarget` - the single choke
  point every claim goes through. Without this he re-acquires on the way and stops again.

Existing claims are dropped when the order is given (`ClearCombatClaim`), and the flag is
cleared **the moment he stands on his mark** - inside `HoldPoll`, which already does that
distance check, rather than on the slow squad tick. He fights again from there.

### Grouping

Squads given the same order share an anchor and a formation. **Several ground orders can be
live at once**: `HoldAddGroup(members, pos, facing)` merges a group into the running hold
rather than restarting it, and `HoldDropGroup(members)` takes one out without ending the order
for the others.

The squad-wide formation stand-down now only fires when the order binds **everyone**
(`HoldIsPartial`). It used to trigger on any hold at all, which dropped the entire company onto
the plain follow chain the moment one squad was sent somewhere - and made formation changes
look like they did nothing, because there was no formation left to change.

A man on a hold station is also taken **out of the follow slot chain**
(`IsFormationEligible`). The chain has each man follow the one ahead of him, so leaving a
held man in it made everyone behind him trail off to the station - order one squad to move
and the rest walked over and stood with them. He rejoins when the order is lifted.

That distinction matters because `HoldBegin` wipes `HoldStations` wholesale - a second move
order used to drop the first squad straight back to following. Stations were always per-man,
so the only thing the group layer adds is *which anchor a man's station is measured from*, and
merging instead of replacing.

### What the card glyph says

The little glyph under each card is the squad's live state, not the last order given:

| Glyph | Meaning |
|---|---|
| charge | someone in the squad is in combat (`soul:IsInCombatDanger`) |
| tent | quartered in camp |
| move to position | under a ground order and not there yet |
| stop | standing - arrived, or told to stop |
| follow | following the player |

Combat is tested first: a squad fighting *in* camp is fighting, and that is what the player
needs to see. "In camp" is half or more of the squad passing `IsMercInCampProper`, which means
the camp is standing and the man is not in the out-party.

"Arrived" is 70% of the squad standing on its station, which keeps the glyph from flickering
while the back rank catches up.

### Casualties on the health bar

The bar's full width is the squad's strength **before** the fight, so the dark band on the
right is the men it has cost. `SquadDeaths[i]` counts men who left the roster without being
reassigned, and is wiped once nobody has been in combat for two ticks - the bar is meant to
report "this fight cost you four men", not to accumulate for ever.

## Stopping the sword coming out on 1-4

Squad selection sits on 1-4, which are `qam_1`..`qam_4` - and in the field those draw the
weapon in that quick slot. The fix is an **action filter**, not an action map.

The game ships one for exactly this:

```xml
<actionfilter name="no_qam_weapons">
    action_qam_1..4 · open_qam_weapon · activate_qam_weapon
    action_qam_weapon · toggle_holster_qam_weapon
</actionfilter>
```

Of those, only two are on a keyboard superaction: **1-4** and **B** (the quick-access weapon
wheel). Blocking B would cost the player their weapon draw for as long as the interface is
open, so `Libs/Config/mercenaries_input.xml` declares a narrower `merc_no_qam_slots` with the
four quick slots and nothing else. It is loaded with `ActionMapManager.LoadFromXML`, so it
does not override `defaultProfile.xml` and cannot collide with a mod that ships its own copy.

**Lua cannot enable a filter.** `EnableActionFilter` was removed from the script binding
before release - it appears as `removed` in Warhorse's own 2023 scriptbind changelog, and the
string is absent from WHGame.dll. Only `IsFilterEnabled` survives.

The live route is the Skald quest node **`FilterInput`** (`wh::playermodule::C_FilterInput`),
a bare engine primitive with no `Namespace` - so it carries none of the risk described in
[quests.md](quests.md) about referencing vanilla sub-modules. It takes `Filters`
(`array<string>` from a `MakeArray`) and `IsActive` (bool). The base game uses it 94 times,
eight of them on `no_qam_weapons`; the clearest model is the vanilla module
`zakazani_zasunuti_zbrane_a_inventare`, which enables `no_qam_weapons` + `no_inventory` and
nothing else - no movement or camera filter alongside.

The Lua-to-quest bridge is the one this mod already uses elsewhere: Lua puts a marker item in
the player's inventory, an `ItemDescriptorTrigger` fires `OnAcquire` / `OnLose`, and a `State`
feeds `IsActive`.

### How it is wired

| Piece | Where |
|---|---|
| the filter | `data/Libs/Config/mercenaries_input.xml`, loaded with `LoadFromXML` |
| the marker item | `merc_qamblock_token` in `data/Libs/tables/item/item__mercenaries.xml`, weightless |
| the quest nodes | `merc_qam_*` in **both** `mercenaries_background_quest.xml` copies |
| the driver | `BL.qamGate` in `mercenaries_blui.lua`, `merc_bl_qam` to change it |

Lua adds the weightless marker to the player's inventory; an `ItemDescriptorTrigger` fires
`OnAcquire` / `OnLose`; a bool `State` feeds `FilterInput.IsActive`. The item is weightless
because it is added and removed constantly, and the token is cleared unconditionally on every
`OnGameplayStarted` - a crash with the interface open would otherwise leave the filter stuck
on and 1-4 permanently dead.

The nodes are duplicated into the **trosecko** copy as well. Those two quests are hand-mirrored
(see [quests.md](quests.md)); a change to one that is not made to the other simply stops
working when the player crosses regions.

`merc_bl_qam <shown|wheel|off>` sets the gate: `shown` blocks for as long as the interface is
up (1-4 are ours then), `wheel` only while an order is being picked, `off` never.

`merc_bl_filter` probes whether the custom filter registered at all. Note it is **not
conclusive**: `IsFilterEnabled` reports *enabled*, not *present*, and returns `false` for the
definitely-present `no_qam_weapons` just as readily. The real test is whether 1-4 stop drawing.
If they do not, **MEASURED: the runtime-loaded custom filter did not take** - `merc_no_qam_slots` had no
effect, so both quest copies now name the vanilla `no_qam_weapons`. That works, at the cost of
also blocking the **B** quick-access weapon wheel for as long as the interface is up.
`merc_bl_qam wheel` narrows it to only while an order is being picked, which gives B back
between orders.

`Libs/Config/mercenaries_input.xml` is kept: it costs nothing, and it documents the narrower
filter for the day `LoadFromXML` is understood well enough to register one.

Note there is **no ref-counting** on a filter's enabled state, so if our `FilterInput` and a
vanilla quest's both target the same filter, whichever fires last wins. That is another reason
to use our own filter name rather than `no_qam_weapons`.

## KCD2 Keybinder

Console binds are how this interface takes keys by default, and they have a real limitation:
the engine's bind table keeps **no history**, there is no command to read a key's current
binding, and `bind` silently overwrites. So two mods wanting F4 just stomp each other.

[KCD2 Keybinder](../references) solves this properly. It reads the vanilla
`defaultProfile.xml` and `keybindSuperactions.xml` out of the game pak, merges every
mod-declared command into them, and writes the result as a generated pak - so mod commands
become **real action-map actions the player assigns in the game's own keybind options**, with
the game's own conflict handling.

It discovers commands by scanning mod Lua for two annotations, which this mod now carries for
all 16 of its bindable commands:

```lua
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_k1
```

With Keybinder installed, set `BL.useConsoleBinds = false` so the interface stops taking keys
itself and leaves them entirely to the assignments the player made.

Without it, the console-bind fallback stays on and `mercenaries.BLRestore` is the only way to
give another mod's key back:

```lua
mercenaries.BLRestore = { f4 = "wh_camera_thirdperson_toggle" }
```

## Slow motion

Time slows **while a wheel is open** - not while the bar is merely on screen. That distinction
matters now the interface is permanent: tying it to visibility would run the whole game at 30%
speed forever. `BL.slowmo` is the factor (default `0.30`, `1` disables) and `merc_bl_slowmo`
changes it live. `BL.timeCvar` selects which cvar is driven.

**Measured: something in the engine restores `t_GameScale` about ten seconds after it is
written.** One write is not enough, so it is re-asserted once a second while a wheel is open.
The refresh chain is single-instance and ends the moment the wheel closes, so it never
outlives the order being given and never accumulates into a save.

It writes **`t_GameScale`** - stock CryEngine's own *"Game time scaled by this - for variable
slow motion"*. It is not cheat-gated: its flags (`0x84`) share no bits with the console's
`0x3000002` cheat mask, and `ICVar::Set` has no gate of its own. KCD2 never writes it - the
game's Master Strike and Perfect Block are parry-timing windows, not time dilation, and the
inherited Crysis `bulletTimeMode` cvars are dead code with no reader - so nothing else is
competing for it.

`t_GameScale` is scoped to game time. `t_Scale` is "All times" and drags the UI with it, so
prefer the former.

Time scale is global engine state, which makes leaking it the real risk: a crash, an alt-F4
or a save taken while the interface was open would strand the game in slow motion. It is
reset on hide **and** unconditionally on every `OnGameplayStarted`.

Camera feel is the one thing not settled on paper. CryEngine keeps a scaled channel
(`GetFrameTime`) and a real one (`GetCurrAsyncTime`), and the UI rides the real one, which is
a good sign mouse-look stays crisp - but the view-update path was not traced end to end. If
look does feel sluggish, scaling mouse sensitivity by `1/BL.slowmo` while active is the fix,
not a blocker.

## What is on screen

**Squad cards**, left edge, one per squad. Troop-type glyph and headcount at the top, the
same glyph again as a faint watermark filling the card, a health bar across the bottom that
runs green to amber to red, the squad's index in a chip on the right edge, and the squad's
current order as a small glyph underneath. A selected squad gets Bannerlord's warm brown
fill and a brighter gold border.

The cards are shorter than Bannerlord's because five squads have to fit a column where
Bannerlord only ever stacks four.

**Order row**, bottom centre but raised well clear of KCD2's health and stamina vignette -
Bannerlord puts this row exactly where KCD2 puts the player's health. Each button reports
the *live* state rather than a fixed category name, so the Movement button reads "Follow Me"
when the company is following. A lit state (firing at will, mounted, facing) gets the gold
ring.

**Radial submenu**, centred above its own button. Its discs are noticeably smaller than the
row's, badge and label sit right on the disc rim, and the whole thing sits on a soft dark
vignette. While it is open the row drops its key badges, because the keys now address the
wheel.

## The order tree

| Category | Orders |
|---|---|
| Movement | Move to Position, Follow Me, Charge, Stop, Retreat, Return |
| Formation | Line, Column, Square, Wedge, Circle, Escort, Return |
| Toggle | Fire at Will, Mounted, Engagement, Swarm, Return |
| Weapons | Random, Sword & Shield, Axe & Shield, Mace & Shield, Longsword, Polearm, Return |
| Clothing | five wardrobe styles, More, Return |

**Weapons** is context-sensitive: with an archer squad selected it offers Bow, Crossbow and
Hand Cannon from `mercenaries.ArcherWeaponSets` instead of the melee list from
`mercenaries.WeaponSets`.

**Weapons and Clothing are applied man by man**, not through `ChangeMercWeapon` /
`ChangeMercOutfit`. Those re-equip the *whole company*, which is how picking a ranged loadout
for an archer squad ended up putting hand cannons on the melee line. Both use the per-entity
form the company-wide functions call internally, and both skip `SpawnedFriend`-less custom
companions on the same rule those functions use. Switching into or out of the custom uniform
re-arms the same men, because that uniform carries its weapon with it.

### Commanding a quartered squad

Camp members are excluded from `HoldRoster` (`IsMercInCampProper` / `IsCampActor`), so a ground
order simply never reaches them - they stand in camp and the order looks ignored. Every order
except **To Camp** therefore calls `BLLeaveCamp` first, which marks the selected squads out of
the out-party: the camp's own way of saying "these men are with the player now".

So a squad can be sent straight from camp to a piece of ground, and the rest of the company is
not disturbed.

**To Camp** is one button with three states: no camp pitches one and sends the selection in; a
selection that is out goes in; a selection already in marches back out, and the camp is broken
once nobody is left inside.

It is scoped throughout, which takes care. `SpawnMercCamp` does `CampOutParty = {}` - "fresh camp: everyone starts in it" - so pitching
one claims the whole company logically, including squads holding ground somewhere else. It does
**not** teleport anyone, so sweeping the unselected men straight back into the out-party
immediately afterwards is enough, and there is no tick in which a holding squad drops out of
`HoldRoster`. Squads are also dropped out of
any ground order before teleporting, or a man moved off his station walks all the way back.

It took the bottom-row seat that Fire at Will had. Fire is still in the Toggle wheel.

**Clothing** offers the 17 wardrobe styles from [outfits.md](outfits.md). Seventeen will not
fit a wheel that holds six, so it pages five at a time and slot 6 steps to the next page. The
last page is short (5-5-5-2), and its empty slots are held open rather than collapsed - so
More is always `0` and Return is always `H`, on every page.

Squad selection needs no wheel: 1-4 pick squads directly.

Mount and Facing Direction gave up their seats on the bottom row to Weapons and Squads. Both
still live in the Toggle wheel, which is where Bannerlord keeps its duplicates too.

Every list mirrors a table the mod already has, so the wheel cannot offer an order the mod
cannot issue:

| Wheel | Source |
|---|---|
| Formation | `mercenaries.FormationShapeOrder` |
| Engagement | `mercenaries.EngageOrder` - Engage at will / Viking: kill everyone / Defend only / Hold your blades |
| Swarm | `mercenaries.AggroOrder` - Tight ranks / Balanced / Swarm them |

Engagement and Swarm are multi-state settings, not toggles: each press steps to the next
state, and the gold ring means "not the default" rather than "on".

There is no Movement "No Engage" entry. Refusing combat is what `EngageOrder`'s *Hold your
blades* already is, so it belongs in Engagement rather than duplicated as a movement order.

## How it is built

`tools/make_bl.py` generates three files that must always be rebuilt together:

| File | What it is |
|---|---|
| `data/libs/UI/MercBL.swf` | the art: ~130 unique bitmaps wrapped in 586 named clips |
| `data/libs/UI/UIElements/MercBL.xml` | the UIElements contract naming every clip |
| `data/Scripts/mods/mercenaries_blatlas.lua` | clip sizes, layout geometry, order tree, key binding |

```
python tools/make_bl.py --preview
```

`--preview` renders `tools/out/blui_*.png` - the whole interface composed offline from the
same art and the same geometry the game uses. That is the iteration loop: it answers "does
this look right" without launching the game.

Everything is a bitmap in a named sprite. Sprites share shapes and shapes share bitmaps, so
586 clips cost about 130 images. Clips are centre-registered, which is what a radial menu and
a row of circles want. Bitmaps are rendered at 3x the stage and each clip carries a 1/3
shrink in its authored matrix, so a 4K screen - exactly 3x the 1280x720 stage - gets 1:1
pixels instead of an upscale.

### Two traps worth remembering

`SetScale` and `SetAlpha` are **percent**, not multipliers, and the atlas bakes that 1/3
shrink into every clip's authored matrix. A scale call has to re-apply the shrink or the
clip jumps to three times its intended size. `SetPos` is in plain stage units.

Clips are parked off-stage at build time rather than hidden, so nothing flashes in the frame
between the movie being built and Lua laying it out. The first layout is deferred ~600 ms
past `ShowElement` for the same reason: the movie is built on first display, and transforms
sent in the same call address clips that do not exist yet and silently no-op.

## Art

Glyphs come from `assets/ui/command-icons-v2` - original silhouettes in Bannerlord's visual
language, not TaleWorlds' assets. They are loaded, flattened to a single colour and fitted
to a box, so inconsistent margins in the source PNGs do not show.

v2 covers every setting the mod actually has, including the four engagement states, the three
swarm presets and the weapon loadouts, so nothing in the interface is a placeholder any more.

The glyphs are generated rasters and **48 of the 50 carry a faint halo of near-transparent
pixels well outside the artwork**. A raw `getbbox()` centres the icon on that halo instead of
on the ink - measured at up to 123px of 1254, which reads as a visibly off-centre glyph. The
box is taken from a thresholded copy (`GLYPH_ALPHA_FLOOR`) and the real alpha cropped to it,
so soft edges inside the glyph survive. The build still
prints any glyph it had to stand in for, and prints nothing when there are none.

`assets/ui/outfit-icons-v1` holds 17 heraldic style icons for the wardrobe presets in
[outfits.md](outfits.md). Those belong to the camp/outfit screen, not this one, and are not
in this atlas.

## What the screen reads back

Every button and every lit wheel slot shows what the company is **actually set to**, read out
of the mod on each draw by `BLReadState`. Nothing on this screen keeps its own copy of a
setting: `BL.state` is a cache the layout refreshes and the presses write optimistically, so
an order that is refused or clamped puts its own button back.

That was not always so. `BL.state` used to be a table of defaults seeded when the driver
loaded and written only by this screen's own presses, and everything set from the console,
from the quartermaster's dialogue or restored by a save was contradicted the moment the
screen opened. Horses ship **on** and the button opened on "Dismounted"; a company holding
fire read "Firing at will"; a wedge read "Line".

| Shown | Read from |
|---|---|
| Movement | `SquadOrder[i]`, cross-checked against `HoldStations` |
| Formation | `mercenaries.FormationShape` |
| Fire at Will | `_G.ArcherStance` - `skirmish` is on, anything else is off |
| Mounted | `mercenaries:HorsesAllowed()` |
| Engagement | `_G.MercEngage` |
| Swarm | `_G.MercAggro` |
| Weapons (melee) | `SquadWeapon[i]`, else `_G.MercCurrentWeapon` |
| Weapons (ranged) | `mercenaries:GetArcherWeaponType()` - company-wide, never per squad |
| Clothing | `SquadOutfit[i]`, else `_G.MercCurrentOutfit` |

Two of those need the cross-check rather than the record alone:

**A ground order outlives its stations.** `SquadOrder` is the last order *given*;
`HoldDropGroup`, a rally and every gameplay start clear the stations while the record stays
put. Without `BLSquadHeld` a reloaded save opened on "Move to Position" with the men trotting
along behind the player. `BLOrdersOnLoad` now drops `SquadOrder`, `SquadWeapon` and
`SquadOutfit` outright for the same reason - a load re-dresses and re-arms the whole company
from `MercCurrentOutfit` / `MercCurrentWeapon`, so the per-squad records describe nothing.

**A charge is a thirty-second window, not a standing order.** It reads as a charge only while
`_blChargePrevStance` says one is in flight.

A live setting with **no wheel entry** is never written into `BL.state`: `FormationShape`
"vanilla" and `ArcherStance` "melee" have no clip, and a button asked for a clip that does not
exist draws nothing at all - it would vanish rather than lie. The formation button keeps the
last real shape; `melee` reads as not firing, which is what men with the bow on their back are
doing.

`tools/check_blstate.py` is the gate: it runs the drivers in a real Lua interpreter, calls the
mod's own setters, and asserts both that `BL.state` agrees with them and that every value it
can produce names art in the atlas.

### The archers' weapon wheel

Picking Bow, Crossbow or Hand Cannon goes to `SetArcherWeaponType`, not down the per-man
`EquipMercenaryWeapon` path the melee loadouts use. `EquipMercenaryWeapon` throws away the
index it is handed for an archer and re-equips him from that company-wide setting instead
(see [archers.md](archers.md)), so a ranged pick used to light the wheel's icon and change
nothing - the men kept the weapon they had.

## Wiring it to the real company

`mercenaries.BLSquadSource` returns the card data, and `mercenaries_blorders.lua` drives it
off the real squads - troop type, headcount, mean health, casualties and the squad's live
state, all from [mercenaries_squads.lua](../data/Scripts/mods/mercenaries_squads.lua).
Replace it to drive the cards off something else:

```lua
mercenaries.BLSquadSource = function()
    return { { type = "infantry", count = 12, hp = 1.0, order = "charge", sel = true }, ... }
end
```

`type` must be one of `BLAtlas.troopTypes` and `order` one of the movement keys - plus
`camp`, which is a card state rather than an order.
