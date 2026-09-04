# Release notes

Paste-ready for the mod page. Version 2.0, matching `mod.manifest`.

---

## 2.0 — The company goes to war

The biggest update the mod has had. Your mercenaries are no longer just an escort: they have
a camp that runs while you are away, a quartermaster who employs them, contracts to fulfil,
walls to defend and a siege to fight.

### Camp

- **A camp your company lives in.** Pitch it anywhere; the men sit, eat, sleep, drink, spar,
  sharpen their swords and talk to each other. It survives saving and reloading.
- **The quartermaster** — an immortal camp NPC who is the interface for the whole management
  layer: wages, supplies, upgrades, contracts, difficulty, and deploying part of the company
  while the rest holds the camp.
- **Logistics.** Food, drink, wages, tiredness and morale run continuously. Well-fed, paid
  men fight better; starved, unpaid men do not. The company's state is mirrored on your own
  HUD as status icons (`merc_status_icons 0` to turn them off).
- **Upgrades** bought from the quartermaster: smithy with a working forge, alchemy bench,
  hunting station, tavern, practice yard, player house, palisade walls, gates, watchtowers
  and archer carts. Each claims a spot on the camp grid, and the whole camp rebuilds itself
  on load.

### War

- **Camp raids.** Bandits come for your palisade. They form up out of sight, march on a gap
  in your wall, and your men marshal to meet them there. A shut gate calls the raid off.
- **The siege of Raborsch** — a full set-piece: defender towers and archer carts on the
  walls, an attacking army with its own archery line, barricades and patrols, all scaled to
  the company you brought with you.
- **The Kleinkrieg contract chain**, issued and voiced by the quartermaster, plus a
  **repeatable bounty**: clear a bandit camp for coin, over and over.
- **Roaming patrols and road ambushes** populate the map between jobs, with per-route
  escalation as you keep killing them.
- **Six enemy groups** replace the old renegades: looters, bandits, Sigismund's soldiers, the
  Prague regiment, Cumans and Sigismund's knights, each with their own gear, souls and tier
  spread — plus Heinrich, an overpowered champion, for when you want a real fight.
- **Difficulty tiers** — easy, medium, difficult, extreme, impossible, horde — scaling how
  many enemies every encounter fields and how well armoured they are.

### Command

- **Seven formations**: column, line, square, wedge, circle, escort and the stock game
  preset, with rigid, relaxed and follow-my-path modes. Mounted formations included.
- **Four engagement stances**: attack on sight, fight whoever fights you, defend only, hold
  fire. Set by talking to a mercenary or from the console.
- **Hold this ground**, **escort a person**, and **call a target** the whole company
  converges on.
- **The silent order wheel** — look at a mercenary and the menu opens with no camera cut and
  no spoken line.
- Mounted mercenaries keep up properly, and dismount to fight when a fight starts.

### The company

- **Up to 50 men**, foot and archers.
- **Archers** as a separate combat group with their own AI and three stances: skirmish, close
  to melee, or stand and shoot. Bow, crossbow or hand cannon.
- **The custom uniform** — drop a set of gear in a chest and the whole company wears a copy
  of it, anywhere, camp or no camp.
- **43 named companions** cloned from vanilla characters, recruitable individually.
- **462 outfit presets** across 17 styles - free company, bandits, Cumans and thirteen
  liveries from Leipa to the papal legate - balanced so every style is equally tough at a
  given tier.
- **Post-battle loot sweep** — the men wander the corpses and rummage after a fight.

### Fixes

- **Mercenaries no longer ignore enemy archers.** A rule meant to stop footmen walking
  uselessly to the base of a watchtower was refusing *every* static archer, so at the siege
  of Raborsch the whole company left the attacking archery line alone. Only genuinely
  out-of-reach archers — on a tower deck or a cart bed — are archer-business now.
- **A part-company sortie forms up properly.** Taking only some of the men out of camp via the
  quartermaster left the party with no working formation — they trailed the player in a clump
  while a full deploy worked fine. Three separate causes, all on that one path: the deployed men
  were still flagged as busy with camp chores, so the formation anchored on a man who could not
  walk yet and re-elected him every tick; their camp behaviour was never actually cancelled, so
  the order to fall in was swallowed; and with a palisade up, the rule that keeps men from
  pathing through your own wall was also suppressing the anchor, which switches the formation off
  for everyone. Standing "hold" and "wait" orders are cleared on deploy now, too.
- **A company marching out of a walled camp keeps its formation.** The rule that stops men
  being steered through your own palisade was applied out to 60 m from the camp centre — far
  wider than any camp — so a sortie leaving a walled camp spent its first 75 m in a shapeless
  chain. It is now sized to the actual wall, and men on the same side of it as the squad's
  anchor are not affected at all.
- **Big squads settle into their column instead of churning.** The check that re-issues a
  follow order to men who have stopped moving treated anyone more than 22 m away as stuck —
  but a forty-man column is 36 m deep, so its whole rear half was being re-ordered every two
  seconds and losing its place each time. Men who are demonstrably holding a formation slot
  are now left alone.
- **Buying a camp upgrade no longer recalls a deployed party.** The camp rebuild forgot who was
  out with you.
- **Invisible mercenaries in main-quest battles** — all 12 scripted main-quest battles are
  overridden so your men are enrolled in them and stay rendered.
- Mercs no longer stand around when the enemy is a base-game camp that has not formally
  turned hostile yet.
- The squad spreads across targets instead of dogpiling one enemy, and men who were refused
  a target no longer stand through a battle doing nothing.
- Large performance pass: per-merc scans replaced by one shared scan per tick, patrol
  population caps, and cheaper combat target selection.
- **Less aggressive level-of-detail.** Mesh detail is no longer cut for an ordinary company
  on the road — only a real battle coarsens it now, and far less than before. Distant men
  also keep their proper clothing one detail level longer. `merc_lod_quality crisp` turns the
  cut off entirely; `merc_lod_quality performance` restores the older, cheaper behaviour if
  your machine wants it.

### Options

- **You can turn the company's horses off entirely** — `merc_horses 0`, or ask the quartermaster
  under **Mod settings**. The men then march on foot whatever you are riding, and the squad stops
  behaving like cavalry with it: they form up in a foot column instead of a 64 m mounted one, and
  the catch-up that keeps stragglers with you stays switched on, which it is not for a mounted
  company. Horses already under the men are removed when you turn it off. The setting is saved.

### Console

- **Every command is in one place now**, with names that read like what they do:
  `merc_hire_army_big`, `merc_raid_sigismund`, `merc_battle 20 knight 6 45`, `merc_camp_make`,
  `merc_form_line`, `merc_stance_attack`. Type `merc_help` for the list.
- **New:** one command per enemy group — `merc_spawn_<group>`, `merc_raid_<group>`,
  `merc_patrol_<group>` for bandit, looter, sigismund, knight, prague, cuman and ruthenian.
- **New:** `merc_battle [foot] [group] [archers] [metres]` draws two armies up facing each
  other with their archers behind and you standing between them.
- **New:** `merc_clear_enemies` cleans up everything you spawned.
- **New:** `merc_horses 0 | 1` and `merc_lod_quality crisp | balanced | performance`.
- The ~350 authoring and diagnostic commands no longer clutter the console; type `merc_dev`
  to register them.
- Renamed: `merc_formation_*` → `merc_form_*`, `archer_*` → `merc_archer_*`,
  `enemy_spawn_*` → `merc_spawn_*`, `merc_hire_w1/d2/p3…` → `merc_hire[_weak|_strong] <count>`.

### Localisation

Sixteen languages, all complete. The difficulty confirmation message is now translated too.

---

### Also in 2.0 — the Aleksej questline

- **A nine-beat quest chain** for Aleksej of Zaslawye: a bounty-hunter in Kuttenberg who pays
  for quiet work in the woods, through nine encounters to a reckoning in the marsh.
- **Small-company relief.** The last two fights - the siege of Raborsch and the marsh - now
  scale down when you turn up with few men or none. A lone player faces seven besiegers
  instead of twelve, and the marsh's defenders lose their extra health. A company of eight or
  more sees no change.
- **Quest state survives a reload properly.** The beat camp and its leader are kept across a
  save rather than deleted and respawned, so the objective marker is on the map from the
  moment you load - and the camp no longer completes itself when you reload beside it.
- **Modded armour works with the wardrobe.** 2,358 items from nine popular armour mods are
  slot-classified, so they layer correctly and the gambeson-under-plate rule applies to them.

### Fixes since the first 2.0 draft

- **Console arguments were being ignored.** Thirty commands took an argument that never
  arrived, including `merc_hire <n>`, which always hired five, and ten on/off switches that
  could be turned on but never off.
- **Fast travel** no longer strands or loses the company, and patrols no longer spawn during it.
- **Formations**: stragglers, the leader getting stuck, line width and circle centring.
- **The camp forge and alchemy bench** survive a reload; the smithy stays where you put it.
- **Contract pay** is exact - hand-ins were a groschen short.

## Known issues

- Mercenaries will fight bandits who are part of an unrelated quest.
- Any other mod that replaces `AI/FormationDefinitions.xml` conflicts with this one.
- Mounted units in large companies still look loose compared to foot.
- Mercenaries are invisible inside scripted main-quest battles. `merc_mqstash_now` takes the
  company out of the fight and `merc_mqunstash_now` brings them back.
- Saves that ever held a camp load slowly if the mod is later removed. `merc_uninstall`
  before removing it.

---

## Older versions

See `TODO.txt` for the 1.1–1.6 changelogs.
