// mercenaries_nav.asi - expose KCD2's runtime navigation obstacles to Lua.
//
// WHY THIS EXISTS
// The navmesh ships baked (Levels/<lvl>/recast.pak, Detour tiles with the DNAV magic), so a
// palisade the player builds is never part of it and every NPC aims straight through it.
// The engine does have a runtime answer - the same one in-game NPC dialogues use so that
// passers-by walk round a conversation: C_AIObstacles::AddObstacle(desc) flags every navmesh
// polygon under a cylinder (bit 2 on the 21-byte poly), and the pathfinder's query filter
// multiplies the cost of such polygons by wh_ai_FindPathObstaclesMultiplier whenever
// wh_ai_FindPathUseObstacles is on (it ships on). It has exactly four callers in
// WHGame.dll and not one of them is reachable from Lua, XML, Skald or a behaviour tree.
// This plugin is the fifth caller.
//
// WHAT IT REGISTERS
//   merc_navobst add <x> <y> <z> <radius> <height> [ignoreRadius] [flag]
//       -> Lua global MercNavObstacleResult = obstacle id (or -1)
//   merc_navobst remove <id>
//   merc_navobst clear                     removes everything this plugin added
//   merc_navobst status
// Lua calls it with System.ExecuteCommand(...), which runs synchronously, then reads the
// global. The engine functions are found by BYTE SIGNATURE, never by address - gEnv moves on
// every patch (docs/disassembly.md). The command is registered from an IGame::CompleteInit
// hook so it happens on the game thread, after every engine subsystem is up.
//
// Build: native\mercnav\build.ps1 (MSVC, x64). Load with Ultimate ASI Loader, or inject
// for a test with tools\inject_dll.py.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <string>
#include <vector>
#include <mutex>

namespace {

// ---- engine shapes -------------------------------------------------------------------

// Exactly what the shipping callers put on the stack before calling AddObstacle.
struct ObstacleDesc {
    float x, y, z;         // centre, world space (z at ground level: the height is added upward)
    float radius;          // cylinder radius
    float height;          // cylinder height
    float ignoreRadius;    // -1 = none (see wh_dlg_UseObstacleIgnoreRadius)
    uint8_t flag;          // 1 = the dialogue kind (also asks moving NPCs to replan), 0 = SequenceArea kind
    uint8_t pad[3];
};

struct IConsoleCmdArgs {                     // CryEngine IConsole.h, four slots, unchanged in KCD2
    virtual ~IConsoleCmdArgs() {}
    virtual int GetArgCount() const = 0;
    virtual const char* GetArg(int i) const = 0;
    virtual const char* GetCommandLine() const = 0;
};

typedef void* (*AccessorFn)();                                    // sub_9155C8: TLS-guarded module singleton
typedef int   (__fastcall* AddObstacleFn)(void* mgr, const ObstacleDesc* d);
typedef void  (__fastcall* RemoveObstacleFn)(void* mgr, int id);
typedef void  (*ConsoleCommandFunc)(IConsoleCmdArgs*);
typedef void  (__fastcall* AddCommandFn)(void* console, const char* name, ConsoleCommandFunc fn, int flags, const char* help);
typedef bool  (__fastcall* ExecuteBufferFn)(void* scriptSystem, const char* buf, size_t len, const char* desc, void* env);
typedef void  (__fastcall* CompleteInitFn)(void* game);

// SSystemGlobalEnvironment offsets and vtable slots verified in docs/disassembly.md.
const size_t OFF_pScriptSystem = 0x28;
const size_t OFF_pGame         = 0x90;
const size_t OFF_pConsole      = 0xA8;
const int    SLOT_AddCommand    = 33;   // CXConsole 0x108
// CScriptSystem: 5 = ExecuteFile, 6 = ExecuteBuffer, 7 = UnloadScript. The reference guide
// lists ExecuteBuffer as 7 by adjacency; slot 6 is the one whose body is lua_load over
// (buffer, size) followed by pcall, and slot 7 erases a name from the loaded-script set.
// The first build of this plugin used 7 and every Lua write silently unloaded nothing.
const int    SLOT_ExecuteBuffer = 6;    // CScriptSystem 0x30
const int    SLOT_CompleteInit  = 4;    // IGame 0x20
// The obstacle manager: accessor() -> +0x160 -> +0xA8 -> vtable slot 9 (0x48). Read straight
// off both shipping call sites (the dialogue one at sub_3BE955, the remove one at sub_C88020).
const size_t OFF_mgr1 = 0x160, OFF_mgr2 = 0xA8;
const int    SLOT_mgr = 9;

// ---- state ---------------------------------------------------------------------------

uint8_t*         g_env      = nullptr;
AccessorFn       g_accessor = nullptr;
AddObstacleFn    g_add      = nullptr;
RemoveObstacleFn g_remove   = nullptr;
CompleteInitFn   g_origCompleteInit = nullptr;
bool             g_registered = false;
std::vector<int> g_ours;
std::mutex       g_mutex;
char             g_logPath[MAX_PATH] = {};

void Log(const char* fmt, ...) {
    char buf[1024];
    va_list ap; va_start(ap, fmt); vsnprintf(buf, sizeof buf, fmt, ap); va_end(ap);
    OutputDebugStringA(buf); OutputDebugStringA("\n");
    if (g_logPath[0]) {
        if (FILE* f = fopen(g_logPath, "a")) { fprintf(f, "%s\n", buf); fclose(f); }
    }
}

// Say it in kcd.log too, once Lua is up. Cheap and it is where the user looks.
void LuaSay(const char* msg) {
    if (!g_env) return;
    void* ss = *(void**)(g_env + OFF_pScriptSystem);
    if (!ss) return;
    std::string code = "System.LogAlways([==[[MercNav] ";
    code += msg; code += "]==])";
    ((ExecuteBufferFn)(*(void***)ss)[SLOT_ExecuteBuffer])(ss, code.c_str(), code.size(), nullptr, nullptr);
}

void LuaSet(const char* code) {
    if (!g_env) return;
    void* ss = *(void**)(g_env + OFF_pScriptSystem);
    if (!ss) { Log("LuaSet: no script system"); return; }
    bool ok = ((ExecuteBufferFn)(*(void***)ss)[SLOT_ExecuteBuffer])(ss, code, strlen(code), "mercnav", nullptr);
    Log("ExecuteBuffer(%s) -> %d", code, (int)ok);
}

// ---- signature scanning --------------------------------------------------------------

struct Section { uint8_t* base; size_t size; };

bool FindSection(HMODULE mod, const char* name, Section& out) {
    auto dos = (IMAGE_DOS_HEADER*)mod;
    auto nt  = (IMAGE_NT_HEADERS*)((uint8_t*)mod + dos->e_lfanew);
    auto sec = IMAGE_FIRST_SECTION(nt);
    for (unsigned i = 0; i < nt->FileHeader.NumberOfSections; ++i, ++sec) {
        if (strncmp((const char*)sec->Name, name, 8) == 0) {
            out.base = (uint8_t*)mod + sec->VirtualAddress;
            out.size = sec->Misc.VirtualSize;
            return true;
        }
    }
    return false;
}

// "48 8B ?? 0D" style pattern; returns the first match and how many there were.
uint8_t* Scan(const Section& s, const char* pattern, int* count) {
    std::vector<int> pat;
    for (const char* p = pattern; *p; ) {
        while (*p == ' ') ++p;
        if (!*p) break;
        if (p[0] == '?') { pat.push_back(-1); p += (p[1] == '?') ? 2 : 1; }
        else { pat.push_back((int)strtoul(std::string(p, 2).c_str(), nullptr, 16)); p += 2; }
    }
    uint8_t* first = nullptr; int n = 0;
    for (size_t i = 0; i + pat.size() <= s.size; ++i) {
        size_t j = 0;
        for (; j < pat.size(); ++j) if (pat[j] >= 0 && s.base[i + j] != (uint8_t)pat[j]) break;
        if (j == pat.size()) { if (!first) first = s.base + i; ++n; }
    }
    if (count) *count = n;
    return first;
}

uint8_t* Rel32Target(uint8_t* at) {   // `at` points at the E8 / the 4-byte displacement follows
    int32_t d; memcpy(&d, at + 1, 4);
    return at + 5 + d;
}

// Offset of the nth literal "E8" token in a pattern, counted in bytes. Hand-counted offsets
// were wrong twice; the pattern is the only source of truth for where its calls are.
int NthCallOffset(const char* pattern, int nth) {
    int off = 0, seen = 0;
    for (const char* p = pattern; *p; ) {
        while (*p == ' ') ++p;
        if (!*p) break;
        bool isE8 = (p[0] == 'E' || p[0] == 'e') && p[1] == '8';
        if (isE8 && ++seen == nth) return off;
        ++off; p += 2;
    }
    return -1;
}

bool InSection(const Section& s, const void* p) {
    return (const uint8_t*)p >= s.base && (const uint8_t*)p < s.base + s.size;
}

bool Resolve(HMODULE whgame) {
    Section text;
    if (!FindSection(whgame, ".text", text)) { Log("no .text section"); return false; }
    int n = 0;

    // gEnv: the `exec autoexec.cfg` site. Two shapes (PGO reordered it between 1.2 and 1.4);
    // in both the leading `48 8B 0D disp32` loads gEnv->pConsole.
    uint8_t* g = Scan(text, "48 8B 0D ?? ?? ?? ?? 45 33 C9 45 33 C0 48 8B 11 4C 8B 92 ?? ?? ?? ?? 48 8D 15 ?? ?? ?? ?? 41 FF D2 48 85 FF", &n);
    if (!g || n != 1) g = Scan(text, "48 8B 0D ?? ?? ?? ?? 48 8D 15 ?? ?? ?? ?? 45 33 C9 45 33 C0 4C 8B 11 41 FF 92 ?? ?? ?? ?? 48 85 FF", &n);
    if (!g || n != 1) { Log("gEnv signature: %d hit(s)", n); return false; }
    { int32_t d; memcpy(&d, g + 3, 4); g_env = (g + 7 + d) - OFF_pConsole; }

    // AddObstacle: the in-game-dialogue site. ignoreRadius=-1, flag=1, accessor(), the two
    // hops to the manager, vtable slot 9, then AddObstacle(&desc).
    const char* ADD_SIG = "C7 45 ?? 00 00 80 BF C6 45 ?? 01 E8 ?? ?? ?? ?? 48 8B 88 60 01 00 00 48 8B 89 A8 00 00 00 48 8B 01 FF 50 48 48 8B C8 48 8D 55 ?? E8 ?? ?? ?? ??";
    uint8_t* a = Scan(text, ADD_SIG, &n);
    if (!a || n != 1) { Log("AddObstacle signature: %d hit(s)", n); return false; }
    g_accessor = (AccessorFn)Rel32Target(a + NthCallOffset(ADD_SIG, 1));
    g_add      = (AddObstacleFn)Rel32Target(a + NthCallOffset(ADD_SIG, 2));

    // RemoveObstacle: the small wrapper that clears an owner's id after removing.
    const char* REM_SIG = "83 B9 08 01 00 00 FF 48 8B D9 74 ?? E8 ?? ?? ?? ?? 48 8B 90 60 01 00 00 48 8B 8A A8 00 00 00 48 8B 01 FF 50 48 8B 93 08 01 00 00 48 8B C8 E8 ?? ?? ?? ??";
    uint8_t* r = Scan(text, REM_SIG, &n);
    if (!r || n != 1) { Log("RemoveObstacle signature: %d hit(s)", n); return false; }
    if ((AccessorFn)Rel32Target(r + NthCallOffset(REM_SIG, 1)) != g_accessor) { Log("accessor mismatch between sites"); return false; }
    g_remove = (RemoveObstacleFn)Rel32Target(r + NthCallOffset(REM_SIG, 2));

    Log("resolved: gEnv=%p accessor=%p add=%p remove=%p (WHGame base %p, .text %p+%zx)",
        g_env, (void*)g_accessor, (void*)g_add, (void*)g_remove, (void*)whgame, text.base, text.size);
    if (!InSection(text, (void*)g_accessor) || !InSection(text, (void*)g_add) || !InSection(text, (void*)g_remove)) {
        Log("a resolved function is outside .text - refusing to run");
        return false;
    }
    return true;
}

// ---- the obstacle manager --------------------------------------------------------------

void* Manager() {
    uint8_t* p = (uint8_t*)g_accessor();
    if (!p) return nullptr;
    uint8_t* a = *(uint8_t**)(p + OFF_mgr1); if (!a) return nullptr;
    uint8_t* b = *(uint8_t**)(a + OFF_mgr2); if (!b) return nullptr;
    return ((void* (__fastcall*)(void*))(*(void***)b)[SLOT_mgr])(b);
}

// ---- the console command ---------------------------------------------------------------

void Command(IConsoleCmdArgs* args) {
    const char* line = args ? args->GetCommandLine() : "";
    Log("command: argc=%d line=\"%s\"", args ? args->GetArgCount() : -1, line ? line : "(null)");
    char verb[32] = {};
    float x = 0, y = 0, z = 0, r = 0, h = 0, ig = -1.0f; int flag = 1; int id = -1;
    int got = sscanf(line, "%*s %31s %f %f %f %f %f %f %d", verb, &x, &y, &z, &r, &h, &ig, &flag);

    if (strcmp(verb, "add") == 0 && got >= 6) {
        void* mgr = Manager();
        if (!mgr) { Log("add: no obstacle manager (level not loaded?)"); LuaSet("MercNavObstacleResult=-1"); return; }
        ObstacleDesc d = { x, y, z, r, h, ig, (uint8_t)(flag ? 1 : 0), {0, 0, 0} };
        id = g_add(mgr, &d);
        { std::lock_guard<std::mutex> lk(g_mutex); g_ours.push_back(id); }
        char code[96]; snprintf(code, sizeof code, "MercNavObstacleResult=%d", id);
        LuaSet(code);
    } else if (strcmp(verb, "remove") == 0 && got >= 2) {
        id = (int)x;
        void* mgr = Manager();
        if (mgr) g_remove(mgr, id);
        std::lock_guard<std::mutex> lk(g_mutex);
        for (size_t i = 0; i < g_ours.size(); ++i) if (g_ours[i] == id) { g_ours.erase(g_ours.begin() + i); break; }
        LuaSet("MercNavObstacleResult=0");
    } else if (strcmp(verb, "clear") == 0) {
        void* mgr = Manager();
        std::vector<int> mine;
        { std::lock_guard<std::mutex> lk(g_mutex); mine.swap(g_ours); }
        if (mgr) for (int i : mine) g_remove(mgr, i);
        char code[96]; snprintf(code, sizeof code, "MercNavObstacleResult=%d", (int)mine.size());
        LuaSet(code);
    } else if (strcmp(verb, "status") == 0) {
        size_t n; { std::lock_guard<std::mutex> lk(g_mutex); n = g_ours.size(); }
        char msg[256];
        snprintf(msg, sizeof msg, "plugin up; %u obstacle(s) of ours; manager %s", (unsigned)n, Manager() ? "present" : "ABSENT");
        LuaSay(msg);
        char code[96]; snprintf(code, sizeof code, "MercNavObstacleResult=%d", (int)n);
        LuaSet(code);
    } else {
        LuaSay("merc_navobst add <x> <y> <z> <radius> <height> [ignoreRadius] [flag] | remove <id> | clear | status");
    }
}

void RegisterCommand() {
    if (g_registered) return;
    void* console = *(void**)(g_env + OFF_pConsole);
    if (!console) { Log("register: no console yet"); return; }
    ((AddCommandFn)(*(void***)console)[SLOT_AddCommand])(console, "merc_navobst", &Command, 0,
        "Navigation obstacle: add <x> <y> <z> <radius> <height> [ignoreRadius] [flag] | remove <id> | clear | status");
    g_registered = true;
    LuaSet("MercNavPlugin={version=1}");
    Log("merc_navobst registered");
}

// IGame::CompleteInit runs once, on the game thread, after every subsystem exists: the right
// moment to touch the console's command map, which is not thread-safe.
void __fastcall HookCompleteInit(void* game) {
    if (g_origCompleteInit) g_origCompleteInit(game);
    RegisterCommand();
}

bool HookGame() {
    void* game = *(void**)(g_env + OFF_pGame);
    if (!game) return false;
    void** vt = *(void***)game;
    DWORD old;
    if (!VirtualProtect(&vt[SLOT_CompleteInit], sizeof(void*), PAGE_READWRITE, &old)) { Log("VirtualProtect failed"); return false; }
    g_origCompleteInit = (CompleteInitFn)vt[SLOT_CompleteInit];
    vt[SLOT_CompleteInit] = (void*)&HookCompleteInit;
    VirtualProtect(&vt[SLOT_CompleteInit], sizeof(void*), old, &old);
    Log("hooked IGame::CompleteInit (orig %p)", (void*)g_origCompleteInit);
    return true;
}

DWORD WINAPI InitThread(void*) {
    HMODULE whgame = nullptr;
    for (int i = 0; i < 2400 && !whgame; ++i) { whgame = GetModuleHandleA("WHGame.dll"); if (!whgame) Sleep(250); }
    if (!whgame) { Log("WHGame.dll never appeared"); return 0; }
    if (!Resolve(whgame)) { Log("signatures failed - plugin inactive (game patched? re-derive from the corpus)"); return 0; }

    // Wait for the game object, hook its CompleteInit. If init already finished (we were
    // injected late), register from here and say so.
    for (int i = 0; i < 2400; ++i) {
        if (*(void**)(g_env + OFF_pGame)) break;
        Sleep(50);
    }
    if (!*(void**)(g_env + OFF_pGame)) { Log("gEnv->pGame never set"); return 0; }

    // Loaded at process start (ASI loader): the hook fires during init, on the game thread.
    // Injected later, for a test: init is long over, the hook never fires, and after a grace
    // period the command is registered from here - a race on the console's map in theory,
    // harmless at the main menu in practice, and it is only the development path.
    bool hooked = HookGame();
    for (int i = 0; i < 300 && !g_registered; ++i) Sleep(100);
    if (!g_registered) {
        Log(hooked ? "CompleteInit did not fire within 30s (injected after init?) - registering directly"
                   : "could not hook - registering directly");
        while (!*(void**)(g_env + OFF_pConsole) || !*(void**)(g_env + OFF_pScriptSystem)) Sleep(250);
        RegisterCommand();
    }
    return 0;
}

} // namespace

BOOL APIENTRY DllMain(HMODULE self, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(self);
        GetModuleFileNameA(self, g_logPath, MAX_PATH);
        if (char* dot = strrchr(g_logPath, '.')) strcpy(dot, ".log");
        Log("mercenaries_nav loaded");
        CreateThread(nullptr, 0, InitThread, nullptr, 0, nullptr);
    }
    return TRUE;
}
