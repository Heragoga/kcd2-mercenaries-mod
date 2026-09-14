"""Set the company the way the game sets it, then check the command screen agrees.

The row and the wheels used to be driven by BL.state, a table of defaults seeded when
mercenaries_blui.lua loaded and written only by this screen's own presses. Everything set
from the console, from the quartermaster's dialogue or restored by a save was therefore
contradicted the moment the screen opened - the company held fire and the button read
"Firing at will", horses were on by default and the button read "Dismounted".

BLReadState fixes that by re-reading every entry off the mod on each draw. This check runs
it: lupa embeds a real Lua interpreter, the engine is stubbed, the mod's own setters are
called, and BL.state is then compared against what they were told.

It also pins the trap that makes a wrong read invisible rather than wrong: a value with no
clip in the atlas - FormationShape "vanilla", ArcherStance "melee" - draws NOTHING, so the
button disappears instead of lying. Every value BLReadState can produce has to name art.

    python tools/check_blstate.py

Needs lupa (`pip install lupa`); skipped with a note if it is missing, like check_uistate.py.
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODS = os.path.join(ROOT, "data", "Scripts", "mods")

try:
    from lupa import LuaRuntime
except Exception:
    print("(lupa not installed - skipping the UI state check)")
    sys.exit(0)

# The engine, as far as these files are concerned. Anything they call that is not here sits
# inside a pcall and is swallowed, which is what happens in game when a sibling module has
# not loaded yet.
PRELUDE = """
LOG = {}
System = {
    LogAlways = function(s) LOG[#LOG+1] = tostring(s) end,
    ExecuteCommand = function() end,
    SetCVar = function() end, GetCVar = function() return 0 end,
    GetCurrTime = function() return 0 end, GetFrameID = function() return 1 end,
    GetViewport = function() return { x = 0, y = 0, width = 1920, height = 1080 } end,
    SpawnEntity = function() return nil end, RemoveEntity = function() end,
}
Script = { SetTimerForFunction = function() end, LoadScript = function() end }
UIAction = {}
for _, n in ipairs({"ShowElement","HideElement","ReloadElement","UnloadElement","SetPos",
                    "SetScale","SetAlpha","SetVisible","GotoAndStopFrameName","SetVariable",
                    "CallFunction"}) do UIAction[n] = function() end end
player = { id = 1, inventory = { CreateItem = function() end,
                                 DeleteItemOfClass = function() end,
                                 GetCountOfClass = function() return 0 end,
                                 GetMoney = function() return 0 end } }
Game = { SendInfoText = function() end }
mercenaries = mercenaries or {}
mercenaries.PlayerCommand = function() end
mercenaries.DevCommand = function() end
mercenaries.SaveString = function() end
mercenaries.LoadString = function() return nil end
mercenaries.ActiveMercs = {}
"""

# Every module that owns one of the settings the screen reports, plus the screen itself.
# mercenaries_formation.lua is deliberately NOT here - it needs the scheduler's ChainDef and
# the only thing this check wants from it is the plain field FormationShape, which the
# scenarios set directly.
FILES = ("mercenaries_orders.lua",       # engagement stance, anti-swarm preset
         "mercenaries_archers.lua",      # archer stance, archer weapon type
         "mercenaries_difficulty.lua",   # horses
         "mercenaries_squads.lua",       # the squads an order binds
         "mercenaries_hold.lua",         # the stations a ground order plants
         "mercenaries_blatlas.lua", "mercenaries_blui.lua", "mercenaries_blorders.lua")

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(PRELUDE)
for f in FILES:
    try:
        lua.execute(io.open(os.path.join(MODS, f), encoding="utf-8", errors="replace").read())
    except Exception as e:
        print("WOULD NOT LOAD: %s -> %s" % (f, str(e)[:200]))
        sys.exit(1)

m = lua.globals().mercenaries
G = lua.globals()


def art():
    """Every key each wheel has a clip for, read out of the generated atlas."""
    out = {}
    A = m.BLAtlas
    for cat in A.wheels:
        out[cat] = {e.key for e in A.wheels[cat].values() if e.key != "return"}
    for slot in A.stateWheels.tog.values():
        if slot.slot != "return":
            out[slot.slot] = {s.key for s in slot.states.values()}
    out["outfit"] = {s.key for s in A.stateWheels.outfit[1].states.values()}
    return out


ART = art()

# BL.state entry -> the wheel whose art it has to name.
OWNER = {"move": "move", "form": "form", "fire": "fire", "mount": "mount",
         "engage": "engage", "swarm": "swarm", "wpnm": "wpnm", "wpnr": "wpnr",
         "outfit": "outfit"}


def station(i, key):
    """Put squad i's man `key` on a hold station, the way HoldAddGroup does."""
    lua.execute("mercenaries.Squads[%d] = { ['%s'] = true }" % (i, key))
    lua.execute("mercenaries.HoldStations['%s'] = { x = 0, y = 0, z = 0 }" % key)


def reset():
    lua.execute("""
        mercenaries.Squads, mercenaries.HoldStations = {}, {}
        mercenaries.SquadOrder, mercenaries.SquadWeapon, mercenaries.SquadOutfit = {}, {}, {}
        mercenaries._blChargePrevStance = nil
        mercenaries.BL.placing = false
        mercenaries.FormationShape = "column"
        _G.MercCurrentWeapon, _G.MercCurrentOutfit = 1, 1
        mercenaries:SetArcherStance("skirmish")
        mercenaries:SetArcherWeaponType("bow")
        mercenaries:SetEngageStance("default")
        mercenaries:SetAggroPreset("balanced")
        mercenaries:HorsesSet(true)
    """)


# Each case: a name, the Lua that sets the company up, and the BL.state entries it must
# produce. Everything not named is free to be whatever the defaults make it.
CASES = [
    ("a fresh company", "", dict(move="follow", fire="on", mount="on",
                                 engage="default", swarm="balanced",
                                 wpnm="random", wpnr="bow", outfit="generic")),

    ("orders given from the console / the dialogue", """
        mercenaries:SetArcherStance("hold")
        mercenaries:SetEngageStance("defend")
        mercenaries:SetAggroPreset("tight")
        mercenaries:HorsesSet(false)
        mercenaries.FormationShape = "wedge"
     """, dict(fire="off", engage="defend", swarm="tight", mount="off", form="wedge")),

    # This is the one the whole screen was wrong about: horses ship ON, and the button
    # opened on "Dismounted" until something pressed it.
    ("horses, which are on by default", "", dict(mount="on")),

    ("archers told to close to melee - a stance the button cannot show", """
        mercenaries:SetArcherStance("melee")
     """, dict(fire="off")),

    ("the archers' weapon type, which is company-wide", """
        mercenaries:SetArcherWeaponType("crossbow")
     """, dict(wpnr="crossbow")),

    ("the loadout and the wardrobe a save restores", """
        _G.MercCurrentWeapon, _G.MercCurrentOutfit = 4, 9
     """, dict(wpnm="longsword", outfit="sigismund")),

    ("this screen's own per-squad loadout, which outranks the company's", """
        _G.MercCurrentWeapon = 4
        mercenaries.SquadWeapon[1] = "polearm"
        mercenaries.SquadOutfit[1] = "teutonic"
     """, dict(wpnm="polearm", outfit="teutonic")),

    ("a squad standing on the ground it was sent to", """
        mercenaries.SquadOrder[1] = "move"
     """, dict(move="move"), lambda: station(1, "w1")),

    # The stations are cleared on every gameplay start and by HoldDropGroup; SquadOrder is
    # not, so without the cross-check a reloaded save opened on "Move to Position" with the
    # men trotting along behind the player.
    ("a ground order whose stations are gone", """
        mercenaries.SquadOrder[1] = "move"
     """, dict(move="follow")),

    ("a charge in flight", """
        mercenaries.SquadOrder[1] = "charge"
        mercenaries._blChargePrevStance = "default"
     """, dict(move="charge")),

    ("a charge that has expired", """
        mercenaries.SquadOrder[1] = "charge"
     """, dict(move="follow")),

    ("siting a flag, before the click lands", """
        mercenaries.BL.placing = true
     """, dict(move="move")),

    # No wheel entry and no art: the button must keep the last real shape rather than ask
    # for a clip that does not exist and draw nothing.
    ("the internal 'vanilla' formation fallback", """
        mercenaries.FormationShape = "vanilla"
     """, dict(form="column")),
]

bad = 0
for case in CASES:
    name, setup, want = case[0], case[1], case[2]
    reset()
    if len(case) > 3:
        case[3]()
    if setup.strip():
        lua.execute(setup)
    m.BLReadState(m)
    st = m.BL.state
    for k, v in sorted(want.items()):
        got = st[k]
        if got != v:
            print("%s: BL.state.%s = %r, expected %r" % (name, k, got, v))
            bad += 1
    # Whatever it produced, every entry has to name art.
    for k, wheel in sorted(OWNER.items()):
        got = st[k]
        if got not in ART[wheel]:
            print("%s: BL.state.%s = %r, which has no clip in the atlas" % (name, k, got))
            bad += 1

print("bl state: %d company set-ups checked, %d wrong" % (len(CASES), bad))
print("PASS" if not bad else "FAIL")
sys.exit(1 if bad else 0)
