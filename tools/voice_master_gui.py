#!/usr/bin/env python3
"""Slider front-end for voice_master.py.  Run: python voice_master.py --gui"""

from __future__ import annotations

import json
import math
import os
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

import numpy as np

import voice_master as vm

try:
    import sounddevice as sd
except Exception:
    sd = None


def _play(x, fs):
    if sd is not None:
        sd.stop()
        sd.play(np.clip(x, -1, 1).astype(np.float32), fs)
        return
    import tempfile
    import winsound
    import soundfile as sf
    path = os.path.join(tempfile.gettempdir(), "voice_master_preview.wav")
    sf.write(path, np.clip(x, -1, 1).astype(np.float32), fs, subtype="PCM_16")
    winsound.PlaySound(path, winsound.SND_FILENAME | winsound.SND_ASYNC)


def _stop():
    if sd is not None:
        sd.stop()
    else:
        import winsound
        winsound.PlaySound(None, winsound.SND_PURGE)


class App:
    def __init__(self, root, cfg, args):
        self.root = root
        self.cfg = cfg
        self.ref = None
        self.files = []
        self.src = None
        self.out = None
        self.vars = {}
        self.busy = False
        root.title("voice_master - KCD2 voice line mastering")
        root.geometry("1280x860")

        top = ttk.Frame(root, padding=6)
        top.pack(fill="x")
        ttk.Button(top, text="Add files...", command=self.add_files).pack(side="left")
        ttk.Button(top, text="Add folder...", command=self.add_folder).pack(side="left", padx=4)
        ttk.Button(top, text="Reference...", command=self.pick_ref).pack(side="left", padx=(16, 4))
        ttk.Button(top, text="Reference folder...", command=self.pick_ref_dir).pack(side="left")
        ttk.Button(top, text="Clear reference", command=self.clear_ref).pack(side="left", padx=4)
        self.ref_lbl = ttk.Label(top, text="reference: none")
        self.ref_lbl.pack(side="left", padx=12)

        body = ttk.Panedwindow(root, orient="horizontal")
        body.pack(fill="both", expand=True)

        left = ttk.Frame(body)
        body.add(left, weight=1)
        self.listbox = tk.Listbox(left, exportselection=False)
        self.listbox.pack(fill="both", expand=True, padx=4, pady=4)
        self.listbox.bind("<<ListboxSelect>>", lambda e: self.load_selected())

        btns = ttk.Frame(left)
        btns.pack(fill="x", padx=4, pady=4)
        ttk.Button(btns, text="Process + preview", command=self.preview).pack(fill="x")
        ttk.Button(btns, text="Play original", command=self.play_src).pack(fill="x", pady=2)
        ttk.Button(btns, text="Play processed", command=self.play_out).pack(fill="x")
        ttk.Button(btns, text="Stop", command=_stop).pack(fill="x", pady=2)
        ttk.Separator(btns).pack(fill="x", pady=6)
        ttk.Button(btns, text="Render selected", command=lambda: self.render(False)).pack(fill="x")
        ttk.Button(btns, text="Render all", command=lambda: self.render(True)).pack(fill="x", pady=2)
        ttk.Separator(btns).pack(fill="x", pady=6)
        ttk.Button(btns, text="Load preset", command=self.load_preset).pack(fill="x")
        ttk.Button(btns, text="Save preset", command=self.save_preset).pack(fill="x", pady=2)
        ttk.Button(btns, text="Reset defaults", command=self.reset).pack(fill="x")

        self.outdir = tk.StringVar(value=args.out or "")
        od = ttk.Frame(left)
        od.pack(fill="x", padx=4, pady=4)
        ttk.Label(od, text="output folder").pack(anchor="w")
        ttk.Entry(od, textvariable=self.outdir).pack(fill="x")
        ttk.Button(od, text="Browse...", command=self.pick_out).pack(fill="x", pady=2)

        mid = ttk.Frame(body)
        body.add(mid, weight=2)
        self.params_holder = ttk.Frame(mid)
        self.params_holder.pack(fill="both", expand=True)
        self.build_params(self.params_holder)

        right = ttk.Frame(body)
        body.add(right, weight=2)
        self.build_plot(right)

        self.status = ttk.Label(root, text="ready", relief="sunken", anchor="w", padding=4)
        self.status.pack(fill="x")

        if args.inputs:
            self.add_paths(vm.expand_inputs(args.inputs))
        if args.ref:
            self.set_ref(args.ref)
        elif os.path.isfile(vm.DEFAULT_PROFILE):
            self.set_ref(vm.DEFAULT_PROFILE)

    # ------------------------------------------------------------ parameters

    def build_params(self, holder):
        for w in holder.winfo_children():
            w.destroy()
        nb = ttk.Notebook(holder)
        nb.pack(fill="both", expand=True)
        self.vars = {}
        for stage, block in vm.DEFAULTS.items():
            page = ttk.Frame(nb)
            nb.add(page, text=stage)
            canvas = tk.Canvas(page, highlightthickness=0)
            sb = ttk.Scrollbar(page, orient="vertical", command=canvas.yview)
            inner = ttk.Frame(canvas)
            inner.bind("<Configure>",
                       lambda e, c=canvas: c.configure(scrollregion=c.bbox("all")))
            canvas.create_window((0, 0), window=inner, anchor="nw")
            canvas.configure(yscrollcommand=sb.set)
            canvas.pack(side="left", fill="both", expand=True)
            sb.pack(side="right", fill="y")
            for row, key in enumerate(block):
                self.add_row(inner, row, stage, key)

    def add_row(self, parent, row, stage, key):
        dotted = f"{stage}.{key}"
        default = vm.DEFAULTS[stage][key]
        value = self.cfg[stage][key]
        lo, hi, doc = vm.PARAM_META.get(dotted, (0, 0, ""))
        ttk.Label(parent, text=key, width=22).grid(row=row, column=0, sticky="w", padx=4, pady=1)
        if isinstance(default, bool):
            var = tk.BooleanVar(value=bool(value))
            ttk.Checkbutton(parent, variable=var, command=self.touch).grid(
                row=row, column=1, sticky="w")
        elif isinstance(default, str):
            var = tk.StringVar(value=str(value))
            e = ttk.Entry(parent, textvariable=var, width=26)
            e.grid(row=row, column=1, sticky="w")
            e.bind("<FocusOut>", lambda ev: self.touch())
        else:
            var = tk.DoubleVar(value=float(value))
            frame = ttk.Frame(parent)
            frame.grid(row=row, column=1, sticky="w")
            scale = ttk.Scale(frame, from_=lo, to=hi, variable=var, length=190,
                              command=lambda v, d=dotted: self.on_slide(d))
            scale.pack(side="left")
            ent = ttk.Entry(frame, width=8)
            ent.pack(side="left", padx=4)
            ent.insert(0, self.fmt(default, value))
            ent.bind("<Return>", lambda ev, d=dotted: self.on_entry(d))
            self.vars[dotted + "#entry"] = ent
        self.vars[dotted] = var
        ttk.Label(parent, text=doc, foreground="#666").grid(row=row, column=2, sticky="w", padx=8)

    @staticmethod
    def fmt(default, value):
        return str(int(round(float(value)))) if isinstance(default, int) else f"{float(value):.3g}"

    def on_slide(self, dotted):
        stage, _, key = dotted.partition(".")
        default = vm.DEFAULTS[stage][key]
        v = self.vars[dotted].get()
        if isinstance(default, int):
            v = int(round(v))
        ent = self.vars.get(dotted + "#entry")
        if ent is not None:
            ent.delete(0, "end")
            ent.insert(0, self.fmt(default, v))
        self.cfg[stage][key] = vm.coerce_like(default, v)

    def on_entry(self, dotted):
        ent = self.vars[dotted + "#entry"]
        try:
            v = float(ent.get())
        except ValueError:
            return
        self.vars[dotted].set(v)
        self.on_slide(dotted)

    def touch(self):
        for dotted, var in self.vars.items():
            if dotted.endswith("#entry"):
                continue
            stage, _, key = dotted.partition(".")
            self.cfg[stage][key] = vm.coerce_like(vm.DEFAULTS[stage][key], var.get())

    def reset(self):
        self.cfg = vm.new_config()
        self.build_params(self.params_holder)
        self.say("defaults restored")

    def load_preset(self):
        p = filedialog.askopenfilename(filetypes=[("JSON", "*.json")])
        if not p:
            return
        with open(p, "r", encoding="utf-8") as fh:
            vm.deep_merge(self.cfg, json.load(fh))
        self.build_params(self.params_holder)
        self.say(f"loaded {os.path.basename(p)}")

    def save_preset(self):
        self.touch()
        p = filedialog.asksaveasfilename(defaultextension=".json", filetypes=[("JSON", "*.json")])
        if not p:
            return
        with open(p, "w", encoding="utf-8") as fh:
            json.dump(self.cfg, fh, indent=2)
        self.say(f"saved {os.path.basename(p)}")

    # ----------------------------------------------------------------- files

    def add_paths(self, paths):
        for p in paths:
            if p not in self.files:
                self.files.append(p)
        self.files.sort(key=vm.natural_key)
        self.listbox.delete(0, "end")
        for p in self.files:
            self.listbox.insert("end", os.path.basename(p))
        if self.files and not self.listbox.curselection():
            self.listbox.selection_set(0)
            self.load_selected()

    def add_files(self):
        ps = filedialog.askopenfilenames(
            filetypes=[("Audio", "*.wav *.mp3 *.ogg *.flac *.m4a"), ("All", "*.*")])
        if ps:
            self.add_paths(list(ps))

    def add_folder(self):
        d = filedialog.askdirectory()
        if d:
            self.add_paths(vm.expand_inputs([d]))
            if not self.outdir.get():
                self.outdir.set(os.path.join(d, "mastered"))

    def pick_out(self):
        d = filedialog.askdirectory()
        if d:
            self.outdir.set(d)

    def current(self):
        sel = self.listbox.curselection()
        return self.files[sel[0]] if sel else None

    def load_selected(self):
        p = self.current()
        if not p:
            return
        self.src = vm.load_audio(p, int(self.cfg["io"]["sample_rate"]), self.cfg["io"]["decoder"])
        self.out = None
        a = vm.analyse(self.src)
        self.say(f"{os.path.basename(p)}   {a['duration']:.2f}s   LUFS {a['lufs']:.1f}   "
                 f"peak {a['true_peak_db']:.1f}   floor {a['noise_rms_db']:.1f}")
        self.draw()

    # ------------------------------------------------------------- reference

    def set_ref(self, spec):
        try:
            self.ref = vm.load_reference(spec, self.cfg, 400)
        except Exception as exc:
            messagebox.showerror("reference", str(exc))
            return
        self.ref_lbl.config(
            text=f"reference: {self.ref['name']}  LUFS {self.ref['lufs']:.1f}  "
                 f"peak {self.ref['peak_db']:.1f}")
        self.draw()

    def pick_ref(self):
        p = filedialog.askopenfilename(
            filetypes=[("Audio or profile", "*.ogg *.wav *.mp3 *.flac *.json"), ("All", "*.*")])
        if p:
            self.set_ref(p)

    def pick_ref_dir(self):
        d = filedialog.askdirectory()
        if d:
            self.set_ref(d)

    def clear_ref(self):
        self.ref = None
        self.ref_lbl.config(text="reference: none")
        self.draw()

    # ----------------------------------------------------------------- render

    def run_bg(self, fn):
        if self.busy:
            return
        self.busy = True

        def wrap():
            try:
                fn()
            except Exception as exc:
                self.root.after(0, lambda: messagebox.showerror("error", repr(exc)))
            finally:
                self.busy = False
        threading.Thread(target=wrap, daemon=True).start()

    def preview(self):
        if self.src is None:
            return
        self.touch()
        self.say("processing...")

        def job():
            y, info = vm.process(self.src.copy(), self.cfg, self.ref)
            self.out = y
            self.root.after(0, lambda: self.after_preview(info))
        self.run_bg(job)

    def after_preview(self, info):
        self.say(f"LUFS {info['in_lufs']:.1f} -> {info['out_lufs']:.1f} "
                 f"(target {info['target_lufs']:.1f})   "
                 f"peak {info['in_peak_db']:.1f} -> {info['out_peak_db']:.1f}   "
                 f"floor {info['in_noise_db']:.1f} -> {info['out_noise_db']:.1f}   "
                 f"length {info['in_duration']:.2f}s -> {info['out_duration']:.2f}s   "
                 f"ReferenceLength {math.ceil(info['out_duration'])}")
        self.draw()
        self.play_out()

    def play_src(self):
        if self.src is not None:
            _play(self.src, int(self.cfg["io"]["sample_rate"]))

    def play_out(self):
        if self.out is not None:
            _play(self.out, int(self.cfg["io"]["sample_rate"]))
        else:
            self.preview()

    def render(self, everything):
        self.touch()
        files = self.files if everything else [self.current()]
        files = [f for f in files if f]
        if not files:
            return
        outdir = self.outdir.get() or os.path.join(
            os.path.dirname(os.path.abspath(files[0])), "mastered")
        os.makedirs(outdir, exist_ok=True)

        def job():
            for i, p in enumerate(files, 1):
                self.root.after(0, lambda i=i, p=p: self.say(
                    f"rendering {i}/{len(files)}  {os.path.basename(p)}"))
                vm.run_batch([p], self.cfg, self.ref, outdir, quiet=True)
            self.root.after(0, lambda: self.say(f"wrote {len(files)} file(s) to {outdir}"))
        self.run_bg(job)

    # ------------------------------------------------------------------ plot

    def build_plot(self, parent):
        from matplotlib.figure import Figure
        from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
        self.fig = Figure(figsize=(5, 7), dpi=96)
        self.ax_w = self.fig.add_subplot(211)
        self.ax_s = self.fig.add_subplot(212)
        self.canvas = FigureCanvasTkAgg(self.fig, master=parent)
        self.canvas.get_tk_widget().pack(fill="both", expand=True)

    def draw(self):
        fs = int(self.cfg["io"]["sample_rate"])
        self.ax_w.clear()
        self.ax_s.clear()
        if self.src is not None:
            t = np.arange(len(self.src)) / fs
            self.ax_w.plot(t, self.src, lw=0.4, color="#999", label="original")
        if self.out is not None:
            t = np.arange(len(self.out)) / fs
            self.ax_w.plot(t, self.out, lw=0.4, color="#c33", label="processed")
        self.ax_w.set_ylim(-1.05, 1.05)
        self.ax_w.set_xlabel("s")
        self.ax_w.legend(loc="upper right", fontsize=7)
        self.ax_w.set_title("waveform", fontsize=9)

        nfft = int(self.ref["nfft"]) if self.ref else 2048
        freqs = np.fft.rfftfreq(nfft, 1 / fs)
        def norm(c):
            c = np.asarray(c, dtype=float)
            b = (freqs >= 250) & (freqs <= 6000)
            return c - c[b].mean()
        if self.src is not None:
            self.ax_s.semilogx(freqs[1:], norm(vm.analyse(self.src, fs, nfft)["ltas_db"])[1:],
                               color="#999", lw=1, label="original")
        if self.out is not None:
            self.ax_s.semilogx(freqs[1:], norm(vm.analyse(self.out, fs, nfft)["ltas_db"])[1:],
                               color="#c33", lw=1, label="processed")
        if self.ref is not None:
            self.ax_s.semilogx(freqs[1:], norm(self.ref["ltas_db"])[1:],
                               color="#36c", lw=1.4, label="reference")
        self.ax_s.set_xlim(40, fs / 2)
        self.ax_s.set_ylim(-60, 30)
        self.ax_s.grid(True, which="both", alpha=0.25)
        self.ax_s.set_xlabel("Hz")
        self.ax_s.set_ylabel("dB re 250-6k")
        self.ax_s.legend(loc="lower left", fontsize=7)
        self.ax_s.set_title("speech spectrum", fontsize=9)
        self.fig.tight_layout()
        self.canvas.draw_idle()

    def say(self, text):
        self.status.config(text=text)


def launch(cfg, args):
    root = tk.Tk()
    App(root, cfg, args)
    root.mainloop()
    return 0


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", nargs="*")
    ap.add_argument("-o", "--out", default=None)
    ap.add_argument("--ref", default=None)
    launch(vm.new_config(), ap.parse_args())
