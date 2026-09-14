"""Press H and U and check which screen is up.

Every other checker reads the drivers as text. This one RUNS them: lupa embeds a real Lua
interpreter, the engine gets stubbed, and the two screens' state machine is exercised by
calling BLToggle and CUToggle the way the keys do.

What it pins:

  * the two screens are never up together. They share the number row, and with both up
    which of them a keypress reaches depends on which test runs first.
  * opening one while the other is up SWAPS - the first closes.
  * closing a screen closes it. Nothing reopens behind it; a screen that comes back on its
    own is the thing players complained about loudest.
  * the number row stays held across a swap. The order matters: CUReleaseKeys hands the
    keys back to the game, so BLShow has to close the camp screen BEFORE it takes them.

    python tools/check_uistate.py

Needs lupa (`pip install lupa`); skipped with a note if it is missing, like the luaparser
check in check_campui.py.
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

# The engine, as far as these two files are concerned. Anything they call that is not here
# sits inside a pcall and is swallowed, which is the same thing that happens in game when a
# sibling module has not loaded yet.
PRELUDE = """
LOG, KEYS, TIMERS = {}, { held = false }, {}
System = {
    LogAlways = function(s) LOG[#LOG+1] = tostring(s) end,
    ExecuteCommand = function(s)
        if tostring(s):match("^bind ") then KEYS.held = true end
        if tostring(s):match("^unbind ") then KEYS.held = false end
    end,
    SetCVar = function() end, GetCVar = function() return 0 end,
    GetCurrTime = function() return 0 end, GetFrameID = function() return 1 end,
    GetViewport = function() return { x = 0, y = 0, width = 1920, height = 1080 } end,
}
Script = { SetTimerForFunction = function(ms, n) TIMERS[#TIMERS+1] = n end,
           LoadScript = function() end }
UIAction = {}
for _, n in ipairs({"ShowElement","HideElement","ReloadElement","UnloadElement","SetPos",
                    "SetScale","SetAlpha","SetVisible","GotoAndStopFrameName","SetVariable",
                    "CallFunction"}) do UIAction[n] = function() end end
player = { inventory = { CreateItem = function() end, DeleteItemOfClass = function() end,
                         GetCountOfClass = function() return 0 end } }
Game = { SendInfoText = function() end }
mercenaries = mercenaries or {}
mercenaries.PlayerCommand = function() end
mercenaries.DevCommand = function() end
mercenaries.SaveString = function() end
mercenaries.LoadString = function() return nil end
mercenaries.ActiveMercs = {}
mercenaries.BLSquadSource = function() return {} end
"""

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(PRELUDE)

for f in ("mercenaries_blatlas.lua", "mercenaries_campatlas.lua",
          "mercenaries_blui.lua", "mercenaries_campui.lua"):
    try:
        lua.execute(io.open(os.path.join(MODS, f), encoding="utf-8", errors="replace").read())
    except Exception as e:
        print("WOULD NOT LOAD: %s -> %s" % (f, str(e)[:160]))
        sys.exit(1)

# The camp panels read the live logistics tables. Faking those is not this check's job, and
# what is under test is the state machine, not the pixels.
lua.execute("mercenaries.CUDrawPanels = function() end")
lua.execute("mercenaries.CUDrawRow = function() end")

m = lua.globals().mercenaries
KEYS = lua.globals().KEYS

STEPS = [
    ("H", (True, False),  "opens the command screen"),
    ("U", (False, True),  "swaps to the camp screen"),
    ("U", (False, False), "closes it, and nothing reopens"),
    ("H", (True, False),  "opens the command screen"),
    ("H", (False, False), "closes it"),
    ("U", (False, True),  "opens the camp screen"),
    ("H", (True, False),  "swaps to the command screen"),
    ("U", (False, True),  "swaps back"),
    ("U", (False, False), "closes it"),
]

bad = 0
for key, want, why in STEPS:
    (m.BLToggle if key == "H" else m.CUToggle)(m)
    got = (bool(m.BL.on), bool(m.CU.on))
    if got[0] and got[1]:
        print("BOTH SCREENS OPEN AT ONCE after pressing %s" % key)
        bad += 1
    elif got != want:
        print("PRESSING %s: command=%s camp=%s, expected command=%s camp=%s (%s)"
              % (key, got[0], got[1], want[0], want[1], why))
        bad += 1
    if got != (False, False) and not KEYS.held:
        print("THE NUMBER ROW WAS DROPPED while a screen was up (after %s)" % key)
        bad += 1

print("ui state: %d transitions checked, %d wrong" % (len(STEPS), bad))
print("PASS" if not bad else "FAIL")
sys.exit(1 if bad else 0)
