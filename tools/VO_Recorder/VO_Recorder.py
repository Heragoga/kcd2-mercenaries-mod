import tkinter as tk
from tkinter import messagebox
import sounddevice as sd
import soundfile as sf
import numpy as np
import os
import re
import threading
import queue

try:
    import noisereduce as nr
    HAS_NR = True
except ImportError:
    HAS_NR = False

try:
    from pedalboard import Pedalboard, NoiseGate, Compressor, HighpassFilter, LowpassFilter, Gain
    HAS_PB = True
except ImportError:
    HAS_PB = False

# --- SETTINGS ---
INPUT_FILE = "lines.txt"
OUTPUT_DIR = "output_audio"
PREFERRED_SAMPLE_RATE = 40000
CHANNELS = 1
SILENCE_THRESHOLD = 0.002
CLICK_TRIM_SECONDS = 0.15

DEVICE_BLOCKLIST = [
    "microsoft sound mapper", "primary sound capture", "steam streaming",
    "audiorelay", "virtual mic", " wave", "mapper",
]

def is_blocked(name):
    return any(bad in name.lower() for bad in DEVICE_BLOCKLIST)

class VORecorderApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Mass VO Recorder")
        self.root.geometry("650x640")

        self.lines = []
        self.current_index = 0
        self.audio_data = None
        self.is_recording = False
        self.audio_queue = queue.Queue()
        self.active_sample_rate = PREFERRED_SAMPLE_RATE
        self.stream = None
        self.monitor_stream = None
        self.live_rms = tk.DoubleVar(value=0.0)

        # Processing toggles
        self.opt_denoise     = tk.BooleanVar(value=HAS_NR)
        self.opt_noisegate   = tk.BooleanVar(value=HAS_PB)
        self.opt_highpass    = tk.BooleanVar(value=HAS_PB)
        self.opt_lowpass     = tk.BooleanVar(value=HAS_PB)
        self.opt_compress    = tk.BooleanVar(value=HAS_PB)
        self.opt_normalize   = tk.BooleanVar(value=True)

        all_devices = sd.query_devices()
        self.input_devices = []
        seen_names = set()
        for i, d in enumerate(all_devices):
            if d['max_input_channels'] > 0 and not is_blocked(d['name']):
                if d['name'] not in seen_names:
                    self.input_devices.append((i, d['name'], int(d['default_samplerate'])))
                    seen_names.add(d['name'])

        if not self.input_devices:
            self.input_devices = [
                (i, d['name'], int(d['default_samplerate']))
                for i, d in enumerate(all_devices)
                if d['max_input_channels'] > 0
            ]

        if not self.input_devices:
            messagebox.showerror("Error", "No input devices found.")
            root.destroy()
            return

        self.selected_idx = self.input_devices[0][0]
        self.selected_mic_name = tk.StringVar(value=self.input_devices[0][1])

        if not os.path.exists(OUTPUT_DIR):
            os.makedirs(OUTPUT_DIR)

        self.load_data()
        self.setup_ui()
        self.load_line()
        threading.Thread(target=self._bg_resolve_sr, daemon=True).start()
        self.root.after(200, self.start_monitor)
        self.root.after(50, self.update_meter)
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

    def load_data(self):
        try:
            with open(INPUT_FILE, "r", encoding="utf-8") as f:
                content = f.read()
            pattern = re.compile(
                r"<Row>\s*<Cell>(.*?)</Cell>\s*<Cell>(.*?)</Cell>.*?</Row>",
                re.IGNORECASE | re.DOTALL
            )
            for match in pattern.findall(content):
                self.lines.append({"Filename": match[0].strip(), "Text": match[1].strip()})
            if not self.lines:
                messagebox.showwarning("Warning", f"No rows found in {INPUT_FILE}.")
        except Exception as e:
            messagebox.showerror("Error", f"Could not load {INPUT_FILE}\n{e}")
            self.root.destroy()

    def setup_ui(self):
        # Mic selector
        mic_frame = tk.Frame(self.root)
        mic_frame.pack(pady=4)
        tk.Label(mic_frame, text="Microphone: ", font=("Arial", 9, "bold")).pack(side=tk.LEFT)
        device_names = [name for (_, name, _) in self.input_devices]
        self.mic_dropdown = tk.OptionMenu(
            mic_frame, self.selected_mic_name, *device_names,
            command=self.on_mic_changed
        )
        self.mic_dropdown.pack(side=tk.LEFT)

        self.samplerate_lbl = tk.Label(self.root, text="Checking sample rate...", font=("Arial", 8), fg="gray")
        self.samplerate_lbl.pack()

        # Level meter
        meter_frame = tk.Frame(self.root, pady=2)
        meter_frame.pack(fill='x', padx=20)
        tk.Label(meter_frame, text="Live Input Level:", font=("Arial", 8, "bold")).pack(anchor='w')
        self.meter_canvas = tk.Canvas(meter_frame, height=18, bg="#222", highlightthickness=1, highlightbackground="#555")
        self.meter_canvas.pack(fill='x')
        self.meter_bar = self.meter_canvas.create_rectangle(0, 0, 0, 18, fill="#00cc44", outline="")
        self.rms_label = tk.Label(meter_frame, text="RMS: 0.00000", font=("Arial", 7), fg="gray")
        self.rms_label.pack(anchor='e')

        # Processing panel
        proc_outer = tk.LabelFrame(self.root, text="Audio Processing (applied on Approve)", font=("Arial", 9, "bold"), padx=6, pady=4)
        proc_outer.pack(fill='x', padx=16, pady=4)

        row1 = tk.Frame(proc_outer)
        row1.pack(fill='x')
        row2 = tk.Frame(proc_outer)
        row2.pack(fill='x')

        def make_cb(parent, text, var, available):
            state = tk.NORMAL if available else tk.DISABLED
            label = text if available else f"{text} (not installed)"
            tk.Checkbutton(parent, text=label, variable=var, state=state,
                           font=("Arial", 9)).pack(side=tk.LEFT, padx=6)

        make_cb(row1, "Noise Reduction",   self.opt_denoise,   HAS_NR)
        make_cb(row1, "Noise Gate",        self.opt_noisegate, HAS_PB)
        make_cb(row1, "Compress/Even Out", self.opt_compress,  HAS_PB)
        make_cb(row2, "Highpass (80Hz)",   self.opt_highpass,  HAS_PB)
        make_cb(row2, "Lowpass (12kHz)",   self.opt_lowpass,   HAS_PB)
        make_cb(row2, "Normalize",         self.opt_normalize, True)

        if not HAS_NR or not HAS_PB:
            missing = []
            if not HAS_NR: missing.append("noisereduce")
            if not HAS_PB: missing.append("pedalboard")
            tk.Label(proc_outer,
                     text=f"Run: pip install {' '.join(missing)}",
                     font=("Arial", 8), fg="red").pack(anchor='w')

        # Line display
        self.progress_lbl = tk.Label(self.root, text="", font=("Arial", 10))
        self.progress_lbl.pack(pady=3)

        self.filename_lbl = tk.Label(self.root, text="", font=("Arial", 10, "bold"), fg="blue")
        self.filename_lbl.pack(pady=1)

        self.text_lbl = tk.Label(
            self.root, text="", font=("Arial", 14),
            wraplength=550, justify="center"
        )
        self.text_lbl.pack(expand=True, fill='both', pady=6)

        # Buttons
        btn_frame = tk.Frame(self.root)
        btn_frame.pack(pady=12)

        self.btn_rec = tk.Button(
            btn_frame, text="🔴 START RECORDING", bg="lightcoral",
            font=("Arial", 12, "bold"), command=self.toggle_record
        )
        self.btn_rec.grid(row=0, column=0, padx=10)

        self.btn_play = tk.Button(
            btn_frame, text="▶ PLAY", font=("Arial", 12),
            state=tk.DISABLED, command=self.play_audio
        )
        self.btn_play.grid(row=0, column=1, padx=10)

        self.btn_next = tk.Button(
            btn_frame, text="✔ APPROVE & NEXT", bg="lightgreen",
            font=("Arial", 12, "bold"), state=tk.DISABLED, command=self.approve_next
        )
        self.btn_next.grid(row=0, column=2, padx=10)

    def on_mic_changed(self, selected_name):
        for (idx, name, _) in self.input_devices:
            if name == selected_name:
                self.selected_idx = idx
                break
        self.samplerate_lbl.config(text="Checking sample rate...", fg="gray")
        self.stop_monitor()
        threading.Thread(target=self._bg_resolve_sr, daemon=True).start()
        self.root.after(400, self.start_monitor)

    def _bg_resolve_sr(self):
        sr = self._resolve_sample_rate()
        self.active_sample_rate = sr
        self.root.after(0, lambda s=sr: self._update_sr_label(s))

    def _resolve_sample_rate(self):
        for rate in [PREFERRED_SAMPLE_RATE, 48000, 44100]:
            try:
                sd.check_input_settings(device=self.selected_idx, samplerate=rate, channels=CHANNELS)
                return rate
            except Exception:
                continue
        return int(sd.query_devices(self.selected_idx)['default_samplerate'])

    def _update_sr_label(self, sr):
        if sr == PREFERRED_SAMPLE_RATE:
            self.samplerate_lbl.config(text=f"Sample rate: {sr} Hz (preferred)", fg="green")
        else:
            self.samplerate_lbl.config(text=f"Sample rate: {sr} Hz (device native)", fg="orange")

    def _monitor_callback(self, indata, frames, time_info, status):
        self.live_rms.set(float(np.sqrt(np.mean(indata ** 2))))

    def start_monitor(self):
        self.stop_monitor()
        try:
            self.monitor_stream = sd.InputStream(
                samplerate=self.active_sample_rate, channels=CHANNELS,
                dtype='float32', device=self.selected_idx,
                callback=self._monitor_callback
            )
            self.monitor_stream.start()
        except Exception:
            pass

    def stop_monitor(self):
        if self.monitor_stream:
            try:
                self.monitor_stream.stop()
                self.monitor_stream.close()
            except Exception:
                pass
            self.monitor_stream = None

    def update_meter(self):
        rms = self.live_rms.get()
        width = self.meter_canvas.winfo_width()
        fill_ratio = min(rms / 0.3, 1.0)
        fill_px = int(width * fill_ratio)
        color = "#00cc44" if rms > SILENCE_THRESHOLD else "#cc4400"
        self.meter_canvas.itemconfig(self.meter_bar, fill=color)
        self.meter_canvas.coords(self.meter_bar, 0, 0, fill_px, 18)
        self.rms_label.config(
            text=f"RMS: {rms:.7f}  {'✔ signal detected' if rms > SILENCE_THRESHOLD else '✘ no signal'}"
        )
        self.root.after(50, self.update_meter)

    def load_line(self):
        if self.current_index < len(self.lines):
            row = self.lines[self.current_index]
            self.progress_lbl.config(text=f"Line {self.current_index + 1} of {len(self.lines)}")
            self.filename_lbl.config(text=f"File: {row['Filename']}.wav")
            self.text_lbl.config(text=row['Text'])
            self.audio_data = None
            self.btn_play.config(state=tk.DISABLED)
            self.btn_next.config(state=tk.DISABLED)
        else:
            self.text_lbl.config(text="ALL LINES COMPLETED!")
            self.filename_lbl.config(text="")
            self.btn_rec.config(state=tk.DISABLED)
            self.mic_dropdown.config(state=tk.DISABLED)

    def _audio_callback(self, indata, frames, time_info, status):
        self.audio_queue.put(indata.copy())
        self.live_rms.set(float(np.sqrt(np.mean(indata ** 2))))

    def toggle_record(self):
        if not self.is_recording:
            self.stop_monitor()
            self.is_recording = True
            self.audio_data = None
            self.audio_queue = queue.Queue()

            self.btn_rec.config(text="⏹ STOP RECORDING", bg="yellow")
            self.btn_play.config(state=tk.DISABLED)
            self.btn_next.config(state=tk.DISABLED)
            self.mic_dropdown.config(state=tk.DISABLED)

            try:
                self.stream = sd.InputStream(
                    samplerate=self.active_sample_rate, channels=CHANNELS,
                    dtype='float32', device=self.selected_idx,
                    callback=self._audio_callback
                )
                self.stream.start()
            except Exception as e:
                self.is_recording = False
                self.btn_rec.config(text="🔴 START RECORDING", bg="lightcoral")
                self.mic_dropdown.config(state=tk.NORMAL)
                self.start_monitor()
                messagebox.showerror("Microphone Error", str(e))
        else:
            self.is_recording = False
            if self.stream:
                self.stream.stop()
                self.stream.close()
                self.stream = None
            self._on_record_done()
            self.start_monitor()

    def _on_record_done(self):
        self.btn_rec.config(text="🔴 RE-RECORD", bg="lightcoral")
        self.mic_dropdown.config(state=tk.NORMAL)

        chunks = []
        while not self.audio_queue.empty():
            chunks.append(self.audio_queue.get())

        if not chunks:
            messagebox.showwarning("Empty", "No audio was captured.")
            return

        audio_np = np.concatenate(chunks, axis=0).flatten()
        rms = float(np.sqrt(np.mean(audio_np ** 2)))

        if rms < SILENCE_THRESHOLD:
            messagebox.showwarning("No Signal", f"RMS: {rms:.7f} — microphone returned silence.")
            return

        # Trim silence end
        non_silent = np.where(np.abs(audio_np) > SILENCE_THRESHOLD)[0]
        if len(non_silent) > 0:
            audio_np = audio_np[:non_silent[-1] + 1]

        # Trim click
        click_samples = int(self.active_sample_rate * CLICK_TRIM_SECONDS)
        if len(audio_np) > click_samples:
            audio_np = audio_np[:-click_samples]

        self.audio_data = audio_np
        self.btn_play.config(state=tk.NORMAL)
        self.btn_next.config(state=tk.NORMAL)

    def process_audio(self, audio):
        sr = self.active_sample_rate

        # Spectral noise reduction — samples first 0.5s as noise profile
        if self.opt_denoise.get() and HAS_NR:
            noise_sample_len = min(int(sr * 0.5), len(audio))
            noise_clip = audio[:noise_sample_len]
            audio = nr.reduce_noise(y=audio, sr=sr, y_noise=noise_clip, prop_decrease=0.8)

        # Pedalboard chain
        if HAS_PB:
            board = []
            if self.opt_highpass.get():
                board.append(HighpassFilter(cutoff_frequency_hz=80))
            if self.opt_lowpass.get():
                board.append(LowpassFilter(cutoff_frequency_hz=12000))
            if self.opt_noisegate.get():
                board.append(NoiseGate(threshold_db=-40, attack_ms=2, release_ms=100))
            if self.opt_compress.get():
                board.append(Compressor(threshold_db=-20, ratio=3, attack_ms=5, release_ms=100))
            if board:
                pb = Pedalboard(board)
                audio = pb(audio, sr)

        # Normalize to -1dB peak
        if self.opt_normalize.get():
            peak = np.max(np.abs(audio))
            if peak > 0:
                audio = audio * (0.891 / peak)

        return audio

    def play_audio(self):
        if self.audio_data is not None:
            sd.play(self.audio_data, self.active_sample_rate)

    def approve_next(self):
        if self.audio_data is None:
            return

        self.btn_next.config(state=tk.DISABLED, text="Processing...")
        self.root.update()

        processed = self.process_audio(self.audio_data.copy())

        filename = self.lines[self.current_index]['Filename']
        filepath = os.path.join(OUTPUT_DIR, f"{filename}.wav")
        sf.write(filepath, processed, self.active_sample_rate)

        self.btn_next.config(text="✔ APPROVE & NEXT")
        self.current_index += 1
        self.load_line()

    def on_close(self):
        self.is_recording = False
        self.stop_monitor()
        if self.stream:
            try:
                self.stream.stop()
                self.stream.close()
            except Exception:
                pass
        self.root.destroy()

if __name__ == "__main__":
    root = tk.Tk()
    app = VORecorderApp(root)
    root.mainloop()