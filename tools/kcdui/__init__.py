"""kcdui - build custom Scaleform UI for Kingdom Come: Deliverance II.

    from kcdui import Atlas, art, fonts, verify

    A = Atlas("MyScreen")
    A.clip("panel", "panel_art", art.rounded(300, 120, 8, (26, 21, 15), 0.93))
    A.clip("title", "title_art", art.text("Supplies", 19, (238, 231, 216)))
    A.write_swf("data/libs/UI/MyScreen.swf")
    A.write_xml("data/libs/UI/UIElements/MyScreen.xml")
    A.write_lua("data/Scripts/mods/myscreen_atlas.lua", "MyScreenAtlas")

Then drive it from Lua with runtime/kcdui.lua. See README.md - most of what is in there is
a trap that fails silently, which is the whole reason this package exists.
"""
from .atlas import Atlas, lua_value                       # noqa: F401
from . import swf, art, fonts, verify, scene              # noqa: F401

__all__ = ["Atlas", "lua_value", "swf", "art", "fonts", "verify", "scene"]
__version__ = "0.1.0"
