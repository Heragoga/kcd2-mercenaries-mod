# Performance

What this mod costs, what controls it, and how to measure it. The investigation that produced this
is in the appendix — including what turned out to be wrong, so nobody re-chases it.

## The short version

The long-standing "world is struggling" problem was **roaming patrols**: on by default, spawning
with no mercs hired, with nothing bounding how many gangs could be live at once. At a 20-merc
company that measured a median of 78 and a worst case of **234** extra full NPCs. Capped, it is 36.

The mod's **Lua is not a meaningful cost** — every scheduler slot, behaviour-tree hook and
persistence write together measured **0.19% of wall time** (116ms in a 60,300ms window, release
build). Cost lives in what the mod makes the **engine** do: NPCs it spawns, entities it keeps
rendered, raycasts it fires, cvars it raises.

## Tunables that control cost

| tunable | file | default | what it costs |
|---|---|---|---|
| `LivePatrolsEnabled` | `mercenaries_patrols_live.lua` | true | the whole patrol system; `merc_patrols_arm 0` |
| `PatrolMaxLiveMen` | same | 36 | living patrolmen, all gangs |
| `PatrolMaxLiveGangs` | same | 3 | concurrent gangs |
| `PatrolMaxMen` | same | 16 | one gang |
| `PatrolSpawnPerTick` | same | 1 | gangs appearing per 3s tick |
| `PatrolMaxCorpses` / `PatrolCorpseSecs` | same | 12 / 180s | lingering ragdolls |
| `RenderPin` | `mercenaries_util.lua` | true | every merc never distance-culled or LOD-reduced; `merc_render_pin 0` |
| `LodBoostMinCrowd` + `LodBoostRequireFoes` | `mercenaries_lodboost.lua` | 70, true | raises the engine AI-LOD budget globally while a real fight is on |
| `TowerMaxCount` | `mercenaries_tower.lua` | 999 | ~8 always-rendered meshes per tower — effectively uncapped |
| `RaidEnabled` | `mercenaries_raids.lua` | true | a camp raid every ~2 in-game days |
| `SchedEnabled` | `mercenaries_scheduler.lua` | true | `merc_sched 0` falls back to the legacy timers |
| `ProfEnabled` | `mercenaries_profiler.lua` | **false** | profiling wraps ~74 functions; opt-in only |

## Measuring

**Use the release build.** `PackageModDev.bat` launches `KCD2Mod`, a non-PGO DLL config **and an
older game version** (1.5.5 vs 1.5.6), which is laggy with no mods at all. Its timings are
meaningless. It is still the only build that prints engine `[Error]` lines, so it is the right tool
for finding errors and the wrong one for finding cost.

| command | what it does |
|---|---|
| `merc_prof 1` | enable profiling (off by default) and instrument in one step |
| `merc_prof_timer` | **run first** — if the smallest delta reads 0.000ms the clock is quantised and nothing below is trustworthy |
| `merc_prof_report` / `merc_prof_total` | dump by worst spike / by total time |
| `merc_prof_hitch <ms>` | lower the threshold if nothing trips |
| `merc_gc 0` / `1` | stop/restart Lua GC — the A/B for a GC-driven stutter |
| `merc_perf_verify` | proves the own-soul hash set answers the same as the old 65-entry scan |
| `merc_sched_status` | scheduler slots, rates, per-slot errors |
| `merc_patrols_status` | live patrol men / gangs / corpses against the caps |

Reading the output:

- **`STALL … Ran on the previous tick:`** — if it names slots, the mod is implicated; if it says
  *"NOTHING - the stall is outside this mod"*, it is engine-side and no Lua tuning will help. Slots
  whose period is a single tick are excluded, because they fire every tick regardless of cause.
- **`HITCH <name> … (Nms since last of THIS, Mms since any)`** — the first figure is the real period
  for that source. Periods are per-name; one shared timestamp is noise when sources interleave.
- **`~bt hooks per window`** — aggregate ms across all per-NPC behaviour-tree hooks per 250ms. Many
  individually-cheap calls landing in one frame are invisible to any per-call threshold.
- **`~mastertick gap` / `~heartbeat gap`** — gauges, not durations; their normal value is their own
  schedule. `Script.SetTimerForFunction` will not go below roughly **100ms**.
- Rows marked `(nest)` ran inside another timed function; their time is already in the caller's.

**Check the save's mod set.** `kcd.log` prints `Mods used while saving (N)` before the level load. A
save made with 35 mods, loaded against 1, carries state referencing 34 absent ones and invalidates
any with/without comparison run on it.

## The 2026-08 lag hunt: it was corrupted game files

**Root cause: verifying the game files through Steam fixed it completely.** Nothing in this
mod, and no code change, was involved. Recorded in full because the hunt cost days and the
same trap is easy to fall into again.

What made it so expensive to find:

- **The fault was intermittent per launch.** The same build was laggy on one run and smooth
  on the next. Every single-run A/B was therefore a coin flip, and two "confirmed culprits"
  were produced that way and acted on: a bisect fingering roaming patrols, and a
  `GetActions` A/B fingering `mercenaries_lookatinteraction.lua`. Both were noise.
- **It survived removing the mod entirely**, which should have ended the investigation far
  sooner than it did.
- **It was location-correlated, not content-correlated.** A clean vanilla save with no mods
  lagged around Kuttenberg and was fine in open countryside — which reads as "the mod is
  heavy in cities" and is really "the install is damaged".

**The rules that would have found it in an hour:**

1. If the symptom persists with the mod uninstalled, stop debugging the mod.
2. Never accept a single-launch A/B for an intermittent fault. Five runs per side minimum.
3. Verify game file integrity before a deep performance hunt. It is two minutes.
4. Check `kcd.log`'s `Extended build info:` line. Two installs exist on the dev machine:
   release `1.5.6` (`Win64MasterMasterSteamPGO`, `PackageMod.bat`) and the `KCD2Mod` dev
   install `1.5.5` **DEBUG PURE CLIENT** (`PackageModDev.bat`), which is laggy with no mods
   at all. Mixing launchers alone produces "sometimes laggy, sometimes not".

Genuine per-session variables to rule out before suspecting mod code: the launcher above;
`road_encounter` (77 `RandomEventVariant` nodes, 32 on fast travel); a save written with far
more mods than are installed (the `.whs` header is plain XML and lists them); and cold shader
cache (kcd.log showed 16,268 PSOs precached in ~1.5s on a load).

The one lasting good from the hunt is the density work below — found by measurement, kept on
its own merits, not because it fixed this.

## Costs that scale with NPC DENSITY, not squad size

A separate axis from everything else in this file. **This did not cause the 2026-08 lag** —
that was corrupted game files, see above — but it is a real cost found while looking, and it
is kept on its own merits.

The axis: a mod cost proportional to *how many vanilla NPCs are near the player* is silent in
a field and expensive in a market square, however few mercs are hired. Worth knowing about
because it is the one profile that never shows up in a squad-size test.

`UpdateEnemyCache` runs every 300ms (600ms when idle) and passes **every** NPC the box query
returns — not just hostiles — through `IsValidEnemy`. So per nearby NPC, three times a
second, the mod paid:

| was | now |
|---|---|
| `if self.BanditCampSuppressed then` — a **method reference**, always truthy, so the block ran for every candidate in every session even with no bandit camp anywhere | gated on `BanditCampAnyUnalerted()`: two table lookups, no allocation |
| `BanditCampSlots()` built a fresh 2-element table per candidate | slots walked directly in `BanditCampSuppressed` |
| `pcall(function() ... end)` in `IsValidEnemy` (x2) and in `IsAliveAndWell` — a fresh closure per candidate | `pcall(method, obj, arg)` — no closure |
| shared scan radius **latched** to `StaticArcherRange` (90m) forever after the first tower archer, via `PerfWantRadius`, cleared only by `PerfReset` on load | `PerfScanNpcs` recomputes it per pass; 90m only while static archers exist |

That last one is the big multiplier: a 90m circle is ~25x the area of the default 18m, so one
tower archer placed once turned every later crowd into a hundreds-of-NPC sweep — with the
player nowhere near the tower, and after the archer was gone.

Why allocations matter here specifically: Lua's collector runs **on the main thread**. A
per-NPC-per-tick garbage stream is invisible with three NPCs around and becomes a periodic
main-thread pause in a crowd — which reads exactly like "laggy about once a second".

**Still known, not yet changed:** `IsValidEnemy` re-fetches both `ent:GetPos()` and
`distanceRefEnt:GetPos()` per candidate although `UpdateEnemyCache` already holds both
(`playerPos`, and `e.pos` from the shared scan). Two scriptbind crossings per NPC per tick.
Fixing it means a signature change across every caller, so it is left deliberately.

Also unconsolidated: static archers in `hostile`/`mod_enemies` mode and the quartermaster each
run their **own** box query (~90m and 30m) once a second, bypassing the shared scan and
repeating the same per-NPC validation.

## What changed

| change | file | effect |
|---|---|---|
| patrol population caps + nearest-first staggered spawning | `mercenaries_patrols_live.lua` | 234 → 36 NPCs worst case |
| `IsValidEnemy` 65-entry `string.find` → `OwnedSoulSet()` hash | `mercenaries_target_selection.lua` | ~4,300–6,500 pattern matches/sec removed |
| enemy positions cached on `CachedEnemies` | same | duplicate `GetPos` pass per merc per tick removed |
| `table.sort` → bounded top-8 insertion | same | no comparator closure or full sort per merc |
| `FindValidGround` `maxTries` budget | `mercenaries_util.lua` | 1,188 → 360 rays worst case; raid/ambush bursts 16,632 → 2,016 |
| `SaveString` tag map, one scan per session | `mercenaries_saving.lua` | ~7ms → ~1ms per write; `LogiSave` batched |
| `DefForget` wrote an empty string, which `SaveString` rejects | `mercenaries_defences.lua` | defence layout now actually clears |
| `aleksej_scheduler.xml` wrote an undeclared variable | `data/AI/` | 74 engine errors/session gone; Aleksej now defends himself |
| `RayWorldIntersection` skip-entity passed a table | `util.lua`, `tower.lua` | 30 warnings/session gone; the skip now works |
| BT `Wait` variation raised to 40% on 111 pollers | `data/AI/*.xml` | per-NPC trees de-phased |
| LOD boost gated on hostiles, threshold 8 → 70 | `mercenaries_lodboost.lua` | no longer latches on squad size alone |
| LOD band hysteresis + dwell | same | 300m query + per-NPC call no longer re-fires on crowd jitter |
| shared caches and master scheduler | `mercenaries_perf.lua`, `mercenaries_scheduler.lua` | reference sections below |

## Ruled out — do not re-investigate

- **Lua GC** — tested with the collector stopped, no change.
- **Render pinning** — tested with `merc_render_pin 0`, no change. Still a real per-merc cost, just
  not the cause.
- **The mod's Lua generally** — 0.19% of wall time.
- **Invalid script contexts** — all six names validate against the game's 777-entry table.
- **Leftover debug code** — every debug module is console-only, arms no timer at load and leaves
  nothing behind. Every Debug/Test/Verbose flag defaults off.
- **`RebuildMercCache`** — runs once on load, not periodically.
- **Bare BT `Loop`/`Wait` node traversal** — a structural count is not evidence of cost; scriptbind
  crossings and world queries are.
- **`RaidTick` / `LivePatrolTick` / `WBTick` as background cost** — all correctly gated.

## A regression worth remembering

After the caps were confirmed working, an adversarial review flagged that the corpse cap could delete
bodies the player was actively looting. The fix for that reintroduced the lag, because two of its
parts raised the entity count above the version that had been tested:

- `PatrolMaxCorpses` 12 -> 24, and a `PatrolCorpseKeepRange` of 60m **inside which the cap never
  evicted at all**. Standing and fighting in one place then accumulated corpses with nothing to stop
  it - an unbounded case introduced while fixing a bounded one.
- `PatrolLiveGangCount` changed to require a living man, so a wiped gang released its slot instantly
  and a replacement spawned *alongside* the corpse pile. More entities at once, not fewer.

Both reverted. The looting protection is now keyed on **recency, not distance**: the pile just made
is exempt from the cap for `PatrolCorpseGraceSecs` (30s) and then ages out. At most a pile or two is
ever exempt, so it cannot accumulate.

The lesson is narrow and worth keeping: **any change that relaxes a population bound has to be
measured against the bound, not just against the bug it fixes.** A correctness fix that quietly
raises a ceiling is a performance regression wearing a bug-fix hat.

## Known costs not yet addressed

Real, but not the cause, and each needs a design decision rather than a mechanical fix:

- `LogiRebuildCampForUpgrade` tears down and re-raycasts the **entire** camp for every upgrade
  purchase — the heightmap phase alone is up to 7,921 rays, hit 3–7 times a session.
- `TowerMaxCount = 999`; each tower is ~8 always-rendered meshes.
- Every spawned structure gets `SetViewDistUnlimited`; wall segments stack four max-detail render
  calls per piece.
- `merc_deterrenceImmunityPulse` (both level copies) is a 5s repeating quest Timer that logs
  `Empty soul collection` whenever no mercs exist. Harmless at that rate, but it buries real errors.
  Left alone deliberately — quest graphs are fragile.

---

## Shared frame cache

`mercenaries_perf.lua` — one scan per window, everyone reads from it. Load immediately after `mercenaries_util.lua` in the `Script.LoadScript` chain, before anything that reads `PerfPos`/`PerfNpcScan`/`EntityByWuid`.

```lua
mercenaries.PerfPos           = {}   -- [wuidStr] = {x=,y=,z=}; PerfPos.player = player pos
mercenaries.PerfNpcScan       = nil  -- {at=,cx=,cy=,cz=,r=,list={{entity=,wuid=,pos=},...}}
mercenaries.PerfWidestRadius  = mercenaries.EnemyScanRadius or 18
mercenaries.EntityByWuid      = {}   -- [wuidStr] = entity ref
mercenaries.CampActorCache    = {}   -- [wuidStr] = true/false
mercenaries.PatrolMemberIndex = {}   -- [wuidStr] = LivePatrols record

function mercenaries:PerfWantRadius(r)
    if r and r > (self.PerfWidestRadius or 0) then self.PerfWidestRadius = r end
end

-- ONE box query replaces UpdateEnemyCache's own, static archers' own, FindEnemyTarget's own.
function mercenaries:PerfScanNpcs()
    if not player then return end
    local pp = player:GetPos()
    if not pp then return end
    local r = math.max(self.PerfWidestRadius or 18, self.EnemyAlerted and self.EnemyAlertRadius or 0)
    local list = {}
    local ents = System.GetPhysicalEntitiesInBoxByClass(pp, r, "NPC")
    if ents then
        for _, ent in pairs(ents) do
            if ent and type(ent) == "table" then
                local p = ent:GetPos()
                if p then
                    local wuid = ent.this and ent.this.id or ent.id
                    table.insert(list, { entity = ent, wuid = wuid, pos = p })
                    self.PerfPos[tostring(wuid)] = p  -- piggy-back the position cache for free
                end
            end
        end
    end
    local now = 0; pcall(function() now = System.GetCurrTime() or 0 end)
    self.PerfNpcScan = { at = now, cx = pp.x, cy = pp.y, cz = pp.z, r = r, list = list }
end

-- Cheap, O(squad), no world query — driven every master tick (50ms).
function mercenaries:PerfScanMercs()
    for _, ent in pairs(self.ActiveMercs or {}) do
        local wuid = ent and (ent.this and ent.this.id or ent.id)
        if wuid then
            local p = ent:GetPos()
            if p then self.PerfPos[tostring(wuid)] = p end
        end
    end
    if player then
        local pp = player:GetPos()
        if pp then self.PerfPos.player = pp end
    end
end

-- Returns nil (never a false "empty") when out of coverage or too stale — caller MUST
-- fall back to its own query, never assume nothing is there.
function mercenaries:PerfNpcsNear(pos, radius, maxAgeMs)
    local scan = self.PerfNpcScan
    if not (scan and pos and radius) then return nil end
    if maxAgeMs then
        local now = 0; pcall(function() now = System.GetCurrTime() or 0 end)
        if (now - (scan.at or 0)) * 1000 > maxAgeMs then return nil end
    end
    local dx, dy = pos.x - scan.cx, pos.y - scan.cy
    if math.sqrt(dx*dx + dy*dy) + radius > scan.r then return nil end
    local r2, out = radius*radius, {}
    for _, e in ipairs(scan.list) do
        local ex, ey = e.pos.x - pos.x, e.pos.y - pos.y
        if (ex*ex + ey*ey) <= r2 then table.insert(out, e) end
    end
    return out
end

function mercenaries:PerfRegister(ent)
    if not ent then return end
    local wuid = ent.this and ent.this.id or ent.id
    if wuid then self.EntityByWuid[tostring(wuid)] = ent end
end
function mercenaries:PerfUnregister(wuid)
    if wuid then
        local ws = tostring(wuid)
        self.EntityByWuid[ws] = nil
        self.PerfPos[ws]      = nil
    end
end

-- Liveness-checked; falls back to a hash lookup (NOT a name scan) so a stale post-load id
-- can never silently return wrong data — it must pass IsAliveAndWell before being returned.
function mercenaries:PerfEntity(wuid)
    if not wuid then return nil end
    local ws = tostring(wuid)
    local cached = self.EntityByWuid[ws]
    if cached then
        local ok, alive = pcall(function() return cached.id ~= nil and self:IsAliveAndWell(cached, true) end)
        if ok and alive then return cached end
        self.EntityByWuid[ws] = nil
    end
    local ok, ent = pcall(function() return XGenAIModule.GetEntityByWUID(wuid) end)
    if ok and ent then self.EntityByWuid[ws] = ent end
    return ok and ent or nil
end

function mercenaries:OwnedSoulSet()
    if self._ownedSoulSet then return self._ownedSoulSet end
    local set = {}
    for _, tierList in pairs(self.Souls or {}) do
        for _, guid in ipairs(tierList) do set[guid] = true end
    end
    for _, guid in ipairs(self.ArcherSouls or {}) do set[guid] = true end
    for _, guid in ipairs(self.StaticArcherSouls or {}) do set[guid] = true end
    self._ownedSoulSet = set
    return set
end

function mercenaries:CampActorCacheSet(wuid, isActor)
    if wuid then self.CampActorCache[tostring(wuid)] = isActor and true or false end
end
function mercenaries:CampActorCacheInvalidate(wuid)
    if wuid then self.CampActorCache[tostring(wuid)] = nil end
end
function mercenaries:CampActorCacheInvalidateAll()
    self.CampActorCache = {}
end

function mercenaries:PatrolIndexGang(rec)
    for _, e in ipairs(rec.men or {}) do
        local w = e and (e.this and e.this.id or e.id)
        if w then self.PatrolMemberIndex[tostring(w)] = rec end
    end
end
function mercenaries:PatrolIndexClear(rec)
    for _, e in ipairs(rec.men or {}) do
        local w = e and (e.this and e.this.id or e.id)
        if w and self.PatrolMemberIndex[tostring(w)] == rec then
            self.PatrolMemberIndex[tostring(w)] = nil
        end
    end
end

-- Wipe everything on load/level change; the one place EntityByWuid gets re-populated
-- afterward is RebuildMercCacheDelayed (already the mod's one permitted full-world scan).
function mercenaries:PerfReset()
    self.EntityByWuid      = {}
    self.PerfPos           = {}
    self.PerfNpcScan       = nil
    self.CampActorCache    = {}
    self.PatrolMemberIndex = {}
    self._ownedSoulSet     = nil
end
```

**Staleness contract** (write this down — the thing prior ad-hoc caches in this mod never had):

| table | refresh | tolerance |
|---|---|---|
| `PerfPos` | every master tick (50ms), all `ActiveMercs` + player | strictly fresher than any current 150ms+ consumer; never a regression |
| `PerfNpcScan` | on the `combatscan` slot (300ms, 150ms alerted, 600ms+ idle) | consumers at ≤300ms may read directly; anchored-elsewhere consumers (towers, WBTick, QM) MUST call `PerfNpcsNear` and fall back to their own query on nil, never assume empty |
| `EntityByWuid` | liveness-checked every read | never trusted blind; self-heals via hash lookup on miss/fail, so post-load id reuse can't return wrong data |
| `CampActorCache` | event-invalidated (camp spawn/break/recall/dismiss/siege-flip); round-robin sweep is only the safety net | bug in event wiring degrades to "≤2.5s stale," never "wrong forever" |
| `PatrolMemberIndex` | event-invalidated only, never time-based | `PatrolLivingMen` deliberately stays an uncached live rescan — a TTL here would let a corpse anchor the follow chain |

### Adopting call sites

| file:line | current pattern | primitive | replacement |
|---|---|---|---|
| `mercenaries_target_selection.lua:56-83` | 65-entry `string.find` triple loop | `OwnedSoulSet()` | O(1) hash lookup on `ent.soul:GetId()` |
| `mercenaries_target_selection.lua:115-149` | own `GetPhysicalEntitiesInBoxByClass` | `PerfNpcsNear`/`PerfScanNpcs` | driven by `combatscan` slot with backoff |
| `mercenaries_saving.lua:4-61` | full `GetEntitiesByClass('BasicEntity')` scan per save/load | same `PerfRegister`/`PerfEntity` mechanism, applied to a tag→saver-entity table | invalidated via `PerfReset` on load |
| `mercenaries_target_selection.lua:273-314` (`ScanForEnemies`) | fresh table + `table.sort` per merc per tick | entries carry `.pos` from the scan already | no per-call `GetPos`; bounded nearest-N pass instead of sort |
| `mercenaries_logistics.lua:684-703` | `GetEntityByName` for QM every 5s | `PerfEntity(qmWuid)` | QM wuid cached via `PerfRegister` at spawn |
| `mercenaries_static_archer.lua:509-558` | independent 90m box query per archer | `PerfNpcsNear(archerPos, StaticArcherRange, maxAgeMs)` | `PerfWantRadius(90)` announced at spawn; own-query fallback outside coverage; must carry `isModEnemy` flag |
| `mercenaries.lua:857-880` (`CombatScanLoop`) | always-on 300ms | `combatscan` slot | backoff 300ms→600ms only while unalerted and `CachedEnemies` empty, re-checked every tick |
| `mercenaries_target_selection.lua:273-314,414-454` | duplicate `GetPos` across `ScanForEnemies`/`PickCombatTarget` | shared `.pos` from `PerfScanNpcs` | eliminates the duplicate pass entirely |
| `mercenaries_patrols_live.lua:1002-1035,633-639` | O(all route slots) linear scan | `PatrolMemberIndex` | O(1) "which gang"; `PatrolLivingMen` stays uncached |
| `mercenaries_patrol.lua:85-99` | `PatrolCtx` called twice | same index | both calls become O(1); prefer threading params instead |
| `mercenaries_formation.lua:94-138` | tostring/`IsCampActor` pile | `CampActorCache` + `PerfPos` | O(1) cache read; no per-merc `GetPos` |
| `mercenaries_patrols_live.lua:927-963` | redundant living-list rebuild | reuse caller's already-computed living list | not a TTL'd copy — thread it down |
| `data/AI/camp_actor.xml:79-154` | 2-3× redundant role lookups/cycle | `campActorSnapshot` perNpc slot | one `{isGuard,furniture,activity}` computed per NPC per cycle |
| `mercenaries_camp.lua:1808-1934` | unconditional O(n²) pairing scan | distance check inside `campchat` slot body | `if not CampActive` wipe branch stays unconditional |
| `mercenaries_quartermaster.lua:123-177` | always-on 1s box query ×2 | `qmtargetscan` slot with backoff | box query itself unchanged; never shares `CachedEnemies` |
| `data/AI/follow.xml:177-264` | `GetEntityByName` every 500ms | `PerfEntity(data.horse)` | `PerfRegister` right after `System.SpawnEntity` for the horse |
| `mercenaries_spawning.lua:805-930` (`FindEnemyTarget`) | independent per-NPC 50m query | `PerfNpcsNear(myPos, 50, maxAgeMs)` with fallback | per-agent hold/`NavTargetBlocked` state machine untouched |

## Budgeted master scheduler

`mercenaries_scheduler.lua` — one master tick, N registered slots, phase-offset, gated, amortized, adaptive. Load after `mercenaries_perf.lua` and after everything the slot `fn`s call — near the end of the `Script.LoadScript` chain.

```lua
mercenaries.MasterTickMs = 50
mercenaries.SchedTick    = 0
mercenaries.SchedSlots   = {}

local function ticksOf(ms) return math.max(1, math.floor(ms / mercenaries.MasterTickMs + 0.5)) end

function mercenaries:SchedRegister(name, def)
    def = def or {}
    local period = ticksOf(def.periodMs or 1000)
    local phase = def.phaseTicks
    if not phase then
        self._schedPhaseCursor = (self._schedPhaseCursor or 0) + 1
        phase = self._schedPhaseCursor % period
    end
    self.SchedSlots[name] = {
        name = name, fn = def.fn, gate = def.gate,
        periodTicks = period, phaseTicks = phase % period,
        backoff = def.backoff, idle = false, idleSince = nil,
        perNpc = def.perNpc, cursor = 1,
    }
end

-- Only the subsystem itself knows whether this pass found anything; re-checked every
-- master tick, never latched — a squad going alert mid-backoff is caught next tick.
function mercenaries:SchedMarkIdle(name, idle)
    local s = self.SchedSlots[name]
    if not s then return end
    if idle and not s.idle then s.idle = true; s.idleSince = self.SchedTick end
    if not idle then s.idle = false; s.idleSince = nil end
end

local function effectivePeriod(self, s)
    if not (s.backoff and s.idle) then return s.periodTicks end
    if (self.SchedTick - (s.idleSince or 0)) < ticksOf(s.backoff.idleMs or 0) then return s.periodTicks end
    return math.max(s.periodTicks, math.floor(s.periodTicks * (s.backoff.factor or 1)))
end

local function runPerNpc(self, s)
    local pn = s.perNpc
    local t = self[pn.table]
    if not t then return end
    if not s._keys or s._keysDirty then
        s._keys, s._keysDirty = {}, false
        for k in pairs(t) do table.insert(s._keys, k) end
        s.cursor = 1
    end
    local n = #s._keys
    if n == 0 then return end
    for _ = 1, math.min(pn.budget or n, n) do
        local k = s._keys[s.cursor]
        local ent = t[k]
        if ent then pcall(pn.fn, self, ent, k) end
        s.cursor = s.cursor + 1
        if s.cursor > n then s.cursor = 1; s._keysDirty = true end
    end
end

function mercenaries.MasterTick()
    local self = mercenaries
    self.SchedTick = self.SchedTick + 1
    local t = self.SchedTick
    for _, s in pairs(self.SchedSlots) do
        local period = effectivePeriod(self, s)
        if (t + s.phaseTicks) % period == 0 then
            if (not s.gate) or s.gate(self) then
                if s.perNpc then
                    runPerNpc(self, s)
                else
                    local ok, err = pcall(s.fn, self)
                    if not ok then
                        System.LogAlways('[Mercenary Jeff] Scheduler slot "' .. s.name .. '" error: ' .. tostring(err))
                    end
                end
            end
        end
    end
    Script.SetTimerForFunction(mercenaries.MasterTickMs, "mercenaries.MasterTick")
end
```

50ms is the GCD of every existing cadence (150/300/700/1000/3000/5000 all land on an exact boundary — nothing drifts). Phase offsets are auto-assigned from a monotonic cursor, so slots sharing a period spread across it by registration order instead of colliding by coincidence — today, 150/300/700 all divide 2100ms evenly, so `FormationLoop`, `CombatScanLoop`, and `WBTick` periodically all fire on the same frame purely because their independent `SetTimerForFunction` chains happened to drift together.

### Phase-slot table

| slot | periodMs | backoff | perNpc | fn |
|---|---|---|---|---|
| `mercpos` | 50 | — | — | `PerfScanMercs` |
| `formation` | 150 | **none — flat, never backed off** | — | `UpdateFormationLeader` |
| `campactorsweep` | 50 | — | `ActiveMercs`, budget=4 | `CampActorCacheSet` per merc |
| `combatscan` | 300 | idle 5000ms → ×2 (600ms) | — | `DismountWatch`, `UpdatePlayerSpeed`, `PerfScanNpcs`, `UpdateEnemyCache`, `UpdateSquadThreat`, `LodBoostTick` |
| `monitor` | 1000 | — | — | `MonitorInventory`, `MonitorMainQuestLoop`, `MonitorDistanceAndTeleport`, `ProcessReturnPending`, `KeepStaticArchersUp`, `AmbushMonitor`, `CampBedSleepWatch`, `BanditCampMonitor`, `RaborschMonitor`, `AlxTalkTick`, `AlxLodgingTick` |
| `lowpriority` | 5000 | — | — | `PruneMercCache`, `UpdateFormationSlots`, `ResupplyArchersOutOfCombat`, `ResupplyStaticArchers`, `PruneCombatClaims`, `RefreshRenderPins`, `LivePatrolWatchdog`, `MonitorCamp`, `LogiTick` |
| `wbtick` | 700 | — | — | `WBTickBody` (gated, see below) |
| `lodboostreassert` | 300 | — | — | compare-before-write on 18 cvars + `LodRatioAutoApply` |
| `qmtargetscan` | 1000 | idle 8000ms → ×3 | — | `FindQuartermasterTarget` (own query, untouched) |
| `campchat` | 5000 | — | — | `CampChatTick` (distance gate added inside) |
| `lootsweep` | 1000 | — | — | `LootAssign` (busy/free hoisted before scan) |

### Gating preconditions per subsystem

- **`mercpos` / `campactorsweep`**: `next(self.ActiveMercs) ~= nil` — nothing to do with an empty squad.
- **`formation`**: `next(self.ActiveMercs) ~= nil and player ~= nil` — no combat/distance/backoff gate at all, deliberately: this is the one thing that must never lag. Its win comes entirely from the cache primitives, not from running less often.
- **`combatscan`**: no gate function — always fires; the backoff (300ms→600ms) is the throttle, driven by `SchedMarkIdle("combatscan", not (EnemyAlerted or next(CachedEnemies)))`, re-evaluated every 50ms so a squad going alert mid-backoff is corrected on the very next master tick, never stale until some independent timer's own next fire.
- **`wbtick`**: `WBArmed and CampActive and CampCenter and player`, then squared-distance ≤300² from `CampCenter` — mirrors `RaidPlayerInCamp`'s own 45m gate with generous margin; raids only launch within 45m and forces spawn within 120m, so this cannot suppress a legitimate raid.
- **`lodboostreassert`**: `LodBoostActive == true` — cadence stays 300ms on purpose (a slower reassert reintroduces the LOD-popping bug the every-tick reassert was written to fix); the fix is compare-before-write, not a slower timer.
- **`qmtargetscan`**: no gate, backoff only — deliberately never shares `CachedEnemies` (player-centered) because it must keep defending an empty, distant, raided camp.
- **`campchat`**: the `if not CampActive` chat-wipe branch stays unconditional inside the fn; only the O(n²) pairing scan is gated on distance-to-`CampBuildOrigin`.
- **`lootsweep`**: no gate; `busy`/`free` are computed first inside the fn and `LootEligibleMercs()` is skipped when neither can change.

### Timer latches must be cleared on load, not on session start

`Script.SetTimerForFunction` chains **do not survive a save load** — the engine drops them with the
level. The `mercenaries` table does survive, so **any latch guarding a timer outlives the timer it
guards**, and left set it means that tick never comes back for the rest of the session.

That is not a theory. `LootSweepLoop` is armed unconditionally on every load *and* re-arms itself
unconditionally; if timers survived it would double every single load, and it does not.

Getting it wrong killed the whole mod on the second save loaded in one session. `SchedRunning` was
still true from the first, `SchedStart` refused to arm, and the master tick never ran again — taking
`MonitorInventory` with it, so the hire tokens were never consumed and **hiring silently did
nothing**. `_schedWatchdogArmed` was latched the same way, so the one thing that could have noticed
was dead too. The log says it plainly and then stops:

```
[Mercenaries] Game loaded! Starting the inventory monitor loop...
[MercSched] master tick already running - refusing to arm a second chain
```

`SchedOnLoad` runs at the very top of `OnGameplayStarted`, before anything arms a timer, and clears
every latch in `TimerLatches` — `SchedRunning`, `_schedWatchdogArmed`, `LivePatrolRunning`,
`RaidRunning`, `WBRunning`, `FoeLoopArmed`, `GearTickArmed`, `_profHbArmed`. **Add to that list
whenever a new self-arming loop gets a latch.** Only latches whose chain is re-armed somewhere
belong there; a latch nobody re-arms is just a flag.

The latch itself is kept, because the thing it protects against is real — `OnGameplayStarted` arming
twice for *one* load would leave two ghosts independently driving every slot. It is now keyed to a
**load generation** (`SchedLoadGen`) instead of the session: within one load a second `SchedStart`
is still refused, across loads it arms fresh.

## Full findings table

Sorted by severity, then tick rate (fastest first) within severity.

| id | file:line | tick | cost | fix | severity |
|---|---|---|---|---|---|
| follow-horse-getentitybyname-poll | `data/AI/follow.xml:177-264` | 500ms | 2 `GetEntityByName` calls/merc/sec, unconditional of mount state, full-registry linear scan | `PerfEntity(data.horse)` hash lookup | critical |
| formation-eligibility-tostring-pile | `mercenaries_formation.lua:94-138` | 150ms | ~16 tostring/merc/tick incl. one fully redundant `IsCampActor` call; ~500-550 scriptbind + ~1,400-2,100 tostring/sec at 20 mercs | drop redundant call; route through `CampActorCache` | high |
| enemy-cache-soul-guid-stringfind | `mercenaries_target_selection.lua:54-108,115-149` | 300ms | ~1,950 `string.find` + ~450 scriptbind calls/300ms at 30 nearby NPCs | `OwnedSoulSet()` hash lookup | high |
| isvalidenemy-linear-soul-scan | `mercenaries_target_selection.lua:56-83` | 300ms | 65 `string.find`/candidate, ~4,300-6,500/sec at 20-30 NPCs | same `OwnedSoulSet()` fix | high |
| combatscanloop-always-on-unfiltered | `mercenaries.lua:857-880` | 300ms | 3.33 full box-query+validate passes/sec forever once 1 merc hired | rides fix #1's speedup; add idle backoff via scheduler | high |
| patrolctx-linear-rescan-eager-rebuild | `mercenaries_patrols_live.lua:1002-1035,633-639` | 300ms (as fast as 150ms via `PatrolWalkTick`) | O(~26-52 route slots) scan + eager alive-rebuild per hook; ~300-650 scriptbind/sec, 2-gang/15-man | `PatrolMemberIndex[wuidStr]=rec` | high |
| findenemytarget-per-npc-query | `mercenaries_spawning.lua:805-930` | 1000ms | independent 50m box query per enemy NPC; burst of N simultaneous queries at fight start | shared `PerfNpcsNear`, per-agent state machine preserved | medium |
| savestring-full-world-scan | `mercenaries_saving.lua:4-61` | 5000ms | `GetEntitiesByClass('BasicEntity')` + spawn + destroy + log I/O per write; ~94 non-tick call sites too | id-cache per tag, invalidated on load | medium |
| static-archer-per-instance-full-scan | `mercenaries_static_archer.lua:509-558` | 1000ms | N archers × independent 90m query + 65-scan, overlap unshared | shared `PerfNpcsNear` per archer | medium |
| patrolchain-double-ctx-call | `mercenaries_patrol.lua:85-99` | 1000ms | doubles `PatrolCtx` cost + O(gang) identity scan w/ per-comparison `tostring()` | `PatrolMemberIndex`, or thread caller's leader/members as params | medium |
| wbtick-ungated-sphere-scan | `mercenaries_wallbattle.lua:184-214,629-703` | 700ms | ungated 55m sphere query + name/alive walk, forever, once any wall/defence exists | distance gate (300m from `CampCenter`) before the scan | medium |
| scanforenemies-per-merc-sort | `mercenaries_target_selection.lua:273-314` | 300ms | O(m log m) `table.sort` + fresh table per merc per tick on a centrally-refreshed list | bounded nearest-N linear pass, drop `table.sort` | medium |
| scanforenemies-pickcombattarget-duplicate-scan | `mercenaries_target_selection.lua:273-454` | 300ms | one O(E log E) sort + one redundant O(E) `GetPos` pass, duplicated self-lookup | merge into one pass, shared `.pos` | medium |
| ranged-combat-data-ammo-overscan | `mercenaries_ai_modules.lua:236-249` | 300ms | 14 vs at-most-6 `GetCountOfClass` scriptbinds/archer/tick, each pcall-wrapped | `GetArcherWeaponType()` once, scan only that pool | medium |
| archer-ammo-check-no-early-exit | `mercenaries_ai_modules.lua:236-249` | 300ms | same function, no early-exit once ammo found | same fix as above (duplicate finding) | medium |
| scanforenemies-double-getpos-and-closure-alloc | `mercenaries_target_selection.lua:273-314,414-454` | 500ms (true cadence 300ms) | duplicate `GetPos` across 2 passes; ~1,650-1,700 GetPos/sec at 50-merc opening skirmish | cache pos once per `UpdateEnemyCache` pass | medium |
| lodboost-cvar-reassert-always-on | `mercenaries_lodboost.lua:160-246` | 300ms | 18 unconditional `SetCVar` scriptbinds + 18 pcall closures/tick while ≥8 crowd | `GetCVar`-compare-before-`SetCVar` | low |
| foeloop-redundant-query-dormant | `mercenaries_foe.lua:119-161,180-332` | 250ms | zero cost today; would add a second 90m query + 3 nested O(F×C) passes if ever wired live | no action while dormant; share `PerfNpcsNear` before shipping | low |
| monitorinventory-unconditional-token-polling | `mercenaries.lua:596-806` | 1000ms | ~63 `GetCountOfClass` scriptbinds/sec, never early-outs | cheap version/menu-open gate before the ~50-class poll | low |
| patrol-alert-redundant-livingmen-rebuild | `mercenaries_patrols_live.lua:927-963` | 1000ms | 2 more alive-rescans per alert transition, narrow trigger (combat proximity only) | reuse caller's already-computed living list | low |
| camp-actor-bt-redundant-role-lookups | `data/AI/camp_actor.xml:79-154` | 1000ms | same 3 facts recomputed 2-3× via separate `ExecuteLua` crossings, per camp-actor NPC | one snapshot per NPC per cycle | low |
| campchattick-onsquared-no-distance-gate | `mercenaries_camp.lua:1808-1934` (Scripts/mods) | 5000ms | O(n²) pairing + ~3× scriptbind IsAliveAndWell/merc, runs regardless of player distance | distance gate before list-build/pairing | low |
| qm-aleksej-idle-target-scan-always-on | `mercenaries_quartermaster.lua:123-177` | 1000ms | 2 × 30m box query/sec forever, no enemy-presence gate | widen Wait to 2-3s while `~$inCombat` (query itself unchanged) | low |
| lootsweep-full-squad-scan-when-no-work-possible | `mercenaries_lootsweep.lua:290-347` | 1000ms | full ActiveMercs eligibility scan even when cap full/nothing left to give out; ~250 scriptbind/sec worst case at 50 mercs | hoist busy/free check before `LootEligibleMercs()` | low |
| logicampregen-getentitybyname | `mercenaries_logistics.lua:684-703` | 5000ms | linear-scan `GetEntityByName` for QM every regen tick | cache QM entity ref via `PerfEntity` | low |
| banditcamp-sweeptokens-rebuild-and-scan | `mercenaries_banditcamp_quest.lua:2373-2398` | 1000ms | rebuilds static 29-entry list from scratch every tick, 29 `GetCountOfClass` calls even when idle | memoize combined list once, lazily on first call | low |
| ambushmonitor-scene-table-copy | `mercenaries_ambush.lua:274-281,331-366` | 1000ms | 1 table alloc + key copies/sec, currently negligible | return `self.AmbushScenes` directly | low |

---

# Appendix: how this was found

Eight rounds, several of them wrong. The wrong turns are recorded because they are what stops the
next person repeating them.

**Rounds 1–2 optimised Lua.** A 16-agent sweep produced 28 findings, 27 verified. Real bugs, all
shipped — but the symptom did not move, because Lua was never the cost.

**Round 3 reframed the symptom.** "Heartbeat at constant FPS" means a periodic *spike*, not a
sustained load. Correct, and it led to building the profiler.

**Round 4 built the profiler, and it lied.** Its stall discriminator compared each slot's fired-tick
against a tick that had not run yet, so it would have reported *"the stall is outside this mod"* for
every stall regardless of truth. An adversarial audit caught it before it misled anyone, along with
five more defects in the same tool: return values truncated at four (`PatrolCtx` returns five), hitch
periods shared across all sources, nested calls producing phantom heartbeats, a stall threshold below
the timer's own floor, and the GC detector allocating inside the function meant to detect allocation.

**Round 5 measured the wrong build.** `PackageModDev.bat` targets a non-PGO DLL config one game
version behind, laggy with no mods. Every timing taken there overstated cost. The ratio (Lua =
0.19%) survived; the absolute numbers did not.

**Round 6 found GC, and a broken save.** Collections every 186–383ms with 15–29ms pauses landing
inside one-line functions — plausible, and wrong. The same log showed the save had been created with
35 mods and was running with 1, invalidating every with/without comparison made until then.

**Round 7: the scheduler was killing itself.** A duplicate-chain guard added in round 6 exited
without re-arming when two ticks landed within 40ms — which happens after any hitch, when the engine
fires queued timers back to back. Twelve watchdog re-arms in one session, with the core loops
intermittently dead for ~5s at a time. That was the "marginal improvement, kinda unreliable" phase.

**Round 8: patrols.** The answer had been in every log from the start:
`[Patrols] roaming patrols armed (26 route(s))`.

Three engine facts worth carrying forward:

1. `Script.SetTimerForFunction` accepts no third argument — passing one silently stops the timer
   re-firing. It killed the master scheduler for an entire session.
2. `System.GetCurrTime()` is engine-cached per frame and cannot time anything within a frame.
   `os.clock()` is the only usable source, at ~1ms resolution.
3. A syntax check does not catch a mangled identifier: `mathit_sin` passed `luacheck` cleanly and
   would have thrown on first use. Flag a called name that appears exactly once and is never defined.
