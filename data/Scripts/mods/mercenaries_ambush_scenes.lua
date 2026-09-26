-- Authored ambush scenes: paste merc_ambush_dump output here.
-- Tools and workflow: docs/encounters.md.
--
-- level is informational. No level API is exposed to Lua, so "unknown" means
-- "match any level" - a trigger box from the other map never contains the player.
-- Optional per-scene `group = "bandit"` picks who springs it (default looter).

mercenaries.AmbushScenes = mercenaries.AmbushScenes or {}

mercenaries.AmbushScenes["forest_bend"] = {
    level = "unknown",
    archers = {
        { x = 2665.48, y = 3098.64, z = 123.71 },
        { x = 2663.55, y = 3097.54, z = 123.85 },
        { x = 2661.11, y = 3095.81, z = 124.07 },
        { x = 2658.02, y = 3093.66, z = 124.33 },
        { x = 2654.50, y = 3096.68, z = 123.98 },
        { x = 2656.96, y = 3099.07, z = 123.79 },
        { x = 2659.78, y = 3101.58, z = 123.58 },
        { x = 2661.46, y = 3103.08, z = 123.47 },
    },
    melee = {
        { x = 2658.28, y = 3095.14, z = 124.19 },
        { x = 2657.64, y = 3095.83, z = 124.10 },
        { x = 2656.92, y = 3096.56, z = 123.99 },
        { x = 2656.56, y = 3097.14, z = 123.94 },
    },
    triggers = {
        { minx = 2661.29, miny = 3098.75, maxx = 2672.23, maxy = 3108.53 },
        { minx = 2643.41, miny = 3084.22, maxx = 2657.58, maxy = 3097.41 },
    },
}
