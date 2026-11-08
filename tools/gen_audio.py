#!/usr/bin/env python3
"""Bruitages et musiques du jeu, synthétisés (style 8-bit, en attendant de vrais sons).

Tout est calculé ici, sans échantillon extérieur : pas de licence à gérer, et on peut
retoucher un son en changeant quelques chiffres. Même graine, mêmes fichiers.

- assets/audio/sfx/<nom>.wav   : bruitages courts (22 050 Hz, mono, 16 bits)
- assets/audio/sfx/<nom>.ogg   : boucles d'ambiance (pluie, roulement du train)
- assets/audio/music/<nom>.ogg : musiques de fond en boucle (Vorbis, via ffmpeg)

Usage : python3 tools/gen_audio.py            (tout)
        python3 tools/gen_audio.py sfx        (bruitages seulement)
        python3 tools/gen_audio.py music      (musiques seulement)
"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy.signal import lfilter

ROOT = Path(__file__).resolve().parent.parent
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
MUSIC_DIR = ROOT / "assets" / "audio" / "music"
RATE = 22050


# --- Briques de synthèse -------------------------------------------------------------

def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def osc(kind: str, freq, seconds: float, duty: float = 0.5) -> np.ndarray:
    n = int(seconds * RATE)
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, dtype=float)[:n]
    ph = 2 * np.pi * np.cumsum(f) / RATE
    cyc = (ph / (2 * np.pi)) % 1.0
    if kind == "square":
        return np.where(cyc < duty, 1.0, -1.0) - (2 * duty - 1)  # sans composante continue
    if kind == "triangle":
        return 4 * np.abs(cyc - 0.5) - 1
    if kind == "saw":
        return 2 * cyc - 1
    return np.sin(ph)


def noise(seconds: float, rng: np.random.Generator) -> np.ndarray:
    return rng.uniform(-1, 1, int(seconds * RATE))


def env(n: int, attack: float = 0.005, decay: float = 0.1, sustain: float = 0.0, release: float = 0.05) -> np.ndarray:
    """Enveloppe ADSR (secondes) sur n échantillons ; sustain = niveau entre decay et release."""
    a, d, r = int(attack * RATE), int(decay * RATE), int(release * RATE)
    s_len = max(n - a - d - r, 0)
    curve = np.concatenate([
        np.linspace(0, 1, max(a, 1)),
        np.linspace(1, sustain, max(d, 1)),
        np.full(s_len, sustain),
        np.linspace(sustain, 0, max(r, 1)),
    ])
    if curve.size < n:
        curve = np.pad(curve, (0, n - curve.size))
    return curve[:n]


def exp_decay(n: int, seconds: float) -> np.ndarray:
    return np.exp(-np.arange(n) / (seconds * RATE))


def lowpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    """Filtre passe-bas d'ordre 1 (assez pour adoucir un bruit)."""
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    return lfilter([alpha], [1, alpha - 1], signal)


def highpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    return signal - lowpass(signal, cutoff)


def slide(f0: float, f1: float, seconds: float, curve: float = 1.0) -> np.ndarray:
    x = np.linspace(0, 1, int(seconds * RATE)) ** curve
    return f0 + (f1 - f0) * x


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(p.size for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: p.size] += p
    return out


def seq(*parts, gap: float = 0.0) -> np.ndarray:
    pieces = []
    for p in parts:
        pieces.append(p)
        if gap > 0:
            pieces.append(np.zeros(int(gap * RATE)))
    return np.concatenate(pieces)


def at(signal: np.ndarray, offset: float, total: float) -> np.ndarray:
    out = np.zeros(int(total * RATE))
    start = int(offset * RATE)
    end = min(start + signal.size, out.size)
    out[start:end] += signal[: end - start]
    return out


def normalize(signal: np.ndarray, peak: float = 0.85, rms: float = 0.0) -> np.ndarray:
    """Ramène le crête à `peak` ; avec `rms`, ne dépasse pas non plus ce volume moyen
    (un carré plein sonne bien plus fort qu'un bruit filtré de même crête)."""
    m = np.max(np.abs(signal))
    if m == 0:
        return signal
    gain = peak / m
    if rms > 0:
        gain = min(gain, rms / np.sqrt(np.mean(signal ** 2)))
    return signal * gain


def note_hz(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def write_wav(path: Path, signal: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(signal, -1, 1) * 32000).astype("<i2")
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def write_ogg(path: Path, signal: np.ndarray, quality: int = 3) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        write_wav(wav, signal)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(wav), "-fflags", "+bitexact", "-flags:a", "+bitexact",
                        "-c:a", "libvorbis", "-q:a", str(quality),
                        "-metadata", "comment=Runaway Train (synthé maison)", str(path)], check=True)


# --- Bruitages -----------------------------------------------------------------------

def sfx_all(rng: np.random.Generator) -> dict:
    s = {}
    # Interface
    n = int(0.05 * RATE)
    s["ui_click"] = osc("square", 1320, 0.05, 0.25) * env(n, 0.001, 0.045) * 0.5
    s["ui_open"] = seq(osc("square", 660, 0.05, 0.25) * env(n, 0.001, 0.045), osc("square", 990, 0.07, 0.25) * env(int(0.07 * RATE), 0.001, 0.065)) * 0.45
    s["ui_close"] = seq(osc("square", 990, 0.05, 0.25) * env(n, 0.001, 0.045), osc("square", 660, 0.07, 0.25) * env(int(0.07 * RATE), 0.001, 0.065)) * 0.45
    s["ui_error"] = osc("square", 140, 0.18, 0.5) * env(int(0.18 * RATE), 0.002, 0.05, 0.6, 0.06) * 0.5
    # Combat
    w = noise(0.16, rng)
    s["swing"] = highpass(lowpass(w, 3500), 600) * env(w.size, 0.02, 0.13) * 0.9
    k = int(0.14 * RATE)
    s["hit"] = mix(osc("sine", slide(220, 60, 0.14), 0.14) * exp_decay(k, 0.05), lowpass(noise(0.14, rng), 2500) * exp_decay(k, 0.03) * 0.8)
    h = int(0.3 * RATE)
    s["hurt"] = mix(osc("square", slide(520, 180, 0.3), 0.3, 0.5) * env(h, 0.003, 0.28) * 0.6, noise(0.3, rng) * exp_decay(h, 0.05) * 0.3)
    d = int(0.45 * RATE)
    s["enemy_die"] = mix(osc("saw", slide(300, 50, 0.45, 0.6), 0.45) * env(d, 0.005, 0.44) * 0.5, lowpass(noise(0.45, rng), 1800) * exp_decay(d, 0.12) * 0.5)
    g = int(0.16 * RATE)
    s["shot"] = mix(noise(0.16, rng) * exp_decay(g, 0.03), osc("sine", slide(180, 40, 0.16), 0.16) * exp_decay(g, 0.05) * 0.8)
    gr = t_axis(0.7)
    growl_f = 70 + 12 * np.sin(2 * np.pi * 7 * gr) + rng.uniform(-4, 4, gr.size)
    s["growl"] = (osc("saw", growl_f, 0.7) * 0.5 + lowpass(noise(0.7, rng), 600) * 0.6) * env(gr.size, 0.08, 0.2, 0.7, 0.3)
    s["freed"] = osc("square", slide(300, 900, 0.18), 0.18, 0.25) * env(int(0.18 * RATE), 0.002, 0.17) * 0.5
    # Récolte, sac
    s["pickup"] = seq(osc("square", 988, 0.06, 0.25) * env(int(0.06 * RATE), 0.001, 0.055),
                      osc("square", 1319, 0.1, 0.25) * env(int(0.1 * RATE), 0.001, 0.095)) * 0.45
    s["drop"] = mix(osc("sine", slide(160, 70, 0.15), 0.15) * exp_decay(int(0.15 * RATE), 0.05), lowpass(noise(0.15, rng), 900) * exp_decay(int(0.15 * RATE), 0.04) * 0.5)
    s["plan_found"] = np.concatenate([osc("triangle", note_hz(m), 0.08) * env(int(0.08 * RATE), 0.002, 0.075, 0.0) for m in (72, 76, 79, 84)] +
                                     [osc("triangle", note_hz(88), 0.3) * env(int(0.3 * RATE), 0.002, 0.29)]) * 0.6
    # Train
    wt = t_axis(1.3)
    breath = lowpass(noise(1.3, rng), 4000) * 0.25
    whistle = osc("sine", 620 + 6 * np.sin(2 * np.pi * 5 * wt), 1.3) + osc("sine", 745 + 6 * np.sin(2 * np.pi * 5 * wt), 1.3) * 0.8 + osc("sine", 930, 1.3) * 0.3
    s["whistle"] = (whistle * 0.35 + breath) * env(wt.size, 0.08, 0.1, 0.9, 0.35)
    chug_total = 2.2
    chugs = np.zeros(int(chug_total * RATE))
    beat, time_ = 0.42, 0.0
    while time_ < chug_total - 0.2:
        burst = lowpass(noise(0.18, rng), 1200) * exp_decay(int(0.18 * RATE), 0.05)
        chugs += at(burst, time_, chug_total)
        time_ += beat
        beat = max(beat * 0.86, 0.16)
    s["train_depart"] = chugs * 0.9
    # Freinage : sifflement de vapeur et crissement des roues.
    bt = t_axis(1.4)
    squeal = osc("sine", 2300 + 40 * np.sin(2 * np.pi * 9 * bt) - 300 * bt / 1.4, 1.4) * 0.25 * env(bt.size, 0.15, 0.3, 0.7, 0.5)
    steam = highpass(noise(1.4, rng), 2000) * env(bt.size, 0.02, 0.6, 0.3, 0.6) * 0.5
    s["brake"] = mix(squeal, steam)
    s["door"] = mix(osc("square", 110, 0.12, 0.5) * exp_decay(int(0.12 * RATE), 0.03) * 0.4, lowpass(noise(0.12, rng), 1500) * exp_decay(int(0.12 * RATE), 0.025))
    tk = int(0.1 * RATE)
    s["train_hit"] = mix(osc("square", 330, 0.35, 0.5) * exp_decay(int(0.35 * RATE), 0.1) * 0.4, osc("square", 467, 0.35, 0.5) * exp_decay(int(0.35 * RATE), 0.08) * 0.3,
                         noise(0.1, rng) * exp_decay(tk, 0.02) * 0.6)
    # Événements
    roar_t = t_axis(1.6)
    roar_f = 55 + 20 * np.sin(2 * np.pi * 3 * roar_t)
    roar = osc("saw", roar_f, 1.6) * 0.4 + osc("saw", roar_f * 1.5 + 3, 1.6) * 0.25 + lowpass(noise(1.6, rng), 800) * 0.7
    drums = np.zeros(roar.size)
    for beat_time in (0.0, 0.4, 0.8, 1.1):
        drums += at(osc("sine", slide(120, 40, 0.25), 0.25) * exp_decay(int(0.25 * RATE), 0.08), beat_time, 1.6)
    s["horde"] = (roar * env(roar.size, 0.2, 0.3, 0.8, 0.6) + drums * 0.9)
    s["alarm"] = np.concatenate([osc("square", f, 0.22, 0.5) * env(int(0.22 * RATE), 0.005, 0.02, 0.9, 0.02) for f in (780, 590, 780, 590)]) * 0.35
    s["encounter"] = seq(osc("triangle", note_hz(76), 0.12) * env(int(0.12 * RATE), 0.003, 0.11), osc("triangle", note_hz(83), 0.25) * env(int(0.25 * RATE), 0.003, 0.24)) * 0.6
    # Train : gestion
    def clang(freq, length=0.25):
        m = int(length * RATE)
        return mix(osc("square", freq, length, 0.3) * exp_decay(m, 0.06) * 0.35, osc("sine", freq * 2.7, length) * exp_decay(m, 0.04) * 0.3,
                   noise(0.02, rng) * 0.5)
    s["craft"] = mix(at(clang(520), 0.0, 0.7), at(clang(560), 0.22, 0.7), at(clang(500), 0.44, 0.7))
    saw_t = t_axis(0.5)
    saw = highpass(noise(0.5, rng), 1500) * (0.5 + 0.5 * np.sin(2 * np.pi * 8 * saw_t)) * 0.4
    s["build"] = mix(at(clang(300, 0.3), 0.0, 1.0), at(saw, 0.25, 1.0), at(clang(340, 0.3), 0.8, 1.0)[: int(1.0 * RATE)])
    scrib = np.concatenate([highpass(noise(0.07, rng), 2500) * env(int(0.07 * RATE), 0.005, 0.06) * 0.4 for _ in range(4)])
    s["research"] = seq(scrib, osc("triangle", note_hz(84), 0.3) * env(int(0.3 * RATE), 0.002, 0.29) * 0.6)
    sc = noise(0.35, rng)
    s["coal_load"] = mix(lowpass(sc, 1400) * env(sc.size, 0.05, 0.1, 0.6, 0.1) * 0.6,
                         at(osc("sine", slide(140, 60, 0.12), 0.12) * exp_decay(int(0.12 * RATE), 0.04), 0.32, 0.5))
    hiss = highpass(noise(0.9, rng), 2500) * env(int(0.9 * RATE), 0.01, 0.2, 0.5, 0.5) * 0.35
    s["repair_done"] = mix(seq(osc("triangle", note_hz(79), 0.1) * env(int(0.1 * RATE), 0.002, 0.09), osc("triangle", note_hz(86), 0.35) * env(int(0.35 * RATE), 0.002, 0.34)) * 0.6,
                           at(hiss, 0.15, 1.05))
    s["breakdown"] = mix(clang(180, 0.4), at(clang(150, 0.4), 0.15, 1.2), at(highpass(noise(0.9, rng), 1800) * np.linspace(0.4, 0, int(0.9 * RATE)), 0.3, 1.2),
                         at(osc("square", slide(200, 50, 0.8), 0.8, 0.5) * env(int(0.8 * RATE), 0.01, 0.79) * 0.25, 0.25, 1.2))
    s["medicine"] = seq(osc("sine", slide(300, 700, 0.12), 0.12) * env(int(0.12 * RATE), 0.005, 0.115) * 0.6,
                        osc("sine", slide(350, 800, 0.12), 0.12) * env(int(0.12 * RATE), 0.005, 0.115) * 0.5)
    fan = [72, 76, 79, 84]
    s["promotion"] = np.concatenate([mix(osc("square", note_hz(m), 0.12, 0.25), osc("triangle", note_hz(m - 12), 0.12)) * env(int(0.12 * RATE), 0.003, 0.03, 0.7, 0.02) * 0.4 for m in fan] +
                                    [mix(osc("square", note_hz(84), 0.5, 0.25), osc("triangle", note_hz(72), 0.5), osc("square", note_hz(79), 0.5, 0.25) * 0.6) * env(int(0.5 * RATE), 0.003, 0.1, 0.6, 0.3) * 0.4])
    s["order_done"] = np.concatenate([osc("square", note_hz(m), 0.09, 0.25) * env(int(0.09 * RATE), 0.002, 0.085) * 0.4 for m in (79, 84)] +
                                     [osc("square", note_hz(88), 0.25, 0.25) * env(int(0.25 * RATE), 0.002, 0.24) * 0.4])
    s["infection_up"] = mix(osc("sine", 82, 1.0), osc("sine", 87, 1.0) * 0.8, osc("triangle", 164, 1.0) * 0.3) * env(int(1.0 * RATE), 0.2, 0.3, 0.6, 0.4) * 0.6
    # Tonnerre au loin (la pluie infectée approche) : grondement qui roule.
    th = noise(2.4, rng)
    rumble = lowpass(lowpass(th, 180), 260) * (0.6 + 0.4 * np.sin(2 * np.pi * 1.7 * t_axis(2.4)))
    crack = highpass(noise(0.3, rng), 900) * exp_decay(int(0.3 * RATE), 0.06) * 0.25
    s["thunder"] = mix(rumble * env(th.size, 0.05, 0.4, 0.6, 1.6), crack)
    # Pilleur qui repère le joueur : un « Hé ! » 8-bit (deux syllabes carrées).
    s["bark"] = seq(osc("square", slide(330, 420, 0.07), 0.07, 0.3) * env(int(0.07 * RATE), 0.004, 0.06),
                    osc("square", slide(470, 300, 0.13), 0.13, 0.3) * env(int(0.13 * RATE), 0.004, 0.12)) * 0.6
    # Sortie ratée (tombé, transformé, train manqué) : accord mineur qui descend.
    s["defeat"] = np.concatenate([mix(osc("triangle", note_hz(m), 0.22), osc("square", note_hz(m - 12), 0.22, 0.5) * 0.3) * env(int(0.22 * RATE), 0.004, 0.05, 0.7, 0.05)
                                  for m in (64, 60, 57)] +
                                 [mix(osc("triangle", note_hz(52), 0.7), osc("square", note_hz(40), 0.7, 0.5) * 0.3) * env(int(0.7 * RATE), 0.004, 0.2, 0.5, 0.45)]) * 0.6
    return {name: normalize(sig, 0.8, 0.2) for name, sig in s.items()}


def loops_all(rng: np.random.Generator) -> dict:
    """Boucles d'ambiance (4 s, sans couture)."""
    out = {}
    length = 4.0
    n = int(length * RATE)
    # Pluie : bruit filtré + gouttes ; on raccorde la fin au début par fondu croisé.
    rain = lowpass(noise(length + 0.5, rng), 2200) * 0.5 + highpass(noise(length + 0.5, rng), 4000) * 0.15
    drops = np.zeros(rain.size)
    for _ in range(90):
        pos = rng.uniform(0, length + 0.4)
        drops += at(osc("sine", rng.uniform(1800, 3200), 0.02) * exp_decay(int(0.02 * RATE), 0.005), pos, length + 0.5) * rng.uniform(0.1, 0.3)
    out["rain_loop"] = seamless(rain + drops, n)
    # Roulement : clac-clac des rails, régulier.
    rolling = lowpass(noise(length + 0.5, rng), 500) * 0.25
    for i in range(8):
        base = i * 0.5
        for off in (0.0, 0.12):
            rolling += at(lowpass(noise(0.05, rng), 1800) * exp_decay(int(0.05 * RATE), 0.012) * 0.9, base + off, length + 0.5)
    out["train_loop"] = seamless(rolling, n)
    return {k: normalize(v, 0.6) for k, v in out.items()}


def seamless(signal: np.ndarray, n: int) -> np.ndarray:
    """Boucle de n échantillons : la queue au-delà de n se fond dans le début."""
    fade = signal.size - n
    head = signal[:n].copy()
    ramp = np.linspace(0, 1, fade)
    head[:fade] = head[:fade] * ramp + signal[n:n + fade] * (1 - ramp)
    return head


# --- Musiques ------------------------------------------------------------------------

# Un morceau : tempo, tonalité (note MIDI de la tonique), mode, grille d'accords (degrés),
# et le caractère de chaque voix. Le hasard (graine) écrit la mélodie.
SCALES = {
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "major": [0, 2, 4, 5, 7, 9, 11],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
}

TRACKS = {
    # Écran titre : mélancolique, lent.
    "title": dict(bpm=78, root=57, mode="minor", chords=[0, 5, 2, 6, 0, 3, 4, 4], bars_per_chord=1, repeats=2,
                  drums="soft", lead=True, arp=True, pad=True, seed=3),
    # À bord et en trajet : chaleureux, au rythme des rails.
    "train": dict(bpm=92, root=60, mode="major", chords=[0, 4, 5, 3, 0, 4, 3, 4], bars_per_chord=1, repeats=2,
                  drums="rails", lead=True, arp=True, pad=True, seed=11),
    # Zone de jour : exploration tendue mais curieuse.
    "explore_day": dict(bpm=104, root=62, mode="dorian", chords=[0, 6, 3, 0, 0, 6, 4, 4], bars_per_chord=1, repeats=2,
                        drums="light", lead=True, arp=True, pad=False, seed=21),
    # Zone de nuit : rare, inquiétant.
    "explore_night": dict(bpm=76, root=52, mode="phrygian", chords=[0, 1, 0, 6, 0, 1, 5, 4], bars_per_chord=1, repeats=2,
                          drums="heart", lead=True, arp=False, pad=True, seed=31),
    # Horde : ça cogne.
    "danger": dict(bpm=144, root=57, mode="minor", chords=[0, 0, 5, 6, 0, 0, 3, 4], bars_per_chord=1, repeats=2,
                   drums="drive", lead=True, arp=True, pad=False, seed=41),
}


def chord_notes(root: int, scale: list, degree: int) -> list:
    """Accord de trois sons (tierces dans la gamme) sur un degré."""
    notes = []
    for step in (0, 2, 4):
        idx = degree + step
        notes.append(root + scale[idx % 7] + 12 * (idx // 7))
    return notes


def render_track(cfg: dict) -> np.ndarray:
    rng = np.random.default_rng(cfg["seed"])
    beat = 60.0 / cfg["bpm"]
    bar = beat * 4
    scale = SCALES[cfg["mode"]]
    grid = cfg["chords"] * cfg["repeats"]
    total = len(grid) * cfg["bars_per_chord"] * bar
    tail = bar  # de quoi laisser sonner la fin, refondue dans le début
    out = np.zeros(int((total + tail) * RATE))

    def place(signal, when):
        start = int(when * RATE)
        end = min(start + signal.size, out.size)
        out[start:end] += signal[: end - start]

    # La mélodie : une phrase de 4 mesures écrite au hasard, répétée avec variations (AABA).
    phrase = write_phrase(rng, scale, cfg)
    for i, degree in enumerate(grid):
        t0 = i * cfg["bars_per_chord"] * bar
        notes = chord_notes(cfg["root"], scale, degree)
        # Basse : croches sur la fondamentale (octave en dessous), pulse 25 %.
        bass_note = notes[0] - 12
        step = beat / 2 if cfg["drums"] in ("drive", "light", "rails") else beat
        tt = 0.0
        while tt < bar * cfg["bars_per_chord"] - 1e-6:
            note = bass_note + (12 if cfg["drums"] == "drive" and int(tt / step) % 2 else 0)
            length = step * 0.9
            place(osc("square", note_hz(note), length, 0.25) * env(int(length * RATE), 0.004, 0.05, 0.6, 0.04) * 0.22, t0 + tt)
            tt += step
        # Nappe : accord tenu, triangle doux.
        if cfg["pad"]:
            length = bar * cfg["bars_per_chord"]
            pad = sum(osc("triangle", note_hz(n), length) for n in notes) / 3
            place(pad * env(int(length * RATE), 0.3, 0.2, 0.7, 0.4) * 0.16, t0)
        # Arpège : doubles croches montantes, pulse fin 12,5 %, à l'octave.
        if cfg["arp"]:
            sixteenth = beat / 4
            arp_notes = [n + 12 for n in notes] + [notes[1] + 24]
            for k in range(int(bar * cfg["bars_per_chord"] / sixteenth)):
                n = arp_notes[k % len(arp_notes)]
                place(osc("square", note_hz(n), sixteenth * 0.8, 0.125) * env(int(sixteenth * 0.8 * RATE), 0.002, 0.06, 0.0) * 0.07,
                      t0 + k * sixteenth)
        # Mélodie : la phrase, posée sur les notes de l'accord aux temps forts.
        if cfg["lead"]:
            section = (i // 4) % 4
            bar_in_phrase = i % 4
            for onset, length, offset in phrase[bar_in_phrase]:
                if section == 2 and rng.random() < 0.35:
                    continue  # le « B » respire un peu
                note = cfg["root"] + 12 + offset + (2 if section == 2 else 0)
                note = snap(note, cfg["root"], scale)
                if onset % 2 == 0:
                    note = nearest_chord_tone(note, notes)
                sig = osc("square", note_hz(note), length * 0.95, 0.5)
                vibrato_env = env(sig.size, 0.01, 0.08, 0.55, 0.06)
                place(sig * vibrato_env * 0.11, t0 + onset * beat)
        # Batterie.
        for when, kind in drum_pattern(cfg["drums"], beat, bar * cfg["bars_per_chord"]):
            place(drum(kind, rng), t0 + when)
    # La fin retombe dans le début : boucle sans couture.
    n = int(total * RATE)
    looped = out[:n].copy()
    looped[: out.size - n] += out[n:]
    return normalize(looped, 0.8)


def write_phrase(rng: np.random.Generator, scale: list, cfg: dict) -> list:
    """4 mesures de mélodie : (début en temps, durée en secondes, écart en demi-tons)."""
    beat = 60.0 / cfg["bpm"]
    phrase = []
    degree = 0
    for bar_index in range(4):
        notes = []
        t = 0.0
        while t < 4.0 - 1e-6:
            length_beats = rng.choice([0.5, 1.0, 1.0, 1.5, 2.0]) if cfg["bpm"] < 120 else rng.choice([0.5, 0.5, 1.0])
            length_beats = min(length_beats, 4.0 - t)
            if rng.random() < 0.18:
                t += length_beats  # un silence
                continue
            degree = int(np.clip(degree + rng.choice([-2, -1, -1, 0, 1, 1, 2]), -3, 9))
            if bar_index == 3 and t + length_beats >= 4.0 - 1e-6:
                degree = 0  # la phrase se pose sur la tonique
            offset = scale[degree % 7] + 12 * (degree // 7)
            notes.append((t, length_beats * beat, offset))
            t += length_beats
        phrase.append(notes)
    return phrase


def snap(note: int, root: int, scale: list) -> int:
    """Ramène une note dans la gamme (au plus proche)."""
    rel = (note - root) % 12
    best = min(scale, key=lambda s: min(abs(s - rel), 12 - abs(s - rel)))
    return note - rel + best


def nearest_chord_tone(note: int, chord: list) -> int:
    candidates = [c + 12 * k for c in chord for k in range(-2, 4)]
    return min(candidates, key=lambda c: (abs(c - note), c))


def drum_pattern(style: str, beat: float, length: float) -> list:
    hits = []
    beats = int(round(length / beat))
    for b in range(beats):
        t = b * beat
        if style == "soft":
            if b % 4 == 0:
                hits.append((t, "kick"))
            if b % 4 == 2:
                hits.append((t, "shaker"))
        elif style == "rails":
            hits.append((t, "kick" if b % 2 == 0 else "snare_soft"))
            hits.append((t + beat * 0.5, "hat"))
            hits.append((t + beat * 0.75, "hat"))
        elif style == "light":
            if b % 2 == 0:
                hits.append((t, "kick"))
            else:
                hits.append((t, "snare_soft"))
            hits.append((t + beat / 2, "hat"))
        elif style == "heart":
            if b % 4 == 0:
                hits.append((t, "kick"))
                hits.append((t + beat * 0.35, "kick_soft"))
        elif style == "drive":
            hits.append((t, "kick"))
            if b % 2 == 1:
                hits.append((t, "snare"))
            hits.append((t + beat / 2, "hat"))
            hits.append((t + beat * 0.75, "kick_soft"))
    return hits


def drum(kind: str, rng: np.random.Generator) -> np.ndarray:
    if kind in ("kick", "kick_soft"):
        n = int(0.18 * RATE)
        k = osc("sine", slide(140, 45, 0.18), 0.18) * exp_decay(n, 0.06)
        return k * (0.5 if kind == "kick" else 0.25)
    if kind in ("snare", "snare_soft"):
        n = int(0.15 * RATE)
        s = highpass(noise(0.15, rng), 1200) * exp_decay(n, 0.04) + osc("triangle", 190, 0.15) * exp_decay(n, 0.03) * 0.4
        return s * (0.3 if kind == "snare" else 0.14)
    if kind == "hat":
        n = int(0.04 * RATE)
        return highpass(noise(0.04, rng), 6000) * exp_decay(n, 0.01) * 0.07
    if kind == "shaker":
        n = int(0.09 * RATE)
        return highpass(noise(0.09, rng), 4000) * env(n, 0.03, 0.06) * 0.06
    return np.zeros(1)


# --- Main ----------------------------------------------------------------------------

def main() -> None:
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "sfx"):
        rng = np.random.default_rng(7)
        sounds = sfx_all(rng)
        for name, sig in sounds.items():
            write_wav(SFX_DIR / f"{name}.wav", sig)
        loops = loops_all(rng)
        for name, sig in loops.items():
            write_ogg(SFX_DIR / f"{name}.ogg", sig, 3)
        print(f"{len(sounds)} bruitages, {len(loops)} boucles dans {SFX_DIR.relative_to(ROOT)}")
    if what in ("all", "music"):
        for name, cfg in TRACKS.items():
            sig = render_track(cfg)
            write_ogg(MUSIC_DIR / f"{name}.ogg", sig, 3)
            print(f"musique {name} : {sig.size / RATE:.1f} s")


if __name__ == "__main__":
    main()
