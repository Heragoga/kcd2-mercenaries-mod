"""Load a DLL into the running game for a test, without an ASI loader.

    python tools/inject_dll.py native\mercnav\out\mercenaries_nav.asi

Classic LoadLibraryA-via-CreateRemoteThread. For development only: players get the same DLL
through Ultimate ASI Loader (see native/mercnav/README.md).
"""
import ctypes, ctypes.wintypes as wt, os, sys, time

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
PROCESS_ALL_ACCESS = 0x1F0FFF
MEM_COMMIT, MEM_RESERVE, PAGE_READWRITE = 0x1000, 0x2000, 0x04

k32.OpenProcess.restype = wt.HANDLE
k32.VirtualAllocEx.restype = wt.LPVOID
k32.VirtualAllocEx.argtypes = [wt.HANDLE, wt.LPVOID, ctypes.c_size_t, wt.DWORD, wt.DWORD]
k32.WriteProcessMemory.argtypes = [wt.HANDLE, wt.LPVOID, wt.LPCVOID, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
k32.GetModuleHandleA.restype = wt.HMODULE
k32.GetProcAddress.restype = wt.LPVOID
k32.GetProcAddress.argtypes = [wt.HMODULE, ctypes.c_char_p]
k32.CreateRemoteThread.restype = wt.HANDLE
k32.CreateRemoteThread.argtypes = [wt.HANDLE, wt.LPVOID, ctypes.c_size_t, wt.LPVOID, wt.LPVOID, wt.DWORD, wt.LPDWORD]


def pid_of(name):
    import subprocess
    out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq %s" % name, "/FO", "CSV", "/NH"],
                         capture_output=True, text=True).stdout
    for line in out.splitlines():
        if line.startswith('"'):
            return int(line.split('","')[1].strip('"'))
    return None


def inject(pid, dll):
    dll = os.path.abspath(dll).encode() + b"\x00"
    h = k32.OpenProcess(PROCESS_ALL_ACCESS, False, pid)
    if not h:
        raise OSError(ctypes.get_last_error(), "OpenProcess")
    mem = k32.VirtualAllocEx(h, None, len(dll), MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE)
    written = ctypes.c_size_t(0)
    if not k32.WriteProcessMemory(h, mem, dll, len(dll), ctypes.byref(written)):
        raise OSError(ctypes.get_last_error(), "WriteProcessMemory")
    loadlib = k32.GetProcAddress(k32.GetModuleHandleA(b"kernel32.dll"), b"LoadLibraryA")
    th = k32.CreateRemoteThread(h, None, 0, loadlib, mem, 0, None)
    if not th:
        raise OSError(ctypes.get_last_error(), "CreateRemoteThread")
    k32.WaitForSingleObject(th, 10000)
    code = wt.DWORD(0)
    k32.GetExitCodeThread(th, ctypes.byref(code))
    return code.value


if __name__ == "__main__":
    dll = sys.argv[1] if len(sys.argv) > 1 else r"native\mercnav\out\mercenaries_nav.asi"
    pid = pid_of("KingdomCome.exe")
    if not pid:
        sys.exit("KingdomCome.exe is not running")
    rc = inject(pid, dll)
    print("injected into pid %d, LoadLibrary returned 0x%x (%s)" % (pid, rc, "ok" if rc else "FAILED"))
