Kingdom Come: Deliverance - Mercenaries Mod

A companion mod for Kingdom Come: Deliverance that enables the player to hire, command, and fight alongside NPC mercenaries.

Features
- Hire mercenaries of varying combat tiers.
- Issue basic commands (Follow, Wait, Dismiss).
- Automated combat engagement and target selection.
- Persistent state saving (squad composition and outfits are saved to the game file).
- Multi-language localization.

Building and Releasing
- PackageMod.bat builds the mod into the game's Mods folder (release exe, logs nothing).
- PackageModDev.bat does the same but launches the dev exe, which writes kcd.log.
- PackageRelease.bat produces the single release ZIP: release/mercenaries.zip.

There is **one** build. It ships with voicelines and a companion limit of 50. The mod used
to ship three ZIPs - regular (limit 6), UNLIMITED (999) and NOVOICELINES - which meant three
things to test and an easy way for a player to download the wrong one.

The limit lives in the source, not the packager: mercenaries.MaxCompanions in
data/Scripts/mods/mercenaries.lua. Changing it means regenerating the formation ladder in
data/AI/FormationDefinitions.xml to match - mercenaries.FormationSizes must top out at the
new limit, or squads above the largest template share too few engine spots.

Repository Structure
- /data/ - Core mod files, including Lua scripts, AI Behavior Trees, and Skald XML databases.
- /localization/ - UI and dialogue translation files.
- /docs/ - Documentation and research data regarding the game's engine and API.
- /tools/ - Utility scripts, including FFmpeg batch files for processing custom voiceover audio.
