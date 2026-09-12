import codecs
import ctypes
import os
import queue
import re
import socket
import struct
import subprocess
import sys
import threading
import time
from collections import namedtuple
from ctypes import wintypes
from tkinter import messagebox

import customtkinter as ctk


# =========================================================
# 1. HIDE BACKGROUND CONSOLE & ADMIN ELEVATION
# =========================================================
def hide_console():
    try:
        hwnd = ctypes.windll.kernel32.GetConsoleWindow()
        if hwnd != 0:
            ctypes.windll.user32.ShowWindow(hwnd, 0)
    except Exception:
        pass


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def relaunch_as_admin():
    executable = sys.executable.replace("python.exe", "pythonw.exe")
    ctypes.windll.shell32.ShellExecuteW(
        None, "runas", executable, f'"{os.path.abspath(__file__)}"', None, 0
    )


# =========================================================
# 2. NATIVE PROCESS INSPECTION (no PowerShell, no psutil)
# =========================================================
# `dotnet watch run`, `npm run dev` and `python -m http.server` never put the
# project path on their command line, so matching command lines alone cannot
# tell whose `dotnet.exe` is whose. Each process's WORKING DIRECTORY can: it is
# read straight out of the process's PEB. Listening ports come from the TCP
# table. Both are plain Win32 calls, cheap enough to poll every couple of
# seconds without spawning a PowerShell each time.

_kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
_ntdll = ctypes.WinDLL("ntdll")
_iphlpapi = ctypes.WinDLL("iphlpapi")

_IS_64BIT = ctypes.sizeof(ctypes.c_void_p) == 8

TH32CS_SNAPPROCESS = 0x00000002
PROCESS_VM_READ = 0x0010
PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value
ProcessBasicInformation = 0
ProcessCommandLineInformation = 60
TCP_TABLE_OWNER_PID_LISTENER = 3
ERROR_INSUFFICIENT_BUFFER = 122


class PROCESSENTRY32W(ctypes.Structure):
    _fields_ = [
        ("dwSize", wintypes.DWORD),
        ("cntUsage", wintypes.DWORD),
        ("th32ProcessID", wintypes.DWORD),
        ("th32DefaultHeapID", ctypes.c_size_t),
        ("th32ModuleID", wintypes.DWORD),
        ("cntThreads", wintypes.DWORD),
        ("th32ParentProcessID", wintypes.DWORD),
        ("pcPriClassBase", ctypes.c_long),
        ("dwFlags", wintypes.DWORD),
        ("szExeFile", ctypes.c_wchar * 260),
    ]


class UNICODE_STRING(ctypes.Structure):
    _fields_ = [
        ("Length", ctypes.c_ushort),
        ("MaximumLength", ctypes.c_ushort),
        ("Buffer", ctypes.c_void_p),
    ]


class PROCESS_BASIC_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("ExitStatus", ctypes.c_long),
        ("PebBaseAddress", ctypes.c_void_p),
        ("AffinityMask", ctypes.c_size_t),
        ("BasePriority", ctypes.c_long),
        ("UniqueProcessId", ctypes.c_size_t),
        ("InheritedFromUniqueProcessId", ctypes.c_size_t),
    ]


_kernel32.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
_kernel32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
_kernel32.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
_kernel32.Process32FirstW.restype = wintypes.BOOL
_kernel32.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
_kernel32.Process32NextW.restype = wintypes.BOOL
_kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
_kernel32.OpenProcess.restype = wintypes.HANDLE
_kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
_kernel32.CloseHandle.restype = wintypes.BOOL
_kernel32.ReadProcessMemory.argtypes = [
    wintypes.HANDLE, ctypes.c_void_p, ctypes.c_void_p,
    ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t),
]
_kernel32.ReadProcessMemory.restype = wintypes.BOOL
_kernel32.IsWow64Process.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.BOOL)]
_kernel32.IsWow64Process.restype = wintypes.BOOL
_kernel32.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(ctypes.c_ulonglong)] * 4
_kernel32.GetProcessTimes.restype = wintypes.BOOL
_ntdll.NtQueryInformationProcess.argtypes = [
    wintypes.HANDLE, wintypes.ULONG, ctypes.c_void_p,
    wintypes.ULONG, ctypes.POINTER(wintypes.ULONG),
]
_ntdll.NtQueryInformationProcess.restype = ctypes.c_long
_iphlpapi.GetExtendedTcpTable.argtypes = [
    ctypes.c_void_p, ctypes.POINTER(wintypes.DWORD), wintypes.BOOL,
    wintypes.ULONG, ctypes.c_int, wintypes.ULONG,
]
_iphlpapi.GetExtendedTcpTable.restype = wintypes.DWORD


def list_processes():
    """{pid: (parent pid, lowercase exe name)} for every process on the machine."""
    procs = {}
    snap = _kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    if not snap or snap == INVALID_HANDLE_VALUE:
        return procs
    try:
        entry = PROCESSENTRY32W()
        entry.dwSize = ctypes.sizeof(PROCESSENTRY32W)
        ok = _kernel32.Process32FirstW(snap, ctypes.byref(entry))
        while ok:
            procs[entry.th32ProcessID] = (
                entry.th32ParentProcessID,
                entry.szExeFile.lower(),
            )
            ok = _kernel32.Process32NextW(snap, ctypes.byref(entry))
    finally:
        _kernel32.CloseHandle(snap)
    return procs


def _read_memory(handle, address, size):
    buf = ctypes.create_string_buffer(size)
    read = ctypes.c_size_t(0)
    ok = _kernel32.ReadProcessMemory(
        handle, ctypes.c_void_p(address), buf, size, ctypes.byref(read)
    )
    return buf.raw if ok and read.value == size else None


def _query_cmdline(handle):
    size = wintypes.ULONG(0)
    _ntdll.NtQueryInformationProcess(
        handle, ProcessCommandLineInformation, None, 0, ctypes.byref(size)
    )
    if not size.value:
        return ""
    buf = ctypes.create_string_buffer(size.value)
    status = _ntdll.NtQueryInformationProcess(
        handle, ProcessCommandLineInformation, buf, size.value, ctypes.byref(size)
    )
    if status != 0:
        return ""
    text = UNICODE_STRING.from_buffer(buf)
    if not text.Buffer or not text.Length:
        return ""
    return ctypes.wstring_at(text.Buffer, text.Length // 2)


def _query_cwd(handle):
    # The PEB offsets below are the x64 layout; every tool we watch is 64-bit.
    if not _IS_64BIT:
        return ""
    wow64 = wintypes.BOOL(False)
    if _kernel32.IsWow64Process(handle, ctypes.byref(wow64)) and wow64.value:
        return ""

    pbi = PROCESS_BASIC_INFORMATION()
    status = _ntdll.NtQueryInformationProcess(
        handle, ProcessBasicInformation, ctypes.byref(pbi), ctypes.sizeof(pbi), None
    )
    if status != 0 or not pbi.PebBaseAddress:
        return ""

    raw = _read_memory(handle, pbi.PebBaseAddress + 0x20, 8)  # PEB.ProcessParameters
    if raw is None:
        return ""
    params = struct.unpack("<Q", raw)[0]

    # RTL_USER_PROCESS_PARAMETERS.CurrentDirectory.DosPath (UNICODE_STRING)
    raw = _read_memory(handle, params + 0x38, 16)
    if raw is None:
        return ""
    length, _maximum, buffer = struct.unpack("<HH4xQ", raw)
    if not buffer or not length:
        return ""
    raw = _read_memory(handle, buffer, length)
    return raw.decode("utf-16-le", "replace") if raw else ""


def _query_created(handle):
    created, exited, kernel, user = (ctypes.c_ulonglong() for _ in range(4))
    ok = _kernel32.GetProcessTimes(
        handle,
        ctypes.byref(created), ctypes.byref(exited),
        ctypes.byref(kernel), ctypes.byref(user),
    )
    return created.value if ok else 0


def _safe(fn, *args):
    try:
        return fn(*args)
    except Exception:
        return None


def inspect_process(pid):
    """(command line, working directory, creation time); blanks when unreadable."""
    handle = _kernel32.OpenProcess(
        PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, False, pid
    )
    can_read_memory = bool(handle)
    if not handle:
        handle = _kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not handle:
        return "", "", 0
    try:
        cmdline = _safe(_query_cmdline, handle) or ""
        cwd = (_safe(_query_cwd, handle) or "") if can_read_memory else ""
        created = _safe(_query_created, handle) or 0
        return cmdline, cwd, created
    finally:
        _kernel32.CloseHandle(handle)


def listening_ports():
    """{pid: {port, ...}} for every listening TCP socket (IPv4 and IPv6)."""
    result = {}
    # (family, row size, offset of dwLocalPort, offset of dwOwningPid)
    layouts = (
        (socket.AF_INET, 24, 8, 20),   # MIB_TCPROW_OWNER_PID
        (socket.AF_INET6, 56, 20, 52),  # MIB_TCP6ROW_OWNER_PID
    )
    for family, row_size, port_at, pid_at in layouts:
        size = wintypes.DWORD(0)
        _iphlpapi.GetExtendedTcpTable(
            None, ctypes.byref(size), False, family, TCP_TABLE_OWNER_PID_LISTENER, 0
        )
        rc, buf = ERROR_INSUFFICIENT_BUFFER, None
        for _ in range(3):  # the table can grow between the two calls
            buf = ctypes.create_string_buffer(max(size.value, 4))
            rc = _iphlpapi.GetExtendedTcpTable(
                buf, ctypes.byref(size), False, family, TCP_TABLE_OWNER_PID_LISTENER, 0
            )
            if rc != ERROR_INSUFFICIENT_BUFFER:
                break
        if rc != 0:
            continue

        raw = buf.raw
        count = struct.unpack_from("<I", raw, 0)[0]
        for i in range(count):
            base = 4 + i * row_size
            port = socket.ntohs(struct.unpack_from("<I", raw, base + port_at)[0] & 0xFFFF)
            pid = struct.unpack_from("<I", raw, base + pid_at)[0]
            result.setdefault(pid, set()).add(port)
    return result


# =========================================================
# 3. APP DETECTION MODEL
# =========================================================
# A Rule recognises one process of an app:
#   names     - exe names it may have (lowercase)
#   needles   - substrings that must ALL be in its command line; a tuple is
#               "any of these"
#   in_folder - its working directory must be inside the app's folder
#   ready     - this process alone means the app is up (Flutter's runner exe)
Rule = namedtuple("Rule", "names needles in_folder ready", defaults=(False, False))
ProcInfo = namedtuple("ProcInfo", "pid ppid name cmdline cwd created ports")
Snapshot = namedtuple("Snapshot", "infos protected")


def _norm(text):
    return (text or "").lower().replace("/", "\\")


def _norm_rule(rule):
    needles = tuple(
        tuple(_norm(alt) for alt in n) if isinstance(n, tuple) else _norm(n)
        for n in rule.needles
    )
    return rule._replace(names=frozenset(rule.names), needles=needles)


def rule_matches(rule, info, folder):
    if info.name not in rule.names:
        return False
    if rule.in_folder and not (
        info.cwd == folder or info.cwd.startswith(folder + "\\")
    ):
        return False
    for needle in rule.needles:
        if isinstance(needle, tuple):
            if not any(alt in info.cmdline for alt in needle):
                return False
        elif needle not in info.cmdline:
            return False
    return True


def take_snapshot(candidate_names):
    procs = list_processes()
    try:
        listeners = listening_ports()
    except Exception:
        listeners = {}

    infos = {}
    for pid, (ppid, name) in procs.items():
        if name in candidate_names:
            cmdline, cwd, created = inspect_process(pid)
            infos[pid] = ProcInfo(
                pid, ppid, name, _norm(cmdline), _norm(cwd).rstrip("\\"),
                created, frozenset(listeners.get(pid, ())),
            )

    # Never touch this hub or whatever launched it.
    protected = {0, 4, os.getpid()}
    pid = procs.get(os.getpid(), (0, ""))[0]
    while pid and pid not in protected and pid in procs:
        protected.add(pid)
        pid = procs[pid][0]

    return Snapshot(infos, frozenset(protected))


OFFLINE = {"status": "offline", "tree": [], "ports": [], "owned": False}


def detect_app(app, snap):
    """Status of one app: offline / starting (processes, no port yet) / online."""
    folder = app["folder"]
    matched, ready = set(), False

    for info in snap.infos.values():
        if info.pid in snap.protected:
            continue
        rule = next((r for r in app["rules"] if rule_matches(r, info, folder)), None)
        if rule is not None:
            matched.add(info.pid)
            ready = ready or rule.ready
        elif info.name in app["names"] and info.ports & app["ports"]:
            # Holds this app's port but was started some other way.
            matched.add(info.pid)

    proc = app["proc"]
    owned = proc is not None and proc.poll() is None
    if owned:
        matched.add(proc.pid)

    # Pull in the rest of the tree (dotnet watch -> build -> API, npm -> next ->
    # server workers). A child created before its "parent" is a reused PID.
    children = {}
    for info in snap.infos.values():
        children.setdefault(info.ppid, []).append(info)
    tree, stack = set(matched), list(matched)
    while stack:
        parent = snap.infos.get(stack.pop())
        if parent is None:
            continue
        for child in children.get(parent.pid, ()):
            if (
                child.pid in tree
                or child.pid in snap.protected
                or child.name not in app["names"]
                or child.created < parent.created
            ):
                continue
            tree.add(child.pid)
            stack.append(child.pid)

    ports = sorted(set().union(*(snap.infos[p].ports for p in tree if p in snap.infos)))
    if not tree:
        status = "offline"
    elif ready or app["ports"] & set(ports):
        status = "online"
    else:
        status = "starting"

    return {"status": status, "tree": sorted(tree), "ports": ports, "owned": owned}


def taskkill(pids):
    if not pids:
        return
    args = ["taskkill", "/F", "/T"]
    for pid in sorted(pids):
        args += ["/PID", str(pid)]
    try:
        subprocess.run(
            args,
            capture_output=True,
            timeout=30,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
    except Exception:
        pass


def _pid_list(pids):
    return ", ".join(str(p) for p in sorted(pids))


# =========================================================
# 4. MODERN WEB-POS OPERATIONS HUB
# =========================================================
ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

LOG_DIR = os.path.join(
    os.environ.get("LOCALAPPDATA") or os.path.expanduser("~"), "WebPOS-OpsHub", "logs"
)
LOG_HISTORY_BYTES = 64 * 1024
LOG_CHUNK_BYTES = 256 * 1024
MAX_CONSOLE_LINES = 5000
_ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")


def _clean(text):
    return _ANSI.sub("", text).replace("\r\n", "\n").replace("\r", "")


class PosDashboard(ctk.CTk):
    """
    Developer control center for the local Web-POS stack.

    - The watcher finds every app however it was started — from this hub, from
      a previous hub session, or from a terminal — by working directory,
      command line and listening port, and shows it as ONLINE / STARTING.
    - App output goes to a log file per app (%LOCALAPPDATA%\\WebPOS-OpsHub\\logs)
      and the console tails it, so an app can outlive the hub and its output is
      still there when the hub is reopened.
    - KILL ALL (top right) stops every app and its whole process tree.
    - UI updates from worker threads are routed through a queue so Tk stays stable.
    """

    POLL_MS = 2000

    def __init__(self):
        super().__init__()

        self.title("Web-POS Operations Hub")
        self.geometry("1180x860")
        self.minsize(1000, 720)

        self.sql_services = ["MSSQLSERVER", "SQLTELEMETRY", "SQLWriter"]
        self.service_badges = {}
        self.service_btns = {}

        self.apps = {
            "Backend API": {
                "path": r"E:\POS-APP\Back-End\Web-POS.Api",
                "cmd": "dotnet watch run",
                "hot_reload": "dotnet",
                "ports": [5002, 7002],
                # No one can answer dotnet watch's "restart?" prompt any more.
                "env": {"DOTNET_WATCH_RESTART_ON_RUDE_EDIT": "true"},
                "rules": [
                    # The API itself: bin\Debug\net10.0\Web-POS.Api.exe (or .dll).
                    Rule({"web-pos.api.exe", "dotnet.exe"}, ["\\web-pos.api\\bin\\"]),
                    # dotnet watch / dotnet run and their cmd wrapper: no path on
                    # the command line, recognised by their working directory.
                    Rule({"dotnet.exe", "cmd.exe"}, ["watch"], in_folder=True),
                    Rule({"dotnet.exe", "cmd.exe"}, [(" run", '"run"')], in_folder=True),
                ],
            },
            "POS App (Debug)": {
                "path": r"E:\POS-APP\Front-End",
                "cmd": "flutter run -d windows",
                "hot_reload": "flutter",
                "ports": [],
                "rules": [
                    Rule({"pos_app.exe"}, ["\\front-end\\build\\windows\\"], ready=True),
                    Rule({"dart.exe", "cmd.exe"}, [(" run ", '"run"'), "windows"], in_folder=True),
                ],
            },
            "KDS (Debug)": {
                "path": r"E:\POS-APP\kitchen_display",
                "cmd": "flutter run -d windows",
                "hot_reload": "flutter",
                "ports": [],
                "rules": [
                    Rule({"kitchen_display.exe"}, ["\\kitchen_display\\build\\windows\\"], ready=True),
                    Rule({"dart.exe", "cmd.exe"}, [(" run ", '"run"'), "windows"], in_folder=True),
                ],
            },
            "Dashboard (Release)": {
                "path": r"E:\POS-APP\octopus_dashboard_web",
                "cmd": r"flutter build web && cd build\web && python -m http.server 8081 --bind 100.114.12.38",
                "hot_reload": None,
                "ports": [8081],
                "rules": [
                    # The server (and the cmd running the whole chain) carries no
                    # path — the port pins it.
                    Rule({"python.exe", "py.exe", "cmd.exe"}, ["http.server", "8081"]),
                    # The `flutter build web` step before the server comes up.
                    Rule({"dart.exe"}, ["build", "web"], in_folder=True),
                ],
            },
            "Node.js Web": {
                "path": r"E:\POS-APP\website",
                "cmd": "npm run dev",
                "hot_reload": "node",
                "ports": [3000],
                "rules": [
                    # next dev and its server workers run from website\node_modules.
                    Rule({"node.exe"}, ["\\website\\node_modules\\next\\"]),
                    # npm run dev / cmd wrappers, recognised by working directory.
                    Rule({"node.exe", "cmd.exe"}, ["dev"], in_folder=True),
                ],
            },
        }

        for app in self.apps.values():
            app["proc"] = None
            app["folder"] = _norm(app["path"]).rstrip("\\")
            app["rules"] = [_norm_rule(r) for r in app["rules"]]
            app["ports"] = frozenset(app["ports"])
            app["names"] = frozenset().union(*(r.names for r in app["rules"]))
        self._candidate_names = frozenset().union(*(a["names"] for a in self.apps.values()))

        self.log_boxes = {}
        self.app_buttons = {}
        self.status_badges = {}
        self.detail_labels = {}
        self.action_buttons = {}
        self.app_states = {name: None for name in self.apps}
        self.current_view = "Backend API"

        os.makedirs(LOG_DIR, exist_ok=True)
        self._log_offsets = {name: 0 for name in self.apps}
        self._decoders = {
            name: codecs.getincrementaldecoder("utf-8")(errors="replace")
            for name in self.apps
        }

        self.ui_queue = queue.Queue()
        self._watch_lock = threading.Lock()
        self._action_lock = threading.Lock()
        self._services_busy = False
        self._closing = False

        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(3, weight=1)

        self._build_header()
        self._build_sql_card()
        self._build_launchers_card()
        self._build_console_card()

        for name in self.apps:
            self._load_log_history(name)

        self.protocol("WM_DELETE_WINDOW", self.on_close)

        self.after(150, self.process_ui_queue)
        self.after(100, self.watch_apps)
        self.after(300, self.poll_service_status)

    # =========================================================
    # UI
    # =========================================================
    def _build_header(self):
        header = ctk.CTkFrame(self, fg_color="transparent")
        header.grid(row=0, column=0, padx=20, pady=(15, 5), sticky="ew")
        header.grid_columnconfigure(1, weight=1)

        ctk.CTkLabel(
            header,
            text="Web-POS Developer Control Center",
            font=ctk.CTkFont(size=22, weight="bold"),
        ).grid(row=0, column=0, sticky="w")

        self.global_status = ctk.CTkLabel(
            header,
            text="● WATCHING NOW",
            font=ctk.CTkFont(size=11, weight="bold"),
            text_color="#34D399",
        )
        self.global_status.grid(row=0, column=1, sticky="e", padx=(0, 12))

        self.kill_btn = ctk.CTkButton(
            header,
            text="⏻  KILL ALL",
            width=120,
            height=32,
            font=ctk.CTkFont(size=12, weight="bold"),
            fg_color="#B91C1C",
            hover_color="#DC2626",
            command=self.kill_all,
        )
        self.kill_btn.grid(row=0, column=2, sticky="e")

    def _build_sql_card(self):
        card = ctk.CTkFrame(
            self,
            corner_radius=12,
            fg_color="#18181B",
            border_width=1,
            border_color="#27272A",
        )
        card.grid(row=1, column=0, padx=20, pady=10, sticky="ew")

        ctk.CTkLabel(
            card,
            text="SQL SERVER DATABASE SERVICES",
            font=ctk.CTkFont(size=11, weight="bold"),
            text_color="#71717A",
        ).pack(anchor="w", padx=15, pady=(12, 8))

        for svc in self.sql_services:
            row = ctk.CTkFrame(card, fg_color="#27272A", corner_radius=8)
            row.pack(fill="x", padx=15, pady=4)

            ctk.CTkLabel(
                row,
                text=svc,
                font=ctk.CTkFont(size=13),
                width=180,
                anchor="w",
            ).pack(side="left", padx=12, pady=8)

            badge = ctk.CTkLabel(
                row,
                text="CHECKING",
                font=ctk.CTkFont(size=11, weight="bold"),
                corner_radius=6,
                fg_color="#3F3F46",
                text_color="#FFFFFF",
                width=100,
                height=24,
            )
            badge.pack(side="left", padx=10)
            self.service_badges[svc] = badge

            btn = ctk.CTkButton(
                row,
                text="Toggle",
                width=80,
                height=28,
                fg_color="#3F3F46",
                hover_color="#52525B",
                command=lambda s=svc: self.toggle_service(s),
            )
            btn.pack(side="right", padx=10)
            self.service_btns[svc] = btn

        ctk.CTkFrame(card, height=8, fg_color="transparent").pack()

    def _build_launchers_card(self):
        card = ctk.CTkFrame(
            self,
            corner_radius=12,
            fg_color="#18181B",
            border_width=1,
            border_color="#27272A",
        )
        card.grid(row=2, column=0, padx=20, pady=10, sticky="ew")

        ctk.CTkLabel(
            card,
            text="APPLICATIONS",
            font=ctk.CTkFont(size=11, weight="bold"),
            text_color="#71717A",
        ).pack(anchor="w", padx=15, pady=(12, 8))

        container = ctk.CTkFrame(card, fg_color="transparent")
        container.pack(fill="x", padx=15, pady=(0, 15))

        for app_name in self.apps:
            row = ctk.CTkFrame(container, fg_color="#27272A", corner_radius=9)
            row.pack(side="left", fill="x", expand=True, padx=(0, 8))

            top = ctk.CTkFrame(row, fg_color="transparent")
            top.pack(fill="x", padx=10, pady=(8, 0))

            ctk.CTkLabel(
                top,
                text=app_name,
                font=ctk.CTkFont(size=12, weight="bold"),
                anchor="w",
            ).pack(side="left", fill="x", expand=True)

            badge = ctk.CTkLabel(
                top,
                text="● CHECKING",
                font=ctk.CTkFont(size=9, weight="bold"),
                text_color="#A1A1AA",
            )
            badge.pack(side="right")
            self.status_badges[app_name] = badge

            detail = ctk.CTkLabel(
                row,
                text="checking…",
                font=ctk.CTkFont(size=10),
                text_color="#71717A",
                anchor="w",
                justify="left",
                wraplength=190,
            )
            detail.pack(fill="x", padx=10)
            self.detail_labels[app_name] = detail

            btn = ctk.CTkButton(
                row,
                text="▶ Start",
                height=30,
                fg_color="#064E3B",
                hover_color="#065F46",
                command=lambda n=app_name: self.start_app(n),
            )
            btn.pack(fill="x", padx=10, pady=(4, 9))
            self.app_buttons[app_name] = btn

    def _build_console_card(self):
        card = ctk.CTkFrame(
            self,
            corner_radius=12,
            fg_color="#18181B",
            border_width=1,
            border_color="#27272A",
        )
        card.grid(row=3, column=0, padx=20, pady=(0, 20), sticky="nsew")
        card.grid_columnconfigure(0, weight=1)
        card.grid_rowconfigure(1, weight=1)

        top_bar = ctk.CTkFrame(card, fg_color="transparent")
        top_bar.grid(row=0, column=0, sticky="ew", padx=15, pady=(12, 8))

        ctk.CTkLabel(
            top_bar,
            text="CONSOLE",
            font=ctk.CTkFont(size=11, weight="bold"),
            text_color="#71717A",
        ).pack(side="left", padx=(0, 10))

        self.view_selector = ctk.CTkComboBox(
            top_bar,
            values=list(self.apps.keys()),
            command=self.switch_console_view,
            width=210,
            fg_color="#09090B",
        )
        self.view_selector.set("Backend API")
        self.view_selector.pack(side="left")

        self.clear_btn = ctk.CTkButton(
            top_bar,
            text="Clear Log",
            width=95,
            fg_color="#27272A",
            hover_color="#3F3F46",
            command=self.clear_current_log,
        )
        self.clear_btn.pack(side="right")

        self.log_container = ctk.CTkFrame(card, fg_color="transparent")
        self.log_container.grid(
            row=1, column=0, sticky="nsew", padx=15, pady=(0, 8)
        )
        self.log_container.grid_columnconfigure(0, weight=1)
        self.log_container.grid_rowconfigure(0, weight=1)

        for app_name in self.apps:
            box = ctk.CTkTextbox(
                self.log_container,
                fg_color="#09090B",
                text_color="#A7F3D0",
                font=ctk.CTkFont(family="Consolas", size=12),
                border_width=1,
                border_color="#27272A",
                wrap="none",
            )
            box.grid(row=0, column=0, sticky="nsew")
            # Output-only console.
            box.configure(state="disabled")
            self.log_boxes[app_name] = box

        # -----------------------------------------------------
        # Per-app controls BELOW the console
        # -----------------------------------------------------
        controls = ctk.CTkFrame(card, fg_color="#111113", corner_radius=10)
        controls.grid(row=2, column=0, sticky="ew", padx=15, pady=(0, 12))

        action_row = ctk.CTkFrame(controls, fg_color="transparent")
        action_row.pack(fill="x", padx=8, pady=8)

        self.action_buttons["start"] = ctk.CTkButton(
            action_row, text="▶ Start", width=100,
            fg_color="#064E3B", hover_color="#065F46",
            command=lambda: self.start_app(self.current_view)
        )
        self.action_buttons["start"].pack(side="left", padx=4)

        self.action_buttons["restart"] = ctk.CTkButton(
            action_row, text="↻ Restart", width=100,
            fg_color="#1D4ED8", hover_color="#2563EB",
            command=lambda: self.restart_app(self.current_view)
        )
        self.action_buttons["restart"].pack(side="left", padx=4)

        self.action_buttons["stop"] = ctk.CTkButton(
            action_row, text="■ Stop", width=100,
            fg_color="#991B1B", hover_color="#B91C1C",
            command=lambda: self.stop_app(self.current_view)
        )
        self.action_buttons["stop"].pack(side="left", padx=4)

        self.action_buttons["hot_reload"] = ctk.CTkButton(
            action_row, text="⚡ Hot Reload", width=120,
            fg_color="#7C3AED", hover_color="#8B5CF6",
            command=lambda: self.hot_reload(self.current_view)
        )
        self.action_buttons["hot_reload"].pack(side="left", padx=4)

        self.switch_console_view("Backend API")

    # =========================================================
    # UI QUEUE / CONSOLE
    # =========================================================
    def post(self, item):
        self.ui_queue.put(item)

    def post_log(self, app_name, text):
        if text:
            self.post(("log", app_name, text))

    def process_ui_queue(self):
        try:
            # Tail the log files first so an "exited" notice lands after the
            # last lines the app wrote.
            self._pump_logs()
            while True:
                item = self.ui_queue.get_nowait()
                try:
                    self._handle_ui_item(item)
                except Exception:
                    pass
        except queue.Empty:
            pass
        finally:
            if not self._closing:
                self.after(150, self.process_ui_queue)

    def _handle_ui_item(self, item):
        kind = item[0]
        if kind == "log":
            self._append(item[1], item[2])
        elif kind == "reset":
            # A new run truncated this app's log: re-read it from the top.
            name = item[1]
            self._clear_box(name)
            self._log_offsets[name] = 0
            self._decoders[name].reset()
        elif kind == "states":
            self.apply_app_states(item[1])
        elif kind == "watch_error":
            self.global_status.configure(
                text=f"● WATCHER ERROR — {item[1]}", text_color="#FBBF24"
            )
        elif kind == "services":
            self.apply_service_states(item[1])
        elif kind == "call":
            item[1]()

    def _append(self, app_name, text):
        box = self.log_boxes.get(app_name)
        if box is None or not text:
            return
        try:
            at_bottom = box.yview()[1] >= 0.999
        except Exception:
            at_bottom = True
        box.configure(state="normal")
        box.insert("end", text)
        lines = int(box.index("end-1c").split(".")[0])
        if lines > MAX_CONSOLE_LINES:
            box.delete("1.0", f"{lines - MAX_CONSOLE_LINES}.0")
        box.configure(state="disabled")
        if at_bottom:
            box.see("end")

    def _clear_box(self, app_name):
        box = self.log_boxes[app_name]
        box.configure(state="normal")
        box.delete("1.0", "end")
        box.configure(state="disabled")

    def _log_path(self, app_name):
        slug = re.sub(r"[^a-z0-9]+", "-", app_name.lower()).strip("-")
        return os.path.join(LOG_DIR, f"{slug}.log")

    def _load_log_history(self, app_name):
        """Show the tail of the last run's log — live output if it is still running."""
        path = self._log_path(app_name)
        try:
            size = os.path.getsize(path)
            start = max(0, size - LOG_HISTORY_BYTES)
            with open(path, "rb") as f:
                f.seek(start)
                data = f.read(size - start)
            written = time.strftime("%Y-%m-%d %H:%M", time.localtime(os.path.getmtime(path)))
        except OSError:
            return

        self._log_offsets[app_name] = start + len(data)
        text = data.decode("utf-8", "replace")
        if start > 0:
            text = text.split("\n", 1)[-1]  # drop the partial first line
        self._append(
            app_name, f"──── last output (log written {written}) ────\n{_clean(text)}"
        )

    def _pump_logs(self):
        for name in self.apps:
            path = self._log_path(name)
            try:
                size = os.path.getsize(path)
            except OSError:
                continue

            offset = self._log_offsets[name]
            if size < offset:  # truncated by a new run
                offset = 0
                self._decoders[name].reset()
            if size == offset:
                continue

            try:
                with open(path, "rb") as f:
                    f.seek(offset)
                    data = f.read(min(size - offset, LOG_CHUNK_BYTES))
            except OSError:
                continue

            self._log_offsets[name] = offset + len(data)
            self._append(name, _clean(self._decoders[name].decode(data)))

    # =========================================================
    # WATCHER
    # =========================================================
    def _snapshot(self):
        return take_snapshot(self._candidate_names)

    def _detect(self, app_name, snap):
        return detect_app(self.apps[app_name], snap)

    def watch_apps(self):
        if self._closing:
            return
        self.refresh_now()
        self.after(self.POLL_MS, self.watch_apps)

    def refresh_now(self):
        """Run one watcher pass now. Safe to call from any thread."""
        if self._closing or not self._watch_lock.acquire(blocking=False):
            return

        def worker():
            try:
                snap = self._snapshot()
                self.post(("states", {n: self._detect(n, snap) for n in self.apps}))
            except Exception as exc:
                self.post(("watch_error", str(exc)))
            finally:
                self._watch_lock.release()

        threading.Thread(target=worker, daemon=True).start()

    def _describe(self, app_name, st):
        if st["status"] == "offline":
            return "not running"

        bits = []
        declared = self.apps[app_name]["ports"]
        if declared:
            # Only the app's own ports: dotnet watch also listens on random
            # hot-reload ports that would read as "the API is on :59822".
            shown = [p for p in st["ports"] if p in declared]
            bits.append(" ".join(f":{p}" for p in shown) if shown else "no port yet")
        count = len(st["tree"])
        bits.append(f"{count} proc" + ("" if count == 1 else "s"))
        bits.append("started here" if st["owned"] else "background")
        return " · ".join(bits)

    def apply_app_states(self, states):
        for app_name, st in states.items():
            previous = self.app_states.get(app_name)
            self.app_states[app_name] = st

            badge = self.status_badges[app_name]
            launcher = self.app_buttons[app_name]
            status = st["status"]

            if status == "online":
                badge.configure(text="● ONLINE", text_color="#34D399")
            elif status == "starting":
                badge.configure(text="● STARTING", text_color="#FBBF24")
            else:
                badge.configure(text="● OFFLINE", text_color="#F87171")

            if status == "offline":
                launcher.configure(
                    text="▶ Start",
                    fg_color="#064E3B",
                    hover_color="#065F46",
                    command=lambda n=app_name: self.start_app(n),
                )
            else:
                launcher.configure(
                    text="■ Stop",
                    fg_color="#991B1B",
                    hover_color="#B91C1C",
                    command=lambda n=app_name: self.stop_app(n),
                )

            self.detail_labels[app_name].configure(text=self._describe(app_name, st))

            came_up = previous is None or previous["status"] == "offline"
            if status != "offline" and not st["owned"] and came_up:
                self._append(
                    app_name,
                    f"\n>>> {app_name} is already running in the background "
                    f"({self._describe(app_name, st)}; PID {_pid_list(st['tree'])}).\n"
                    ">>> Stop / KILL ALL will shut it down. Output of a run started "
                    "outside this hub is not captured here.\n",
                )

        running = sum(1 for s in self.app_states.values() if s and s["status"] != "offline")
        self.global_status.configure(
            text=f"● WATCHING NOW · {running}/{len(self.apps)} running · "
            f"{time.strftime('%H:%M:%S')}",
            text_color="#34D399",
        )
        self.update_action_buttons()

    # =========================================================
    # APP ACTIONS
    # =========================================================
    def switch_console_view(self, app_name):
        if app_name not in self.apps:
            return

        self.current_view = app_name
        self.log_boxes[app_name].tkraise()
        self.update_action_buttons()

    def _select(self, app_name):
        self.view_selector.set(app_name)
        self.switch_console_view(app_name)

    def update_action_buttons(self):
        app = self.apps[self.current_view]
        st = self.app_states.get(self.current_view) or OFFLINE
        running = st["status"] != "offline"

        self.action_buttons["start"].configure(state="disabled" if running else "normal")
        self.action_buttons["stop"].configure(state="normal" if running else "disabled")
        self.action_buttons["restart"].configure(state="normal")

        if app["hot_reload"] is None:
            self.action_buttons["hot_reload"].configure(
                state="disabled",
                text="⚡ Not Supported",
            )
        else:
            self.action_buttons["hot_reload"].configure(
                state="normal",
                text="⚡ Hot Reload",
            )

    def _run_action(self, fn):
        """Run a start/stop/restart off the UI thread, one action at a time."""
        def worker():
            with self._action_lock:
                try:
                    fn()
                except Exception as exc:
                    self.post_log(self.current_view, f"\n>>> Action failed: {exc}\n")
            self.refresh_now()

        threading.Thread(target=worker, daemon=True).start()

    def start_app(self, app_name):
        self._select(app_name)
        self._run_action(lambda: self._start_blocking(app_name))

    def stop_app(self, app_name):
        self._select(app_name)
        self._run_action(lambda: self._stop_apps_blocking([app_name]))

    def restart_app(self, app_name):
        self._select(app_name)
        self.post_log(app_name, f"\n>>> Restart requested for {app_name}...\n")

        def fn():
            self._stop_apps_blocking([app_name], announce_idle=False)
            self._start_blocking(app_name)

        self._run_action(fn)

    def kill_all(self):
        self.kill_btn.configure(state="disabled", text="Stopping…")
        self.global_status.configure(
            text="● KILL ALL — stopping everything…", text_color="#F87171"
        )

        def fn():
            stopped = 0
            try:
                stopped = self._stop_apps_blocking(list(self.apps), announce_idle=False)
            finally:
                self.post(("call", lambda: self._kill_all_done(stopped)))

        self._run_action(fn)

    def _kill_all_done(self, stopped):
        self.kill_btn.configure(state="normal", text="⏻  KILL ALL")
        if not stopped:
            self._append(self.current_view, "\n>>> KILL ALL: nothing was running.\n")

    def _start_blocking(self, app_name):
        st = self._detect(app_name, self._snapshot())
        if st["status"] != "offline":
            self.post_log(
                app_name,
                f"\n>>> {app_name} is already running ({self._describe(app_name, st)}). "
                "No second instance started.\n",
            )
            return
        self._launch(app_name)

    def _launch(self, app_name):
        app = self.apps[app_name]
        env = os.environ.copy()
        env.update(app.get("env", {}))
        env["PYTHONUNBUFFERED"] = "1"

        try:
            # Output goes to a file, not a pipe: the app keeps running (and
            # keeps logging) if the hub closes, and the next hub picks it up.
            with open(self._log_path(app_name), "wb") as log:
                log.write(
                    f">>> {app_name} started by Operations Hub at "
                    f"{time.strftime('%Y-%m-%d %H:%M:%S')}\n"
                    f">>> Command: {app['cmd']}\n\n".encode("utf-8")
                )
                log.flush()
                proc = subprocess.Popen(
                    ["cmd.exe", "/c", app["cmd"]],
                    cwd=app["path"],
                    # Flutter reads its r / R keys from stdin; nothing else needs it.
                    stdin=subprocess.PIPE if app["hot_reload"] == "flutter" else subprocess.DEVNULL,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    env=env,
                    creationflags=subprocess.CREATE_NO_WINDOW,
                )
        except Exception as exc:
            self.post(("reset", app_name))
            self.post_log(app_name, f"\n>>> ERROR starting {app_name}: {exc}\n")
            return

        app["proc"] = proc
        self.post(("reset", app_name))
        threading.Thread(
            target=self._wait_for_exit, args=(app_name, proc), daemon=True
        ).start()

    def _wait_for_exit(self, app_name, proc):
        code = proc.wait()
        # A stop we asked for detaches the proc first; only report surprises.
        if self.apps[app_name]["proc"] is proc:
            self.apps[app_name]["proc"] = None
            self.post_log(app_name, f"\n>>> {app_name} process ended (exit code {code}).\n")
        self.refresh_now()

    def _stop_apps_blocking(self, app_names, announce_idle=True):
        """Kill every process tree of the given apps, verify, retry. Returns how many were running."""
        snap = self._snapshot()
        targets = {}
        for name in app_names:
            app = self.apps[name]
            pids = set(self._detect(name, snap)["tree"])
            proc = app["proc"]
            if proc is not None and proc.poll() is None:
                pids.add(proc.pid)
            app["proc"] = None
            pids -= snap.protected
            if pids:
                targets[name] = pids
            elif announce_idle:
                self.post_log(name, f"\n>>> {name} is not running.\n")

        if not targets:
            return 0

        for name, pids in targets.items():
            self.post_log(name, f"\n>>> Stopping {name} (PID {_pid_list(pids)})...\n")

        pending = set().union(*targets.values())
        leftover = {}
        for _ in range(3):
            taskkill(pending)
            time.sleep(0.6)
            snap = self._snapshot()
            leftover = {}
            for name in targets:
                left = set(self._detect(name, snap)["tree"]) - snap.protected
                if left:
                    leftover[name] = left
            if not leftover:
                break
            pending = set().union(*leftover.values())

        for name in targets:
            if name in leftover:
                self.post_log(
                    name,
                    f">>> Could not stop PID {_pid_list(leftover[name])} — "
                    "try again, or end it in Task Manager.\n",
                )
            else:
                self.post_log(name, f">>> {name} stopped.\n")

        return len(targets)

    def hot_reload(self, app_name):
        app = self.apps[app_name]
        proc = app["proc"]

        try:
            mode = app["hot_reload"]

            if mode == "flutter":
                if proc is None or proc.poll() is not None or proc.stdin is None:
                    self.post_log(
                        app_name,
                        f"\n>>> Hot reload unavailable: {app_name} was not started from "
                        "this hub session.\n"
                        ">>> Restart it from here if you need the r / R keys.\n",
                    )
                    return
                # Flutter terminal commands:
                # r = hot reload
                # R = hot restart
                proc.stdin.write(b"r\n")
                proc.stdin.flush()
                self.post_log(app_name, ">>> Flutter hot reload sent (r).\n")

            elif mode == "dotnet":
                self.post_log(
                    app_name,
                    ">>> .NET watch is already monitoring files; hot reload is automatic.\n",
                )

            elif mode == "node":
                # npm run dev tools such as Vite/Next generally have HMR/Fast Refresh.
                self.post_log(
                    app_name,
                    ">>> Node dev server supports automatic file watching/HMR through its dev tool.\n",
                )

        except Exception as exc:
            self.post_log(app_name, f">>> Hot reload error: {exc}\n")

    def clear_current_log(self):
        self._clear_box(self.current_view)

    # =========================================================
    # SQL SERVICES
    # =========================================================
    def get_service_state(self, service_name):
        try:
            output = subprocess.check_output(
                f'sc query "{service_name}"',
                shell=True,
                text=True,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            return "RUNNING" if "RUNNING" in output else "STOPPED"
        except Exception:
            return "ERROR"

    def poll_service_status(self):
        if self._closing:
            return
        self._refresh_services()
        self.after(4000, self.poll_service_status)

    def _refresh_services(self):
        """One service-status pass. Safe to call from any thread."""
        if self._services_busy:
            return
        self._services_busy = True

        def worker():
            try:
                states = {svc: self.get_service_state(svc) for svc in self.sql_services}
                self.post(("services", states))
            finally:
                self._services_busy = False

        threading.Thread(target=worker, daemon=True).start()

    def apply_service_states(self, states):
        for svc, state in states.items():
            badge = self.service_badges[svc]
            if state == "RUNNING":
                badge.configure(
                    text="● RUNNING",
                    fg_color="#064E3B",
                    text_color="#34D399",
                )
            elif state == "STOPPED":
                badge.configure(
                    text="○ STOPPED",
                    fg_color="#451A03",
                    text_color="#F87171",
                )
            else:
                badge.configure(
                    text="⚠ ERROR",
                    fg_color="#7F1D1D",
                    text_color="#FCA5A5",
                )

    def toggle_service(self, service_name):
        self.service_btns[service_name].configure(state="disabled")

        def worker():
            try:
                state = self.get_service_state(service_name)
                cmd = (
                    f'net stop "{service_name}" /y'
                    if state == "RUNNING"
                    else f'net start "{service_name}"'
                )
                subprocess.run(
                    cmd,
                    shell=True,
                    capture_output=True,
                    creationflags=subprocess.CREATE_NO_WINDOW,
                )
            finally:
                self.post((
                    "call",
                    lambda: self.service_btns[service_name].configure(state="normal"),
                ))
                self._refresh_services()

        threading.Thread(target=worker, daemon=True).start()

    def on_close(self):
        running = [
            name for name, st in self.app_states.items()
            if st and st["status"] != "offline"
        ]
        if running:
            answer = messagebox.askyesnocancel(
                "Close Operations Hub",
                "Still running:\n  • " + "\n  • ".join(running) + "\n\n"
                "Yes — stop everything, then close\n"
                "No — leave them running in the background "
                "(the hub picks them up again next time)\n"
                "Cancel — keep the hub open",
                parent=self,
            )
            if answer is None:
                return
            if answer:
                self.configure(cursor="watch")
                self.update()
                if self._action_lock.acquire(timeout=15):
                    try:
                        self._stop_apps_blocking(list(self.apps), announce_idle=False)
                    finally:
                        self._action_lock.release()

        self._closing = True
        self.destroy()


if __name__ == "__main__":
    hide_console()

    if not is_admin():
        relaunch_as_admin()
        sys.exit()

    app = PosDashboard()
    app.mainloop()
