-- The siege of Raborsch.
--
-- Authored with the siege builder (mercenaries_siege.lua, docs/siege-builder.md) and replayed
-- here. The layout is the walls and the besiegers' camp; the MEN are generated, because their
-- number follows the player's company rather than being fixed.
--
--   merc_raborsch        raise the siege
--   merc_raborsch_clear  take it down again
--
-- WHO SHOOTS WHOM
--   Defender archers run "wall": they shoot the besiegers' ARCHERS and nothing else - never the
--   player, never their mercs, and deliberately not the assaulting foot. Shooting the foot made
--   every one of them turn on the wall instead of pressing the assault.
--   Attacker archers run "besieger" (added for this): the player, the mercs AND the defenders
--   on the walls. The ordinary "hostile" mode spares every static archer so two towers never
--   trade shots, which is right for a bandit camp and quite wrong for a siege.
--
-- See docs/raborsch.md.

local function rLog(s) System.LogAlways("[Raborsch] " .. s) end

mercenaries.RaborschLayouts = {}
mercenaries.RaborschPatrols = {}

-- THE site. The siege stands here and nowhere else - there is deliberately no "raise it where
-- I am standing" command, because the layout was authored against this ground: the wall line
-- follows the ridge and the besiegers' camp sits in the hollow behind it. Replayed anywhere
-- else it is 170 pieces of geometry floating through a hillside.
--
-- Level is "kutnohorsko" rather than the dump's "unknown": no level API answers in game, so
-- the builder could not know, but this site is Kuttenberg's.
mercenaries.RaborschSite = { name = "raborsch", level = "kutnohorsko",
                             x = 1425.57, y = 3871.55, z = 118.13, yaw = 0, layout = "initial" }

mercenaries.RaborschLayouts.initial = {
    { kind = "tower", what = "defender archer tower", x = 0.00, y = 0.00, z = 0.00, yaw = 1.7095 },
    { kind = "tower", what = "defender archer tower", x = 4.65, y = 0.32, z = -0.24, yaw = 1.5732 },
    { kind = "tower", what = "defender archer tower", x = 8.64, y = 0.43, z = -0.22, yaw = 1.4734 },
    { kind = "tower", what = "defender archer tower", x = 12.82, y = 0.06, z = -0.13, yaw = 1.3930 },
    { kind = "tower", what = "defender archer tower", x = 17.12, y = -0.77, z = -0.22, yaw = 1.2196 },
    { kind = "tower", what = "defender archer tower", x = 20.73, y = -2.45, z = -0.24, yaw = 0.9603 },
    { kind = "tower", what = "defender archer tower", x = 28.96, y = -11.73, z = -0.48, yaw = 0.4964 },
    { kind = "tower", what = "defender archer tower", x = 32.58, y = -20.66, z = -0.56, yaw = 0.4443 },
    { kind = "tower", what = "defender archer tower", x = 33.31, y = -27.42, z = -1.10, yaw = 0.1609 },
    { kind = "tower", what = "defender archer tower", x = 34.72, y = -47.21, z = -0.78, yaw = -0.2263 },
    { kind = "tower", what = "defender archer tower", x = 28.72, y = -59.96, z = -0.65, yaw = -0.5229 },
    { kind = "tower", what = "defender archer tower", x = 17.19, y = -68.31, z = -0.96, yaw = -1.0532 },
    { kind = "tower", what = "defender archer tower", x = 5.40, y = -70.79, z = -1.06, yaw = -1.3194 },
    { kind = "tower", what = "defender archer tower", x = -3.01, y = -69.36, z = -1.50, yaw = -2.0865 },
    { kind = "tower", what = "defender archer tower", x = -16.70, y = -62.20, z = -0.75, yaw = -2.4636 },
    { kind = "tower", what = "defender archer tower", x = -25.43, y = -48.48, z = -0.96, yaw = -2.7100 },
    { kind = "tower", what = "defender archer tower", x = -26.37, y = -40.48, z = 0.01, yaw = -2.8435 },
    { kind = "tower", what = "defender archer tower", x = -27.24, y = -21.09, z = -0.91, yaw = -3.0797 },
    { kind = "tower", what = "defender archer tower", x = -23.57, y = -11.97, z = -0.97, yaw = 2.7744 },
    { kind = "tower", what = "defender archer tower", x = -20.88, y = -8.81, z = -0.83, yaw = 2.2977 },
    { kind = "tower", what = "defender archer tower", x = -18.07, y = -6.69, z = -0.95, yaw = 2.2334 },
    { kind = "tower", what = "defender archer tower", x = -15.02, y = -4.68, z = -0.72, yaw = 2.0586 },
    { kind = "tower", what = "defender archer tower", x = -10.42, y = -4.00, z = -0.68, yaw = 1.9641 },
    { kind = "cart", what = "defender archer cart", x = -4.87, y = -2.26, z = -0.21, yaw = -1.3472 },
    { kind = "barricade", what = "taras (wagon wall) c", x = -2.49, y = 1.29, z = -0.07, yaw = 3.3205 },
    { kind = "barricade", what = "taras (wagon wall) c", x = -9.95, y = -0.51, z = -0.08, yaw = 3.4719 },
    { kind = "barricade", what = "taras (wagon wall) a", x = -8.57, y = -0.08, z = 0.06, yaw = 3.4694 },
    { kind = "barricade", what = "taras (wagon wall) a", x = -7.25, y = 0.48, z = -0.11, yaw = 3.5171 },
    { kind = "barricade", what = "taras (wagon wall) a", x = -5.98, y = 0.83, z = -0.19, yaw = 3.3011 },
    { kind = "barricade", what = "taras (wagon wall) a", x = -4.64, y = 1.01, z = -0.23, yaw = 3.2349 },
    { kind = "barricade", what = "taras (wagon wall) a", x = -3.47, y = 1.06, z = -0.22, yaw = 3.2988 },
    { kind = "barricade", what = "taras (wagon wall) a", x = 6.83, y = 10.56, z = -0.62, yaw = 0.1554 },
    { kind = "barricade", what = "taras (wagon wall) a", x = 2.43, y = 10.41, z = -0.38, yaw = 0.1614 },
    { kind = "barricade", what = "taras (wagon wall) a", x = -1.19, y = 9.98, z = -0.05, yaw = 0.2126 },
    { kind = "barricade", what = "taras (wagon wall) a", x = -4.81, y = 8.73, z = 0.04, yaw = 0.2210 },
    { kind = "barricade", what = "taras (wagon wall) a", x = -8.71, y = 6.58, z = 0.22, yaw = 0.2223 },
    { kind = "barricade", what = "taras (wagon wall) a", x = -14.76, y = 4.32, z = 0.35, yaw = 0.7037 },
    { kind = "barricade", what = "taras (wagon wall) a", x = -18.27, y = 2.45, z = 0.13, yaw = 0.4589 },
    { kind = "attacker", what = "attacker static archer", x = -18.58, y = 3.16, z = 0.08, yaw = -1.0842, group = "sigi" },
    { kind = "attacker", what = "attacker static archer", x = -15.08, y = 4.77, z = 0.33, yaw = -0.8160, group = "sigi" },
    { kind = "attacker", what = "attacker static archer", x = -8.79, y = 7.12, z = 0.25, yaw = -1.2500, group = "sigi" },
    { kind = "attacker", what = "attacker static archer", x = -4.93, y = 9.57, z = 0.13, yaw = -1.3871, group = "sigi" },
    { kind = "attacker", what = "attacker static archer", x = -1.17, y = 10.65, z = -0.01, yaw = -1.4261, group = "sigi" },
    { kind = "attacker", what = "attacker static archer", x = 2.23, y = 11.21, z = -0.30, yaw = -1.3114, group = "sigi" },
    { kind = "attacker", what = "attacker static archer", x = 6.79, y = 11.57, z = -0.56, yaw = -1.4302, group = "sigi" },
    { kind = "barricade", what = "pavise a", x = 5.80, y = 10.39, z = -0.55, yaw = -0.4399 },
    { kind = "barricade", what = "pavise a", x = 8.15, y = 10.74, z = -0.65, yaw = 0.6625 },
    { kind = "barricade", what = "pavise a", x = 4.12, y = 10.41, z = -0.46, yaw = 0.1599 },
    { kind = "attacker", what = "attacker static archer", x = 4.01, y = 11.22, z = -0.44, yaw = -1.3922, group = "sigi" },
    { kind = "attacker", what = "attacker static archer", x = 5.74, y = 11.09, z = -0.58, yaw = -0.6361, group = "sigi" },
    { kind = "barricade", what = "pavise a", x = 1.28, y = 10.12, z = -0.30, yaw = -0.0190 },
    { kind = "barricade", what = "pavise a", x = 0.22, y = 10.03, z = -0.20, yaw = 0.2713 },
    { kind = "attacker", what = "attacker static archer", x = 0.46, y = 11.03, z = -0.18, yaw = -0.9810, group = "sigi" },
    { kind = "barricade", what = "pavise b", x = -3.69, y = 8.96, z = 0.02, yaw = 0.3467 },
    { kind = "barricade", what = "pavise a", x = -2.54, y = 9.36, z = 0.01, yaw = 0.5092 },
    { kind = "attacker", what = "attacker static archer", x = -3.18, y = 10.16, z = 0.08, yaw = -1.1603, group = "sigi" },
    { kind = "barricade", what = "pavise a", x = -5.96, y = 8.02, z = 0.07, yaw = 0.4938 },
    { kind = "barricade", what = "pavise a", x = -6.70, y = 7.84, z = 0.15, yaw = 0.4803 },
    { kind = "barricade", what = "pavise a", x = -7.38, y = 7.40, z = 0.23, yaw = 0.5234 },
    { kind = "attacker", what = "attacker static archer", x = -6.73, y = 8.98, z = 0.20, yaw = -0.2544, group = "sigi" },
    { kind = "attacker", what = "attacker static archer", x = -8.07, y = 8.35, z = 0.50, yaw = -1.1487, group = "sigi" },
    { kind = "barricade", what = "pavise a", x = -2.60, y = 12.91, z = 0.28, yaw = 0.5698 },
    { kind = "barricade", what = "pavise a", x = -4.45, y = 12.30, z = 0.30, yaw = 0.3459 },
    { kind = "barricade", what = "pavise a", x = -6.10, y = 11.64, z = 0.23, yaw = 0.3378 },
    { kind = "attacker", what = "attacker static archer", x = -6.42, y = 12.66, z = 0.16, yaw = -1.2613, group = "sigi" },
    { kind = "attacker", what = "attacker static archer", x = -4.78, y = 13.00, z = 0.27, yaw = -1.1031, group = "sigi" },
    { kind = "attacker", what = "attacker static archer", x = -2.93, y = 13.65, z = 0.34, yaw = -1.1469, group = "sigi" },
    { kind = "tent", what = "camp circle (fire + seats)", x = -3.34, y = 31.89, z = -2.71, yaw = 0.4762 },
    { kind = "tent", what = "big round tent (player tent)", x = -21.21, y = 36.87, z = -1.88, yaw = -1.9683 },
    { kind = "tent", what = "big round tent b", x = -24.82, y = 33.17, z = -1.91, yaw = -2.2076 },
    { kind = "tent", what = "big square tent", x = -29.32, y = 29.28, z = -2.05, yaw = -1.8418 },
    { kind = "tent", what = "small forest tent c", x = -27.10, y = 24.42, z = -2.51, yaw = -4.2153 },
    { kind = "prop", what = "bed", x = -27.63, y = 23.95, z = -2.51, yaw = -2.5987 },
    { kind = "prop", what = "bed", x = -29.15, y = 28.26, z = -2.15, yaw = -1.8537 },
    { kind = "prop", what = "bed", x = -28.86, y = 30.45, z = -1.98, yaw = 1.3480 },
    { kind = "prop", what = "weapon pile", x = -26.03, y = 32.55, z = -1.93, yaw = 2.8357 },
    { kind = "prop", what = "weapon pile", x = -26.08, y = 33.42, z = -1.93, yaw = 2.6001 },
    { kind = "prop", what = "barrel", x = -26.15, y = 34.05, z = -1.90, yaw = 2.4715 },
    { kind = "prop", what = "barrel", x = -25.65, y = 34.62, z = -1.89, yaw = 2.2769 },
    { kind = "prop", what = "arrow barrel", x = -24.99, y = 34.86, z = -1.88, yaw = 2.1000 },
    { kind = "prop", what = "arrow barrel", x = -24.58, y = 35.14, z = -1.88, yaw = 1.9695 },
    { kind = "prop", what = "arrow barrel", x = -24.69, y = 34.20, z = -1.88, yaw = 2.1231 },
    { kind = "prop", what = "arrow barrel", x = -25.55, y = 33.79, z = -1.92, yaw = 2.4188 },
    { kind = "prop", what = "arrow barrel", x = -25.81, y = 33.00, z = -1.93, yaw = 2.6733 },
    { kind = "prop", what = "sack_b", x = -24.13, y = 35.05, z = -1.88, yaw = 1.8634 },
    { kind = "prop", what = "sack_b", x = -23.71, y = 34.81, z = -1.88, yaw = 1.7610 },
    { kind = "prop", what = "sack_b", x = -24.36, y = 34.44, z = -1.88, yaw = 1.9904 },
    { kind = "prop", what = "sack_pig_feed", x = -25.18, y = 34.03, z = -1.88, yaw = 2.2837 },
    { kind = "prop", what = "sack_charcoal", x = -26.39, y = 31.92, z = -1.96, yaw = 3.0516 },
    { kind = "barricade", what = "cannon (unrealistic)", x = -23.64, y = 33.14, z = -1.90, yaw = 0.1954 },
    { kind = "barricade", what = "pavise a", x = -22.31, y = 33.13, z = -1.95, yaw = 1.3759 },
    { kind = "barricade", what = "pavise a", x = -22.52, y = 32.29, z = -1.94, yaw = 1.0369 },
    { kind = "barricade", what = "pavise a", x = -23.21, y = 31.64, z = -1.97, yaw = 0.6693 },
    { kind = "prop", what = "chair", x = -28.38, y = 27.48, z = -2.23, yaw = -1.7964 },
    { kind = "prop", what = "chair", x = -30.59, y = 29.16, z = -2.06, yaw = -2.5671 },
    { kind = "prop", what = "chair", x = -30.27, y = 30.78, z = -1.98, yaw = 3.0187 },
    { kind = "prop", what = "table small", x = -30.33, y = 29.69, z = -2.02, yaw = 2.9461 },
    { kind = "prop", what = "big chest (lootable)", x = -22.17, y = 36.55, z = -1.88, yaw = 1.6230 },
    { kind = "prop", what = "beer barrel", x = -22.12, y = 37.69, z = -1.90, yaw = 2.5602 },
    { kind = "prop", what = "table big", x = -20.59, y = 36.82, z = -1.88, yaw = -2.0965 },
    { kind = "prop", what = "chair", x = -20.31, y = 36.28, z = -1.88, yaw = -2.2051 },
    { kind = "prop", what = "chair", x = -19.90, y = 36.99, z = -1.88, yaw = -2.0091 },
    { kind = "prop", what = "chair", x = -21.74, y = 37.09, z = -1.88, yaw = -2.4125 },
    { kind = "prop", what = "chair", x = -21.12, y = 38.04, z = -1.88, yaw = -2.7497 },
    { kind = "tent", what = "camp circle (fire + seats)", x = -13.56, y = 23.51, z = -1.89, yaw = -1.2608 },
    { kind = "tent", what = "camp circle (fire + seats)", x = -26.14, y = 15.74, z = -1.91, yaw = -2.5460 },
    { kind = "tent", what = "tent 4", x = -34.39, y = 23.98, z = -2.29, yaw = -1.3012 },
    { kind = "tent", what = "tent 4", x = -33.16, y = 18.03, z = -1.96, yaw = -1.3627 },
    { kind = "tent", what = "tent 5", x = -32.49, y = 14.15, z = -1.82, yaw = -1.4764 },
    { kind = "tent", what = "tent 2", x = -33.72, y = 21.04, z = -2.21, yaw = -1.1651 },
    { kind = "tent", what = "tent 2", x = -37.97, y = 23.21, z = -2.27, yaw = -1.3332 },
    { kind = "tent", what = "tent 3", x = -38.01, y = 19.96, z = -2.06, yaw = -1.5045 },
    { kind = "tent", what = "tent 4", x = -37.81, y = 16.68, z = -1.89, yaw = -1.5708 },
    { kind = "tent", what = "small forest tent c", x = -37.83, y = 13.16, z = -1.78, yaw = -1.4685 },
    { kind = "tent", what = "tent 1", x = -41.12, y = 16.26, z = -1.87, yaw = -1.4890 },
    { kind = "tent", what = "tent 2", x = -41.42, y = 13.58, z = -1.79, yaw = -1.4376 },
    { kind = "tent", what = "tent 4", x = -41.10, y = 19.09, z = -2.07, yaw = -1.5598 },
    { kind = "tent", what = "tent 4", x = -41.45, y = 21.75, z = -2.24, yaw = -1.5336 },
    { kind = "prop", what = "bed", x = -41.21, y = 21.70, z = -2.23, yaw = 0.0893 },
    { kind = "prop", what = "bed", x = -40.77, y = 19.07, z = -2.06, yaw = 0.0910 },
    { kind = "prop", what = "bed", x = -40.83, y = 16.25, z = -1.87, yaw = 0.1227 },
    { kind = "prop", what = "bed", x = -40.93, y = 13.22, z = -1.78, yaw = 0.0968 },
    { kind = "prop", what = "bed", x = -37.16, y = 13.52, z = -1.78, yaw = -0.0230 },
    { kind = "prop", what = "bed", x = -37.52, y = 16.63, z = -1.89, yaw = 0.0475 },
    { kind = "prop", what = "bed", x = -37.35, y = 19.76, z = -2.05, yaw = 0.2267 },
    { kind = "prop", what = "bed", x = -37.60, y = 23.19, z = -2.27, yaw = 0.2312 },
    { kind = "prop", what = "bed", x = -34.18, y = 23.95, z = -2.30, yaw = 0.2891 },
    { kind = "prop", what = "bed", x = -33.26, y = 20.90, z = -2.21, yaw = 0.3723 },
    { kind = "prop", what = "bed", x = -32.86, y = 18.04, z = -1.98, yaw = 0.2457 },
    { kind = "prop", what = "bed", x = -32.54, y = 13.90, z = -1.81, yaw = 0.1372 },
    { kind = "tent", what = "campfire only", x = -36.46, y = 26.90, z = -2.21, yaw = -1.2645 },
    { kind = "tent", what = "campfire only", x = -43.45, y = 26.24, z = -2.34, yaw = -1.9319 },
    { kind = "station", what = "supply cart", x = -34.54, y = 31.84, z = -1.98, yaw = -0.3656 },
    { kind = "station", what = "supply cart", x = -32.28, y = 35.68, z = -1.97, yaw = -0.8366 },
    { kind = "station", what = "supply cart", x = -26.83, y = 38.42, z = -1.98, yaw = 1.9889 },
    { kind = "prop", what = "barrel", x = -26.04, y = 37.32, z = -1.93, yaw = 1.6699 },
    { kind = "prop", what = "barrel", x = -31.42, y = 34.39, z = -1.93, yaw = -2.5733 },
    { kind = "prop", what = "barrel", x = -34.30, y = 35.89, z = -2.01, yaw = -1.6845 },
    { kind = "prop", what = "barrel", x = -36.38, y = 31.51, z = -2.03, yaw = -1.1762 },
    { kind = "prop", what = "barrel", x = -35.86, y = 29.37, z = -2.09, yaw = 0.1712 },
    { kind = "prop", what = "beer barrel", x = -36.47, y = 30.59, z = -2.03, yaw = 1.0609 },
    { kind = "prop", what = "beer barrel", x = -33.93, y = 34.65, z = -1.95, yaw = -0.0694 },
    { kind = "prop", what = "beer barrel", x = -27.21, y = 39.02, z = -2.01, yaw = -0.7480 },
    { kind = "prop", what = "arrow barrel", x = -26.78, y = 39.52, z = -2.04, yaw = -0.4740 },
    { kind = "prop", what = "sack_b", x = -26.05, y = 40.12, z = -2.05, yaw = -0.1758 },
    { kind = "prop", what = "sack_b", x = -27.81, y = 39.20, z = -2.03, yaw = -0.9010 },
    { kind = "prop", what = "sack_b", x = -26.84, y = 37.05, z = -1.95, yaw = 0.5700 },
    { kind = "prop", what = "sack_b", x = -27.44, y = 36.99, z = -1.96, yaw = 0.7261 },
    { kind = "prop", what = "sack_b", x = -31.46, y = 34.71, z = -1.93, yaw = -2.7593 },
    { kind = "prop", what = "sack_b", x = -31.02, y = 35.28, z = -1.93, yaw = -2.9766 },
    { kind = "prop", what = "sack_b", x = -31.07, y = 34.77, z = -1.93, yaw = -2.7169 },
    { kind = "prop", what = "sack_b", x = -34.01, y = 31.33, z = -1.99, yaw = -2.8915 },
    { kind = "prop", what = "sack_b", x = -33.55, y = 31.70, z = -1.98, yaw = -3.0034 },
    { kind = "prop", what = "sack_b", x = -35.09, y = 29.64, z = -2.07, yaw = 3.0043 },
    { kind = "prop", what = "sack_pig_feed", x = -35.00, y = 29.06, z = -2.10, yaw = -2.9222 },
    { kind = "prop", what = "sack_pig_feed", x = -36.70, y = 32.79, z = -1.98, yaw = 0.8013 },
    { kind = "prop", what = "sack_pig_feed", x = -34.48, y = 36.66, z = -2.04, yaw = 0.4834 },
    { kind = "prop", what = "sack_pig_feed", x = -26.94, y = 39.94, z = -2.08, yaw = 0.1091 },
    { kind = "prop", what = "sack_pig_feed", x = -27.74, y = 39.74, z = -2.06, yaw = 0.0451 },
    { kind = "station", what = "hunter's spot", x = -13.36, y = 38.64, z = -2.04, yaw = -0.0173 },
    { kind = "station", what = "tavern / inn", x = -22.12, y = 26.86, z = -2.36, yaw = -1.1525 },
    { kind = "station", what = "tavern / inn", x = -40.81, y = 26.96, z = -2.29, yaw = -1.5264 },
    { kind = "attacker", what = "attacker static archer", x = -21.79, y = 2.68, z = -0.05, yaw = -0.1770, group = "sigi" },
    { kind = "attacker", what = "attacker static archer", x = -23.09, y = 1.80, z = -0.04, yaw = -0.8918, group = "sigi" },
    { kind = "attacker", what = "attacker static archer", x = -25.05, y = 0.66, z = -0.05, yaw = -1.6034, group = "sigi" },
    { kind = "barricade", what = "taras (wagon wall) a", x = -21.08, y = 1.40, z = -0.04, yaw = 0.4607 },
    { kind = "barricade", what = "taras (wagon wall) a", x = -24.78, y = 0.02, z = -0.06, yaw = 0.5649 },
    { kind = "barricade", what = "pavise a", x = -22.19, y = 0.75, z = -0.06, yaw = 0.2736 },
    { kind = "barricade", what = "pavise a", x = -23.37, y = 0.60, z = -0.06, yaw = 0.5071 },
    { kind = "barricade", what = "pavise a", x = -25.87, y = -1.22, z = -0.15, yaw = -0.0747 },
}

-- Absolute, not relative: a patrol walks real ground (docs/siege-builder.md).
mercenaries.RaborschPatrols.initial = {
    { name = "patrol1", pts = {
        { x = 1433.59, y = 3897.97, z = 116.30 },
        { x = 1429.96, y = 3906.82, z = 115.14 },
        { x = 1424.41, y = 3912.37, z = 114.62 },
        { x = 1418.58, y = 3916.81, z = 115.08 },
        { x = 1407.71, y = 3921.05, z = 114.86 },
        { x = 1398.48, y = 3918.44, z = 114.57 },
        { x = 1389.57, y = 3912.52, z = 115.72 },
        { x = 1383.47, y = 3907.63, z = 116.05 },
        { x = 1377.85, y = 3900.69, z = 115.88 },
        { x = 1377.50, y = 3891.61, z = 115.69 },
        { x = 1378.46, y = 3885.19, z = 116.16 },
        { x = 1382.75, y = 3878.65, z = 116.37 },
        { x = 1390.41, y = 3876.70, z = 116.35 },
        { x = 1395.79, y = 3874.84, z = 116.30 },
        { x = 1405.39, y = 3875.92, z = 117.95 },
        { x = 1411.05, y = 3878.14, z = 118.33 },
        { x = 1419.56, y = 3886.02, z = 118.05 },
        { x = 1428.66, y = 3891.46, z = 116.34 },
    }},
}

-- ==== the besieging foot ====
-- A wild mix with cumans among them, weighted rather than uniform so Sigismund's men stay the
-- backbone and the rest reads as what a bought army actually looks like.
mercenaries.RaborschFootGroups = {
    "sigi", "sigi", "sigi", "bandit", "bandit", "cuman", "cuman", "knight", "prague", "looter",
}

-- How many foot the besiegers field, as a multiple of the company the player brought. Archers
-- are NOT counted in this - they are placed by the layout and their number is fixed.
mercenaries.RaborschFootRatio = 1.5
mercenaries.RaborschFootMin   = 6
-- 100, not 40. This is the climax and the besiegers should look like an army rather than a
-- raiding party, so the ceiling is high enough that a big company never runs into it. It is
-- still a ceiling: at 1.5x it only bites past a squad of ~66, and it is the one number to
-- lower if the framerate says otherwise.
mercenaries.RaborschFootMax   = 100

-- One in three walks the patrol route; the rest live in the camp.
mercenaries.RaborschPatrolShare = 1 / 3

-- What the camp-dwellers do, the same cycle the bandit camps use.
-- The full camp: they sit, eat, sleep and doze like any other camp.
--
-- This was briefly restricted to standing activities only, on the theory that a seated man
-- could not draw his weapon. That was the wrong diagnosis - the real fault was an empty
-- weapon set (see the DrawAction note in EquipEnemy) - so the variety is back. Setting this
-- true restricts them to standing activities again if it is ever wanted.
mercenaries.RaborschStandingOnly = false
mercenaries.RaborschRolesStanding = { "eat", "herbs", "eat", "herbs", "eat" }
mercenaries.RaborschRolesAll      = { "sit", "eat", "sleep", "snooze", "herbs", "sit", "eat" }

function mercenaries:RaborschRoleList()
    if self.RaborschStandingOnly then return self.RaborschRolesStanding end
    return self.RaborschRolesAll
end

-- How far out the foot are scattered around the besiegers' camp, and where that camp is
-- relative to the site origin (the tents are all in the +y half of the layout).
mercenaries.RaborschCampOffset = { x = -25.0, y = 27.0 }
mercenaries.RaborschCampSpread = 13.0

-- The wall runs right round the fortress, but the assault only happens on the north face
-- (the attackers and their barricades all sit at y >= 0). Towers on the far side are 40-70m
-- behind the fighting with nothing to shoot, so they are dropped rather than spawned: each
-- one is a structure plus an archer plus a Detail slot, spent on a part of the map the player
-- never reaches. Measured from the layout origin, which is the first tower on the north wall.
mercenaries.RaborschTowerRange = 30.0

-- Towers sit a metre low on this ground - the placement snapped them to terrain that falls
-- away under the deck. One number, applied to towers only.
mercenaries.RaborschTowerLift = 1.0

-- The garrison holds a wall for a long time and must not delete the besiegers doing it.
--   * 5x health outright (SetMaxHealth - the same call the contract leaders use).
--   * a defender buff: hlh/slh *0.2 (a fifth of the damage taken, so the 5x reads as 25x
--     staying power against arrows), and marksmanship/rms taken back DOWN, which undoes the
--     marksman buff every static archer otherwise gets and then some.
--   * the weakest arrow in the game rather than the hunting arrow.
-- Between them their output is a fraction of an ordinary archer's. Saying it is exactly a
-- quarter would be a guess: there is no verified "damage dealt x N" buff code - dmd/dmh/drn
-- appear only in MORALE buffs in vanilla, so they are not assumed to be weapon damage.
mercenaries.RaborschDefenderBuff  = "e5a10012-2c4b-4e6a-9f01-000000000012"
mercenaries.RaborschDefenderHealth = 12.0

-- Walk this close to anyone in the siege and the whole thing goes off at once: the besiegers
-- drop whatever they were doing, the archers stop holding fire, and the squad widens its own
-- scan so it joins in rather than trickling into the fight a man at a time.
-- 10 was far too tight, and it was measured off the player alone (see RaborschMonitor,
-- which now watches the whole company).
--
-- Be precise about what SiegePeace actually withholds, because it is NOT "every
-- besieger": SiegeSuppressed only covers entities registered in StaticArchers, i.e. the
-- tower and cart archers. Foot besiegers are in BanditCampActors, and the gate that reads
-- that table only inspects the two bandit-camp-quest slots, never RBQ - so a foot
-- besieger inside the ordinary EnemyScanRadius can be engaged before the alert fires.
-- What the alert really buys is the archers coming off hold-fire, the forced targets,
-- and the wide radius/ceiling - which is still the difference between a battle and a
-- trickle, but it is not a total embargo.
--
-- 60 is EnemyAlertRadius: the siege goes live at exactly the range an alerted squad can
-- already acquire targets, so the fight starts when the men can see something to fight
-- rather than well after. Note the trigger has no line-of-sight test (wall gating is
-- deliberately off during a siege - NavTargetBlocked's RBQ early-out at
-- mercenaries_navmesh.lua:891), so it can fire through terrain; that is acceptable here
-- only because RaborschMonitor runs at all only while the siege is already set up and
-- staged for this quest beat, so there is no "wandered past by accident" case to guard.
mercenaries.RaborschAlertRange = 60.0

-- SwarmCap is 2 - only two mercs may claim any one target - which is right for a roadside
-- scrap and wrong for a battle: with fifty mercs and a handful of enemies in the cache at any
-- moment, most of the squad is turned away at the claim and stands there. Raised for the
-- duration and put back when the siege is struck.
mercenaries.RaborschSwarmCap = 6

-- ...but pinning EffectiveSwarmCap to that flat 6 every tick was the wrong way to do it,
-- and it put back the very bug the elastic cap was written to fix. UpdateEnemyCache
-- recomputes EffectiveSwarmCap from squad size vs visible enemies every 300ms
-- (mercenaries_target_selection.lua) precisely so "a 50-man squad against a handful of
-- enemies could only ever commit 4 men per enemy - everyone past that found every
-- candidate full, kept no target, and held formation". Overwriting that with a constant
-- 6 once a second re-imposed exactly that ceiling for the whole siege, which is the
-- battle where it hurts most.
--
-- So raise the elastic formula's own CEILING for the duration and let it do its job:
-- against a thin line it commits properly, against one straggler it still will not send
-- all fifty. Saved and restored, because these are global tunables the rest of the game
-- keeps using.
mercenaries.RaborschSwarmCapMax  = 10
mercenaries.RaborschSwarmCapHard = 20

function mercenaries:RaborschRaiseSwarmCeiling()
    if self._rabSavedCapMax == nil then
        self._rabSavedCapMax  = self.SwarmCapMax
        self._rabSavedCapHard = self.SwarmCapHard
    end
    self.SwarmCapMax  = self.RaborschSwarmCapMax
    self.SwarmCapHard = self.RaborschSwarmCapHard
    -- Floor the live value too, so the squad does not have to wait out one cache pass
    -- before anyone past the old ceiling is allowed to claim.
    if (self.EffectiveSwarmCap or 0) < self.RaborschSwarmCap then
        self.EffectiveSwarmCap = self.RaborschSwarmCap
    end
end

function mercenaries:RaborschRestoreSwarmCeiling()
    if self._rabSavedCapMax ~= nil then
        self.SwarmCapMax  = self._rabSavedCapMax
        self.SwarmCapHard = self._rabSavedCapHard
        self._rabSavedCapMax, self._rabSavedCapHard = nil, nil
    end
    self.EffectiveSwarmCap = self.SwarmCap
end

-- EnemyAlerted is NOT enough on its own: UpdateEnemyCache recomputes it every 300ms from what
-- it just found, so setting it once is undone almost immediately - the same trap as the LOD
-- boost. The RADIUS is a plain value nothing recalculates, so that is what gets raised, and
-- the flag is re-asserted every tick alongside it. 60m does not cover this battlefield.
mercenaries.RaborschEngageRadius = 160.0

-- The alert cannot be a single pass. A man asleep or sat on a stool is inside a behaviour
-- that only re-reads its Lua on its own cycle, so stripping his role once leaves him where he
-- is until that comes round - which is where the "twenty seconds, and still stragglers" came
-- from. The alert is re-applied every tick for this many ticks (1Hz) instead.
mercenaries.RaborschAlertSweeps = 32
mercenaries.RaborschDefenderAmmo  = "ad6f0f01-aec4-44d1-982c-1210eb01b74a"  -- arrow_normal, the weakest

-- Applied to every archer a defender tower or cart put up. Deferred, because the towers spawn
-- their archers on their own timer - there is nobody to buff at the moment the tower is built.
function mercenaries:RaborschTuneDefenders()
    local S = self.RBQ
    if not S.active then return end
    S.tuned = S.tuned or {}
    local n = 0
    local function once(e)
        if not e then return end
        local k = tostring(e.id or "")
        if k == "" or S.tuned[k] then return end
        if self:RaborschTuneOne(e) then S.tuned[k] = true; n = n + 1 end
    end
    for _, st in ipairs(S.towers or {}) do once(st.archer) end
    for _, st in ipairs(S.carts or {}) do
        for _, a in ipairs(st.archers or {}) do once(a.ent) end
    end
    local total = 0
    for _ in pairs(S.tuned) do total = total + 1 end
    if n > 0 then
        rLog(string.format("garrison: %d new archer(s) tuned, %d of %d tower(s)+cart(s) manned",
                           n, total, #(S.towers or {}) + 3 * #(S.carts or {})))
    end
end

function mercenaries:RaborschTuneOne(ent)
    if not (ent and ent.actor) then return false end
    pcall(function()
        local m = ent.actor:GetMaxHealth()
        if m and m > 0 then
            ent.actor:SetMaxHealth(m * self.RaborschDefenderHealth)
            ent.actor:SetHealth(m * self.RaborschDefenderHealth)
        end
    end)
    pcall(function() ent.soul:AddBuff(self.RaborschDefenderBuff) end)
    -- Top up with the plainest arrow there is, and DO NOT delete what he already has. The
    -- first version stripped every other arrow class first: if the replacement CreateItem
    -- then failed the man was left on his tower with an empty quiver, standing there.
    pcall(function() ent.inventory:CreateItem(self.RaborschDefenderAmmo, 1.0, 60) end)
    return true
end

mercenaries.RBQ = { active = false }

local function fresh()
    mercenaries.RaborschFootKeys = {}
    return { active = false, ents = {}, foot = {}, archers = {}, towers = {}, carts = {},
             seats = {}, beds = {}, spots = {}, roleIdx = {}, nextRotate = {} }
end

function mercenaries:RaborschSquadSize()
    local n = 0
    pcall(function() n = self:BanditCampFollowerCount() or 0 end)
    return n
end

-- The BESIEGERS' archers - the ones who shoot the player - scale too. Nineteen positions are
-- authored along the siege line, and manning all of them is a wall of arrows for someone who
-- turns up with four men: that is the "too difficult" everyone hits. The wall's own defenders are
-- not touched, since they only ever shoot the besiegers.
mercenaries.RaborschArcherRatio = 0.5    -- half the company, archers being worth more than that
mercenaries.RaborschArcherMin   = 4      -- a siege with no archers on it is not a siege

function mercenaries:RaborschArcherCount(slots)
    local n = math.floor(self:RaborschSquadSize() * self.RaborschArcherRatio + 0.5)
    if n < self.RaborschArcherMin then n = self.RaborschArcherMin end
    -- Low spec halves the field. A 190-NPC siege measured 10-15fps on a two-core CPU and the
    -- SAME siege from slightly further away measured 30-50: it is bodies x proximity, and no
    -- LOD, cloth or AI-budget cvar touched it. See EncounterScale.
    if self.ScaleEncounterCount then n = self:ScaleEncounterCount(n) end
    if n > slots then n = slots end
    return n
end

-- WHICH of the authored positions get a man. Spread evenly down the line rather than taken from
-- one end, or half the siege front would stand empty while the other half was shoulder to
-- shoulder. Returns a set of layout-order indices among the attacker rows.
-- A pavise is personal cover; a taras is the wagon wall itself and always stands.
function mercenaries:RaborschIsPavise(row)
    return row.what ~= nil and string.find(tostring(row.what), "pavise", 1, true) ~= nil
end

-- Which pavises still have somebody behind them. Each is matched to the NEAREST authored archer
-- position, and stands only if that position is manned.
function mercenaries:RaborschCoverKeep(layout, manned)
    local slots = {}
    for _, row in ipairs(layout) do
        if row.kind == "attacker" then table.insert(slots, row) end
    end
    local keep, i = {}, 0
    for _, row in ipairs(layout) do
        if row.kind == "barricade" and self:RaborschIsPavise(row) then
            i = i + 1
            local best, bestD
            for n, a in ipairs(slots) do
                local dx, dy = (a.x or 0) - (row.x or 0), (a.y or 0) - (row.y or 0)
                local d = dx * dx + dy * dy
                if not bestD or d < bestD then best, bestD = n, d end
            end
            -- No archer positions at all (should not happen) leaves the cover standing.
            keep[i] = (best == nil) or (manned[best] == true)
        end
    end
    return keep
end

function mercenaries:RaborschArcherKeep(layout)
    local slots = 0
    for _, row in ipairs(layout) do
        if row.kind == "attacker" then slots = slots + 1 end
    end
    local want = self:RaborschArcherCount(slots)
    local keep = {}
    if want >= slots then
        for i = 1, slots do keep[i] = true end
    else
        for i = 1, want do
            local at = math.floor((i - 0.5) * slots / want + 0.5)
            if at < 1 then at = 1 end
            if at > slots then at = slots end
            while keep[at] and at < slots do at = at + 1 end
            while keep[at] and at > 1 do at = at - 1 end
            keep[at] = true
        end
    end
    rLog(string.format("besieger archers: %d of %d position(s) manned (company of %d)",
        want, slots, self:RaborschSquadSize()))
    return keep
end

-- The levy, fielded in INVERSE proportion to the company. A siege against four men was thin
-- once the archers were thinned with them, so the shortfall is made up in bodies rather than by
-- putting the arrows back: unarmoured villagers add weight and pressure without adding threat.
-- Gone entirely by the time the company is big enough to make a real battle on its own.
mercenaries.RaborschRecruitGroup   = "recruit"
mercenaries.RaborschRecruitBase    = 6    -- fielded against a lone player
mercenaries.RaborschRecruitPerMerc = 1.5   -- shed per merc the player brought
mercenaries.RaborschRecruitMin     = 0
mercenaries.RaborschRecruitMax     = 6

function mercenaries:RaborschRecruitCount()
    local n = math.floor(self.RaborschRecruitBase
                         - self:RaborschSquadSize() * self.RaborschRecruitPerMerc + 0.5)
    if n < self.RaborschRecruitMin then n = self.RaborschRecruitMin end
    if n > self.RaborschRecruitMax then n = self.RaborschRecruitMax end
    if self.ScaleEncounterCount then n = self:ScaleEncounterCount(n) end
    return n
end

function mercenaries:RaborschFootCount()
    local n = math.floor(self:RaborschSquadSize() * self.RaborschFootRatio + 0.5)
    if n < self.RaborschFootMin then n = self.RaborschFootMin end
    if n > self.RaborschFootMax then n = self.RaborschFootMax end
    if self.ScaleEncounterCount then n = self:ScaleEncounterCount(n) end
    return n
end

-- ==== placing one layout row ====
-- Resolved against the SIEGE catalogue, because that is what produced the dump: every label
-- in the layout is one of its entries by construction.
function mercenaries:RaborschItemFor(label)
    for _, cat in ipairs(self:SiegeCatalogue() or {}) do
        for _, it in ipairs(cat.items or {}) do
            if it.label == label then return it end
        end
    end
    return nil
end

function mercenaries:RaborschPlaceRow(row, origin)
    local S = self.RBQ
    local it = self:RaborschItemFor(row.what)
    if not it then rLog("unknown piece '" .. tostring(row.what) .. "' - skipped"); return end

    local pos = self:CampSnapToGround({ x = origin.x + row.x, y = origin.y + row.y,
                                        z = origin.z + row.z })
    local yaw = row.yaw or 0

    if row.kind == "tower" then
        -- Far side of the fortress: nothing to shoot and nobody to see it. Skipped.
        local d = math.sqrt(row.x * row.x + row.y * row.y)
        if d > self.RaborschTowerRange then
            S.towersSkipped = (S.towersSkipped or 0) + 1
            return
        end
        pos.z = pos.z + self.RaborschTowerLift

        -- The garrison's own. "wall": they duel the besiegers' ARCHERS and leave the foot to
        -- the swords. On mod_enemies they shot everything that walked up, and every man they hit
        -- turned round and came at the wall - which is why the assault never went anywhere and
        -- the siege played as one long archery duel with the player caught in it.
        local before = #(self.TowerStations or {})
        self:SpawnTowerStation(pos, yaw, { mode = "wall" })
        if #(self.TowerStations or {}) > before then
            table.insert(S.towers, self.TowerStations[#self.TowerStations])
        end

    elseif row.kind == "cart" then
        local before = #(self.ArcherCarts or {})
        self:SpawnArcherCart(pos, yaw, { mode = "wall" })
        if #(self.ArcherCarts or {}) > before then
            table.insert(S.carts, self.ArcherCarts[#self.ArcherCarts])
        end

    elseif row.kind == "attacker" then
        local e = self:SpawnStaticArcher(pos, "besieger", yaw, row.group or "sigi")
        if e then table.insert(S.archers, e.id) end

    elseif it.circle then
        self:RaborschCampCircle(pos, yaw)

    elseif it.fire then
        pcall(function() self:SpawnCampFirePrefab(pos, 0, nil, "RaborschProp_", S.ents) end)

    elseif it.build then
        -- Stations are singletons in the camp; the siege builder's own workaround applies.
        pcall(function() self:SiegeBuildStation(it, pos, yaw) end)

    elseif it.stash then
        pcall(function()
            local e = System.SpawnEntity({
                class = "Stash", name = "RaborschChest_" .. tostring(math.random(100000, 999999)),
                position = pos, orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
                properties = { object_Model = it.stash, bSaved_by_game = false },
            })
            if e then
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)
                table.insert(S.ents, e.id)
            end
        end)

    elseif it.so then
        -- Usable furniture joins the pools the camp behaviours draw on, so the besiegers
        -- actually sit on the stools and sleep in the beds the layout put down.
        local wuid, soPos = self:SpawnCampFurnitureSO(it.model, pos, yaw, "RaborschFurn",
                                                      it.so, nil, S.ents)
        if wuid then
            if it.so == self.CampBedSO then
                table.insert(S.beds, { wuid = wuid, pos = soPos })
            else
                table.insert(S.seats, { wuid = wuid, pos = soPos, firePos = origin })
            end
        end

    elseif it.model then
        self:SpawnCampPropModel(it.model, pos, yaw, "RaborschProp", S.ents)
        if it.light then
            pcall(function()
                local e = System.SpawnEntity({
                    class = "Light",
                    name = "RaborschLight_" .. tostring(math.random(100000, 999999)),
                    position = { x = pos.x, y = pos.y, z = pos.z + (it.lightZ or 1.0) },
                    properties = it.light,
                })
                if e then table.insert(S.ents, e.id) end
            end)
        end
    end
end

-- The one-click camp circle, replayed. Same maths as the builder's, which is the merc camp's.
function mercenaries:RaborschCampCircle(pos, yaw)
    local S = self.RBQ
    pcall(function() self:SpawnCampFirePrefab(pos, 0, nil, "RaborschProp_", S.ents) end)

    local seat = self.CampModels and self.CampModels.Log
    if seat then
        for k = 1, self.SiegeCircleSeats do
            local a = (k / self.SiegeCircleSeats) * math.pi * 2
            local sp = self:CampSnapToGround({ x = pos.x + math.cos(a) * self.SiegeCircleSeatR,
                                               y = pos.y + math.sin(a) * self.SiegeCircleSeatR,
                                               z = pos.z })
            local wuid, soPos = self:SpawnCampFurnitureSO(seat, sp, a + math.pi, "RaborschSeat",
                                                          self.CampChairSO, nil, S.ents)
            if wuid then table.insert(S.seats, { wuid = wuid, pos = soPos, firePos = pos }) end
        end
    end

    local tents = self.CampTentVariants or {}
    local bed   = self.CampModels and self.CampModels.Bed
    for k = 1, self.SiegeCircleTents do
        local tp, ringAngle = self:CampRingPos(pos, self.CampTentRingRadius, k,
                                               self.CampClusterTentRingSlots, yaw)
        tp = self:CampSnapToGround(tp)
        local tAngle = ringAngle + math.pi + self.CampTentFacingFix
        if #tents > 0 then
            self:SpawnCampPropModel(tents[math.random(#tents)], tp, tAngle, "RaborschProp", S.ents)
        end
        if bed then
            local bp, bAngle = self:CampRelativeOffset(tp, tAngle, self.CampBedOffset)
            bp = self:CampSnapToGround(bp)
            local wuid, soPos = self:SpawnCampFurnitureSO(bed, bp, bAngle, "RaborschBed",
                                                          self.CampBedSO, nil, S.ents)
            if wuid then table.insert(S.beds, { wuid = wuid, pos = soPos }) end
        end
    end
end

-- ==== the men ====
-- Two thirds live in the camp (sit, eat, sleep, snooze, gather); one third walks the route.
-- Roles come from the SAME WUID-keyed tables the bandit camps and the merc camp use, so
-- camp_actor fires for them without a line of new behaviour-tree work (docs/ai-modules.md).
function mercenaries:RaborschSpawnFoot(origin)
    local S = self.RBQ
    local soldiers = self:RaborschFootCount()
    local recruits = self:RaborschRecruitCount()
    local total = soldiers + recruits
    local walkers = math.max(1, math.floor(total * self.RaborschPatrolShare + 0.5))
    local campers = total - walkers

    local camp = self:CampSnapToGround({ x = origin.x + self.RaborschCampOffset.x,
                                         y = origin.y + self.RaborschCampOffset.y,
                                         z = origin.z })

    local route = self.RaborschPatrols.initial and self.RaborschPatrols.initial[1]
    local pts = route and route.pts or {}

    for i = 1, total do
        -- The levy comes last, so the soldiers take the camp places and the recruits fill out
        -- the patrol - which is where a body without armour is most use and least of a problem.
        local grp
        if i > soldiers then
            grp = self.RaborschRecruitGroup
        else
            grp = self.RaborschFootGroups[math.random(#self.RaborschFootGroups)]
        end
        local isWalker = (i > campers)

        local pos, yaw
        if isWalker and #pts > 0 then
            -- Spread along the route rather than bunched at its head: each man starts at his
            -- own point, so the patrol is strung right round the perimeter from the off.
            local at = (((i - campers - 1) * math.floor(#pts / math.max(1, walkers))) % #pts) + 1
            local p = pts[at]
            pos, yaw = self:CampSnapToGround({ x = p.x, y = p.y, z = p.z }), math.random() * math.pi * 2
        else
            local a = math.random() * math.pi * 2
            local r = math.sqrt(math.random()) * self.RaborschCampSpread
            pos = self:CampSnapToGround({ x = camp.x + math.cos(a) * r,
                                          y = camp.y + math.sin(a) * r, z = camp.z })
            yaw = math.random() * math.pi * 2
        end

        local ent = self:SpawnEnemyAt(grp, false, pos, yaw)
        if ent then
            table.insert(S.foot, ent.id)
            local wuid = XGenAIModule.GetMyWUID(ent)
            if wuid then
                local ws = tostring(wuid)
                local ws2 = ent.this and tostring(ent.this.id) or ws
                -- Remembered under both keys, so RaborschIsFighting answers for either.
                self.RaborschFootKeys[ws] = true
                self.RaborschFootKeys[ws2] = true
                -- Reuse the bandit-camp actor set: it is what BanditCampSuppressed and the
                -- enemy schedulers' camp_actor arm both key off.
                self.BanditCampActors[ws] = true
                S.spots[ws] = { actPos = pos, firePos = camp }

                if isWalker and #pts > 0 then
                    local wps = {}
                    for k = 1, #pts do
                        local at = (((i - campers - 1) * 3 + k - 1) % #pts) + 1
                        table.insert(wps, { x = pts[at].x, y = pts[at].y, z = pts[at].z })
                    end
                    S.spots[ws].patrol = wps
                    self.CampPatrollers[ws] = { waypoints = wps, index = 1, foreign = true }
                    if ws2 ~= ws then
                        S.spots[ws2] = S.spots[ws]
                        self.CampPatrollers[ws2] = self.CampPatrollers[ws]
                        self.BanditCampActors[ws2] = true
                    end
                else
                    if ws2 ~= ws then S.spots[ws2] = S.spots[ws]; self.BanditCampActors[ws2] = true end
                    local roles = self:RaborschRoleList()
                    self:RaborschApplyRole(ws, roles[(i % #roles) + 1])
                    if ws2 ~= ws then
                        self:RaborschApplyRole(ws2, roles[(i % #roles) + 1])
                    end
                end
            end
        end
    end
    rLog(string.format("%d foot: %d in camp, %d on patrol (squad of %d x %.1f, %d soldier(s) + %d recruit(s))",
        total, campers, walkers, self:RaborschSquadSize(), self.RaborschFootRatio, soldiers, recruits))
end

-- The bandit camp's ApplyBanditCampRole, against this siege's own pools.
function mercenaries:RaborschApplyRole(ws, role)
    local S = self.RBQ
    local s = S.spots and S.spots[ws]
    if not s then return end

    self.CampFurniture[ws]  = nil
    self.CampActivities[ws] = nil
    if role ~= "sit" and role ~= "snooze" then self:ReleaseSpot(S.seats or {}, ws) end
    if role ~= "sleep" then self:ReleaseSpot(S.beds or {}, ws) end

    local from = s.lastPos or s.actPos

    if role == "sleep" then
        local bed = self:ClaimSpot(S.beds or {}, ws, from)
        if bed then
            self.CampFurniture[ws] = { wuid = bed.wuid, kind = "bed", pos = bed.pos }
            s.lastPos = bed.pos
        end
    elseif role == "sit" then
        local seat = self:ClaimSpot(S.seats or {}, ws, from)
        if seat then
            self.CampFurniture[ws] = { wuid = seat.wuid, kind = "chair", pos = seat.pos,
                                       facePos = seat.firePos }
            s.lastPos = seat.pos
        end
    elseif role == "snooze" then
        local seat = self:ClaimSpot(S.seats or {}, ws, from, true)
        if seat then
            self.CampActivities[ws] = { unstance = "camper_snooze", mode = 1, pos = seat.pos,
                                        locWuid = seat.wuid, facePos = seat.firePos }
            s.lastPos = seat.pos
        end
    elseif role == "eat" then
        self.CampActivities[ws] = { unstance = "eating_standing", mode = 2, pos = s.actPos,
                                    facePos = s.firePos }
        s.lastPos = s.actPos
    elseif role == "herbs" then
        self.CampActivities[ws] = { unstance = "PickingHerbsNPC", mode = 2, pos = s.actPos,
                                    facePos = s.firePos }
        s.lastPos = s.actPos
    end
end

-- ==== raise and strike ====
function mercenaries:SpawnRaborsch()
    if self.RBQ.active then rLog("already standing - merc_raborsch_clear first"); return end
    self.RBQ = fresh()
    local S = self.RBQ
    S.active = true

    local site = self.RaborschSite
    local origin = { x = site.x, y = site.y, z = site.z }

    -- Nobody fights while it is being built. Released at the end, once everyone is placed -
    -- otherwise the first archer up starts shooting the last one being spawned.
    self.SiegePeace = true

    -- The advanced LOD keeps this many NPCs actually rendered instead of popping out at
    -- middling range, which is the difference between a siege and an empty field with sounds.
    -- PINNED, not merely switched on: LodBoostTick would otherwise turn it off again within
    -- the second, because it sizes the crowd from CachedEnemies - built around the player and
    -- excluding everyone suppressed, which during the build is every archer on the field.
    pcall(function() if self.LodBoostPin then self:LodBoostPin(true, "siege") end end)

    local layout = self.RaborschLayouts[site.layout] or {}
    local manned, seen = self:RaborschArcherKeep(layout), 0
    local cover = self:RaborschCoverKeep(layout, manned)
    local pavise = 0
    for _, row in ipairs(layout) do
        local place = true
        if row.kind == "attacker" then
            seen = seen + 1
            place = (manned[seen] == true)
        elseif row.kind == "barricade" and self:RaborschIsPavise(row) then
            -- A pavise is one archer's own shield. With his position unmanned it is a board
            -- propped in a field, and the siege line reads as abandoned rather than thinned.
            -- The tarases stay: those are the wall of wagons, not personal cover.
            pavise = pavise + 1
            place = (cover[pavise] == true)
        end
        if place then pcall(function() self:RaborschPlaceRow(row, origin) end) end
    end
    rLog(string.format("layout: %d row(s), %d tower(s) (%d far ones skipped), %d cart(s), %d archer(s), %d seat(s), %d bed(s)",
        #layout, #S.towers, S.towersSkipped or 0, #S.carts, #S.archers, #S.seats, #S.beds))

    self:RaborschSpawnFoot(origin)

    -- Pin every man's OWN view distance. The LOD cvars are global and an NPC's own
    -- ViewDistRatio gates him regardless of them - see LodPinEntity.
    local pinned = 0
    for _, id in ipairs(S.foot or {}) do
        local e = System.GetEntity(id)
        if e and self:LodPinEntity(e) then pinned = pinned + 1 end
    end
    for _, id in ipairs(S.archers or {}) do
        local e = System.GetEntity(id)
        if e and self:LodPinEntity(e) then pinned = pinned + 1 end
    end
    pcall(function() pinned = pinned + (self:LodPinAllMercs() or 0) end)
    rLog("view distance pinned on " .. pinned .. " NPC(s)")

    -- Let them at each other. The towers spawn their archers on a delay, so this waits for
    -- the last of them rather than firing while half the wall is still empty.
    -- Both deferred past the towers' own archer timers: there is nobody up there yet.
    Script.SetTimerForFunction(5000, "mercenaries.RaborschTuneDelayed")
    Script.SetTimerForFunction(6000, "mercenaries.RaborschRelease")
    rLog("siege raised - everyone holds until the towers are manned")
end

-- Everything goes live at once. Called on proximity, and by merc_raborsch_go.
function mercenaries:RaborschAlert(why)
    local S = self.RBQ
    if not S.active or S.alerted then return end
    S.alerted = true

    -- Archers first: this is the flag they hold fire behind.
    self.SiegePeace = false

    self:RaborschEngageAll()
    rLog("ALERT (" .. tostring(why) .. ") - the siege turns on the player")
end

-- Strip camp roles and hand out targets. Idempotent, and run every tick for the first
-- RaborschAlertSweeps seconds so late-waking men are caught too.
function mercenaries:RaborschEngageAll(quiet)
    local S = self.RBQ
    local n = 0
    for _, id in ipairs(S.foot or {}) do
        pcall(function()
            local e = System.GetEntity(id)
            local w = e and XGenAIModule.GetMyWUID(e)
            if w then
                -- EVERYBODY, patrollers included, and under BOTH keys. IsCampActor reads
                -- these tables with entity.this.id; they were written with GetMyWUID. Clearing
                -- only one of the two leaves camp_actor holding the interrupt slot, and the
                -- man stands in the open being hit without ever entering combat.
                for _, ws in ipairs({ tostring(w), e.this and tostring(e.this.id) or nil }) do
                    self.CampFurniture[ws]  = nil
                    self.CampActivities[ws] = nil
                    self.CampPatrollers[ws] = nil
                    self.BanditCampActors[ws] = nil
                end
                n = n + 1
            end
        end)
    end

    -- Every besieger gets a target handed to him. Left to their own scan (50m, centred on
    -- themselves) the men at the far end of the camp and the patrol never see anyone and
    -- simply carry on - which is what "only half of them engaged" was. ForcedTargetOf is the
    -- documented control point and FindEnemyTarget honours it ahead of its own scanning.
    -- ONE shared target for the whole force, which is exactly what PatrolAlert does and why
    -- the roaming gangs react so well. Round-robin across fifty marks was tried here and is
    -- worse in practice: each man paths at a different, moving merc, so nobody converges and
    -- the assault dribbles in. They will re-target normally once they are in among the squad.
    local tgt0
    pcall(function() tgt0 = player and player.this and player.this.id end)
    if tgt0 then
        for _, id in ipairs(S.foot or {}) do
            pcall(function()
                local e = System.GetEntity(id)
                if e then
                    local tgt = tgt0
                    -- Under BOTH keys. enemy_melee_scheduler.xml calls FindEnemyTarget with
                    -- entity.this.id; GetMyWUID is what the camp tables use. They coincide for
                    -- these NPCs today, and writing both costs nothing if that ever changes.
                    if e.this and e.this.id then self.ForcedTargetOf[tostring(e.this.id)] = tgt end
                    local w = XGenAIModule.GetMyWUID(e)
                    if w then self.ForcedTargetOf[tostring(w)] = tgt end
                    -- Besiegers are NPCs too: pin their view distance like everything else.
                    pcall(function() if self.LodPinEntity then self:LodPinEntity(e) end end)
                end
            end)
        end
    end

    -- And the squad: EnemyAlerted widens their sweep from EnemyScanRadius to EnemyAlertRadius,
    -- and the swarm cap comes off so the whole company can pile in instead of two men per foe.
    self.EnemyAlerted = true
    self:RaborschRaiseSwarmCeiling()
    self._rabSavedAlertR = self._rabSavedAlertR or self.EnemyAlertRadius
    self.EnemyAlertRadius = self.RaborschEngageRadius
    pcall(function() self._lodLastFoeAt = System.GetCurrTime() end)

    if not quiet then
        rLog(n .. " besieger(s) off duty, archers free")
    end
end

-- 1Hz from the main loop. Cheap: it stops at the first man inside the range.
function mercenaries:RaborschMonitor()
    local S = self.RBQ
    if not S.active then return end

    -- Already fighting: hold the squad's targeting open. UpdateEnemyCache recomputes
    -- EnemyAlerted from its own findings every pass, so without this the sweep collapses back
    -- to EnemyScanRadius (18m) between ticks and most of the company stops seeing the battle.
    if S.alerted then
        self.EnemyAlerted = true
        self.EnemyAlertRadius = self.RaborschEngageRadius
        self:RaborschRaiseSwarmCeiling()
        -- Keep sweeping up the stragglers for a while: anyone whose behaviour had not come
        -- round yet on the first pass gets stripped and re-pointed on the next.
        S.alertSweeps = (S.alertSweeps or 0) + 1
        if S.alertSweeps <= self.RaborschAlertSweeps then
            self:RaborschEngageAll(true)
            -- LodRatioAutoApply already re-bands itself when the crowd moves between bands.
            -- Clearing _lodRatioBand here forced a full re-apply EVERY tick, which is exactly
            -- the continuous rescaling that causes pop-in.
            pcall(function() self:LodRatioAutoApply() end)
        end
        return
    end
    if not player then return end
    local p
    pcall(function() p = player:GetWorldPos() end)
    if not p then return end

    -- WHOSE approach counts. Testing the player alone is the same "wrong body's
    -- position" defect NavSuppressFormation had: a company could be standing among the
    -- besiegers with the siege still asleep, because the man the check cared about was
    -- fifty metres back. Any merc walking into it sets it off too. Positions come from
    -- the PerfPos cache (refreshed every 50ms), so this stays a handful of subtractions
    -- at 1Hz - the cost here has always been the GetEntity/GetWorldPos per besieger,
    -- which is unchanged and now done once per besieger rather than once per watcher.
    local watchers = { p }
    for _, ent in pairs(self.ActiveMercs or {}) do
        local w = ent and (ent.this and ent.this.id or ent.id)
        local mp = w and self:PerfMercPos(w) or nil
        if mp then watchers[#watchers + 1] = mp end
    end

    local r2 = self.RaborschAlertRange * self.RaborschAlertRange
    local function near(id)
        local e = System.GetEntity(id)
        if not e then return false end
        local q
        pcall(function() q = e:GetWorldPos() end)
        if not q then return false end
        for _, w in ipairs(watchers) do
            local dx, dy, dz = q.x - w.x, q.y - w.y, q.z - w.z
            if (dx * dx + dy * dy + dz * dz) <= r2 then return true end
        end
        return false
    end

    for _, id in ipairs(S.foot or {}) do
        if near(id) then self:RaborschAlert("the company came within " ..
            string.format("%.0fm", self.RaborschAlertRange)); return end
    end
    for _, id in ipairs(S.archers or {}) do
        if near(id) then self:RaborschAlert("the company reached the barricades"); return end
    end
end

-- Re-run for a while. Towers put their archers up on staggered timers of their own, so one
-- pass at five seconds found three of fourteen and left the rest at stock health with the
-- marksman buff still on them.
function mercenaries.RaborschTuneDelayed()
    local self = mercenaries
    local S = self.RBQ
    if not S.active then return end
    pcall(function() self:RaborschTuneDefenders() end)
    S.tuneRuns = (S.tuneRuns or 0) + 1
    if S.tuneRuns < 15 then
        Script.SetTimerForFunction(2000, "mercenaries.RaborschTuneDelayed")
    end
end

-- The build-time hold only. Everything ELSE that has to happen when the fight starts is in
-- RaborschAlert, which this does not do - the men keep their camp roles until the player is
-- actually near, so the siege can be walked up to and looked at first.
function mercenaries.RaborschRelease()
    local self = mercenaries
    if not self.RBQ.active then return end
    self.SiegePeace = false
    rLog("the siege is live - the two lines may shoot each other now")
end

function mercenaries:DespawnRaborsch()
    local S = self.RBQ
    if not S.active then rLog("nothing standing"); return end

    for _, st in ipairs(S.towers or {}) do pcall(function() self:TowerStationClearOne(st) end) end
    for _, st in ipairs(S.carts or {}) do pcall(function() self:ArcherCartClearOne(st) end) end

    for _, id in ipairs(S.archers or {}) do
        pcall(function()
            local e = System.GetEntity(id)
            if e then self:RemoveStaticArcher(e) end
        end)
        pcall(function() System.RemoveEntity(id) end)
    end

    for _, id in ipairs(S.foot or {}) do
        pcall(function()
            local e = System.GetEntity(id)
            local w = e and XGenAIModule.GetMyWUID(e)
            if w then self:ClearBanditCampActor(tostring(w)) end
        end)
        pcall(function() System.RemoveEntity(id) end)
    end

    for _, id in ipairs(S.ents or {}) do pcall(function() System.RemoveEntity(id) end) end

    self.SiegePeace = false
    -- Hand the squad's targeting rules back, and release every forced target.
    self:RaborschRestoreSwarmCeiling()
    if self._rabSavedAlertR then
        self.EnemyAlertRadius, self._rabSavedAlertR = self._rabSavedAlertR, nil
    end
    for _, id in ipairs(S.foot or {}) do
        pcall(function()
            local e = System.GetEntity(id)
            local w = e and XGenAIModule.GetMyWUID(e)
            if w and self.ForcedTargetOf then self.ForcedTargetOf[tostring(w)] = nil end
        end)
    end
    pcall(function() if self.LodBoostPin then self:LodBoostPin(false) end end)
    pcall(function() if self.LodBoostOff then self:LodBoostOff() end end)
    self.RBQ = fresh()
    rLog("siege struck")
end

-- Why is a defender not shooting? There are only a few possible answers and this prints all
-- of them per archer: whether he exists, whether he has ammo, what mode he is in, whether the
-- targeting layer has given him a target, and how far the nearest besieger is.
-- The besiegers' half of the same question: is this man in combat, or is he still a camp
-- actor standing in the middle of a battle? Prints what IsCampActor sees for BOTH keys.
-- True for a besieger while the siege is alerted. Kept as a set so IsCampActor - which runs
-- for every camp NPC every cycle - stays an O(1) lookup.
mercenaries.RaborschFootKeys = {}

function mercenaries:RaborschIsFighting(wuid)
    local S = self.RBQ
    if not (S and S.active and S.alerted) then return false end
    return self.RaborschFootKeys[tostring(wuid)] == true
end

function mercenaries:RaborschBesiegers()
    local S = self.RBQ
    if not S.active then rLog("nothing standing"); return end
    local alive, actors, targeted, forced = 0, 0, 0, 0
    local shown = 0
    for _, id in ipairs(S.foot or {}) do
        local e = System.GetEntity(id)
        if e and self:IsAliveAndWell(e, true) then
            alive = alive + 1
            local w  = XGenAIModule.GetMyWUID(e)
            local k1 = w and tostring(w) or "?"
            local k2 = e.this and tostring(e.this.id) or "?"
            local isActor = false
            pcall(function()
                isActor = self:IsCampActor(k1) or self:IsCampActor(k2)
            end)
            local tgt = (self.EnemyTargetOf and (self.EnemyTargetOf[k1] or self.EnemyTargetOf[k2])) ~= nil
            local fc  = (self.ForcedTargetOf and (self.ForcedTargetOf[k1] or self.ForcedTargetOf[k2])) ~= nil
            if isActor then actors = actors + 1 end
            if tgt then targeted = targeted + 1 end
            if fc then forced = forced + 1 end
            if shown < 6 then
                rLog(string.format("  keysMatch=%s campActor=%s target=%s forced=%s",
                     tostring(k1 == k2), tostring(isActor), tostring(tgt), tostring(fc)))
                shown = shown + 1
            end
        end
    end
    rLog(string.format("besiegers: %d alive, %d STILL camp actors, %d with a target, %d forced",
                       alive, actors, targeted, forced))
    rLog("  campActor=true during a fight means camp_actor still holds the interrupt slot")
    rLog("  keysMatch=false means GetMyWUID and this.id differ - the camp tables need both")
end

function mercenaries:RaborschDefenders()
    local S = self.RBQ
    if not S.active then rLog("nothing standing"); return end

    local foes = {}
    for _, id in ipairs(S.foot or {}) do
        local e = System.GetEntity(id)
        if e and self:IsAliveAndWell(e, true) then
            local q; pcall(function() q = e:GetWorldPos() end)
            if q then table.insert(foes, q) end
        end
    end

    local function report(ent, what)
        if not ent then rLog("  " .. what .. ": NO ARCHER (the tower never manned it)"); return end
        local ws = tostring(ent.this and ent.this.id or ent.id)
        local rec = self.StaticArchers and self.StaticArchers[ws]
        local ammo, tgt, near = 0, "none", -1
        pcall(function()
            for _, cls in ipairs(self.ArcherArrowClasses or {}) do
                ammo = ammo + (ent.inventory:GetCountOfClass(cls) or 0)
            end
        end)
        pcall(function() tgt = tostring(self.StaticArcherTargetOf[ws]) end)
        pcall(function()
            local mp = ent:GetWorldPos()
            for _, q in ipairs(foes) do
                local d = math.sqrt((q.x-mp.x)^2 + (q.y-mp.y)^2 + (q.z-mp.z)^2)
                if near < 0 or d < near then near = d end
            end
        end)
        rLog(string.format("  %-7s mode=%-11s ammo=%-4d target=%-10s nearest foe=%.0fm",
            what, tostring(rec and rec.mode or "NO RECORD"), ammo,
            (tgt == "nil") and "none" or "yes", near))
    end

    rLog("defenders (" .. #foes .. " besieger(s) alive, range " ..
         tostring(self.StaticArcherRange) .. "m, peace=" .. tostring(self.SiegePeace) .. "):")
    for i, st in ipairs(S.towers or {}) do report(st.archer, "tower" .. i) end
    for i, st in ipairs(S.carts or {}) do
        for j, a in ipairs(st.archers or {}) do report(a.ent, "cart" .. i .. "." .. j) end
    end
    rLog("  mode must be mod_enemies; ammo 0 = he cannot shoot; target none with a foe")
    rLog("  inside range = the targeting layer is refusing him, not the archer")
end

function mercenaries:RaborschStatus()
    local S = self.RBQ
    if not S.active then rLog("not standing"); return end
    rLog(string.format("standing: %d foot, %d attacker archer(s), %d tower(s), %d cart(s)",
        #(S.foot or {}), #(S.archers or {}), #(S.towers or {}), #(S.carts or {})))
    rLog(string.format("seats %d, beds %d, peace %s",
        #(S.seats or {}), #(S.beds or {}), tostring(self.SiegePeace)))
end

mercenaries:DevCommand("merc_raborsch_besiegers", "mercenaries:RaborschBesiegers()", "Are the besiegers in combat, or still camp actors?")
mercenaries:DevCommand("merc_raborsch_defenders", "mercenaries:RaborschDefenders()", "Why each defender archer is or is not shooting")
mercenaries:DevCommand("merc_raborsch_status", "mercenaries:RaborschStatus()", "What is standing")
mercenaries:DevCommand("merc_raborsch_go",     "mercenaries.RaborschRelease()","Let the two lines shoot, without waiting")
mercenaries:DevCommand("merc_raborsch_alert",  "mercenaries:RaborschAlert('console')", "Set the whole siege on the player now")

-- ---------------------------------------------------------------------------
-- LOAD RESET.
--
-- The siege reaches into three pieces of GLOBAL state - SiegePeace (which makes IsValidEnemy
-- refuse every suppressed actor), EnemyAlertRadius (18m -> 160m, the widest sweep in the mod)
-- and the swarm ceiling - and it puts all three back on exactly one path: RaborschStrike.
-- Every other way a siege can end leaves them set, and they are plain Lua, so they outlive
-- the level. Loading a save from before the siege is the ordinary way to hit that: the siege
-- is gone from the world and the 160m sweep is still running, three times a second, wherever
-- the player goes next.
--
-- Released unconditionally here rather than conditionally, because it is self-healing in one
-- direction only: RaborschMonitor re-forces all three at 1Hz while the siege is genuinely
-- still standing and alerted, so a real siege loses them for at most a tick.
function mercenaries:RaborschOnLoad()
    self.SiegePeace = false
    if self._rabSavedAlertR then
        self.EnemyAlertRadius, self._rabSavedAlertR = self._rabSavedAlertR, nil
    end
    self:RaborschRestoreSwarmCeiling()
    -- The RECORD dies with the load too. RBQ is plain Lua, so it outlives the level -
    -- but the siege's entities do not, and this used to keep active=true across a load.
    -- SpawnRaborsch's "already standing" guard then refused to rebuild for the rest of
    -- the session: the player walked up to an EMPTY castle, and the death-checks read
    -- the zero-man "siege" as a victory. The global load sweep (RebuildMercCache,
    -- SpawnedEnemy_* prefixes) removes whatever men the save serialised; this drops the
    -- bookkeeping to match. The quest's wake token re-issues the spawn if beat 8 is live.
    self.RBQ = { active = false }
    self.RaborschFootKeys = {}
end
