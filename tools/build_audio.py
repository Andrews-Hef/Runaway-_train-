#!/usr/bin/env python3
"""Prépare les musiques et bruitages du jeu à partir de sons libres (CC0 pour la plupart).

Les fichiers d'origine (téléchargés sur OpenGameArt, voir CREDITS) ne sont pas dans le
repo : on les range dans un dossier, archives décompressées, puis :

    python3 tools/build_audio.py <dossier_sources>

<dossier_sources>/music/ : les morceaux (rt_<moment>__<nom>.<ext>, cyber/ pour Cyber Runner)
<dossier_sources>/sfx/   : les packs de bruitages, décompressés

Le script :
- musiques : volume ramené au même niveau (-18 LUFS), OGG Vorbis compact, rangées par moment
  (assets/audio/music/<moment>/<nom>.ogg) ;
- bruitages : un ou plusieurs extraits mixés par son (recettes plus bas), silence coupé,
  volume égalisé, WAV mono 44,1 kHz (assets/audio/sfx/<son>.wav, ou <son>_1.wav, _2… quand
  il y a des variantes jouées au hasard) ;
- ambiances : pluie et roulement du train, en boucle sans couture (OGG) ;
- core/audio_catalog.gd : playlists, variantes et crédits, lus par l'autoload Audio.

Même sources, mêmes fichiers. Pour changer un son : modifier sa recette et relancer.
"""
import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parent.parent
SFX_OUT = ROOT / "assets" / "audio" / "sfx"
MUSIC_OUT = ROOT / "assets" / "audio" / "music"
CATALOG = ROOT / "core" / "audio_catalog.gd"
RATE = 44100
OGA = "https://opengameart.org/content/"

# --- Musiques ------------------------------------------------------------------------
# (moment, fichier source, nom, titre, auteur, page, licence)
MUSIC = [
    ("title", "rt_title__nova.mp3", "nova", "Nova", "SpringySpringo", "nova", "CC0"),
    ("title", "rt_title__main-menu-theme-diamond-dust.wav", "diamond_dust", "Main Menu Theme - Diamond Dust", "NBJDLukasAbsolute", "main-menu-theme-diamond-dust", "CC0"),
    ("title", "rt_title__vintage-menu.mp3", "vintage_menu", "Vintage Menu", "iamoneabe", "vintage-menu", "CC0"),
    ("train", "rt_train__midnight-drive.ogg", "midnight_drive", "Midnight Drive", "congusbongus", "midnight-drive", "CC0"),
    ("train", "rt_train__all-the-fight-left.ogg", "all_the_fight_left", "All The Fight Left!", "Holizna", "all-the-fight-left", "CC0"),
    ("train", "rt_train__calm-relax-1-synthwave-421k.mp3", "synthwave_421k", "Calm Relax 1 (Synthwave 421k)", "The Cynic Project (cynicmusic)", "calm-relax-1-synthwave-421k", "CC0"),
    ("explore_day", "rt_day__lost-in-the-snow-wave.ogg", "lost_in_the_snow_wave", "Lost in the Snow Wave", "hatmix", "lost-in-the-snow-wave", "CC0"),
    ("explore_day", "rt_day__space-adventure.ogg", "space_adventure", "Space Adventure", "MintoDog", "space-adventure", "CC0"),
    ("explore_day", "rt_day__lofi-compilation__a-cup-of-tea.mp3", "a_cup_of_tea", "A cup of tea (lofi Compilation)", "TAD", "lofi-compilation", "CC0"),
    ("explore_day", "rt_day__lofi-compilation__cue.mp3", "cue", "Cue (lofi Compilation)", "TAD", "lofi-compilation", "CC0"),
    ("explore_day", "rt_day__lofi-compilation__bartender.mp3", "bartender", "Bartender (lofi Compilation)", "TAD", "lofi-compilation", "CC0"),
    ("explore_day", "rt_day__lofi-compilation__cat-caffe.mp3", "cat_caffe", "Cat caffe (lofi Compilation)", "TAD", "lofi-compilation", "CC0"),
    ("explore_day", "rt_day__lofi-compilation__rainy-forest.mp3", "rainy_forest", "Rainy Forest (lofi Compilation)", "TAD", "lofi-compilation", "CC0"),
    ("explore_day", "rt_day__lofi-compilation__countryside.mp3", "countryside", "Countryside (lofi Compilation)", "TAD", "lofi-compilation", "CC0"),
    ("explore_day", "rt_day__lofi-compilation__oceanside.mp3", "oceanside", "Oceanside (lofi Compilation)", "TAD", "lofi-compilation", "CC0"),
    ("explore_day", "rt_day__lofi-compilation__florist.mp3", "florist", "Florist (lofi Compilation)", "TAD", "lofi-compilation", "CC0"),
    ("explore_day", "rt_day__lofi-compilation__morning-rain.mp3", "morning_rain", "Morning rain (lofi Compilation)", "TAD", "lofi-compilation", "CC0"),
    ("explore_day", "rt_day__chill-lofi-inspired-loop-edit.ogg", "chill_lofi", "Chill lofi inspired (loop edit)", "omfgdude, boucle par qubodup", "chill-lofi-inspired-loop-edit", "CC0"),
    ("explore_day", "rt_day__november-snow.mp3", "november_snow", "November Snow", "The Cynic Project (cynicmusic)", "november-snow", "CC0"),
    ("explore_day", "rt_day__shinsei.mp3", "shinsei", "Shinsei", "Gichco (obscure music)", "shinsei", "CC0"),
    ("explore_day", "rt_day__lofi-hip-hop.ogg", "lofi_hip_hop", "lofi hip hop", "omfgdude", "lofi-hip-hop", "CC0"),
    ("explore_day", "rt_day__chills.ogg", "chills", "Chills", "Holizna", "chills", "CC0"),
    ("explore_day", "rt_day__in-the-lobby.wav", "in_the_lobby", "In the Lobby", "Umplix", "in-the-lobby", "CC0"),
    ("explore_day", "rt_day__dimly-lit.mp3", "dimly_lit", "Dimly lit", "iamoneabe", "dimly-lit", "CC0"),
    ("explore_day", "rt_day__glo-in-the-dark.mp3", "glo_in_the_dark", "Glo in the dark", "iamoneabe", "glo-in-the-dark", "CC0"),
    ("explore_night", "rt_night__80s-mysterywave-music.mp3", "mysterywave", "80s Mysterywave music", "DesertDev", "80s-mysterywave-music", "CC0"),
    ("explore_night", "rt_night__kalypo.flac", "kalypo", "Kalypo", "Spring Spring", "kalypo", "CC0"),
    ("explore_night", "rt_night__iced-village-8-bit-lofi-hip-hop.mp3", "iced_village", "Iced Village (8 Bit Lofi Hip Hop)", "TAD", "iced-village-8-bit-lofi-hip-hop", "CC0"),
    ("explore_night", "rt_night__the-past-8-bit-lofi-hip-hop.mp3", "the_past", "The Past (8 Bit Lofi Hip Hop)", "TAD", "the-past-8-bit-lofi-hip-hop", "CC0"),
    ("explore_night", "rt_night__since-2-am.mp3", "since_2_am", "Since 2 A.M.", "TAD", "since-2-am", "CC0"),
    ("explore_night", "rt_night__ooame.mp3", "ooame", "Ooame", "TAD", "ooame", "CC0"),
    ("explore_night", "rt_night__8-bit-lofi-ice-cave.mp3", "ice_cave", "8 bit lofi - Ice Cave", "TAD", "8-bit-lofi-ice-cave", "CC0"),
    ("explore_night", "rt_night__descent.mp3", "descent", "Descent", "James Gargette (cinameng)", "descent", "CC0"),
    ("explore_night", "rt_night__a-detuned-memory.mp3", "detuned_memory", "A Detuned Memory", "Tarush Singhal", "a-detuned-memory", "CC0"),
    ("explore_night", "rt_night__pyro.mp3", "pyro", "Pyro", "James Gargette (cinameng)", "pyro", "CC0"),
    ("danger", "rt_danger__futility-belt.mp3", "futility_belt", "Futility Belt", "iamoneabe", "futility-belt", "CC0"),
    ("danger", "cyber/Cyber_runer_files/cyber_runner.ogg", "cyber_runner", "Cyber Runner Music", "Luis Zuno (ansimuz)", "cyber-runner-music", "CC0"),
    ("danger", "rt_danger__down-to-business-day-25.wav", "down_to_business", "Down to Business - Day 25", "Zane Little Music", "down-to-business-day-25", "CC0"),
    ("defeat", "rt_defeat__game-over-diamond-dust.wav", "game_over", "Game Over - Diamond Dust", "NBJDLukasAbsolute", "game-over-diamond-dust", "CC0"),
]

# --- Packs de bruitages (crédits) ------------------------------------------------------
# dossier source -> (titre, auteur, page, licence)
PACKS = {
    "interface": ("Interface Sounds", "Kenney (kenney.nl)", "interface-sounds", "CC0"),
    "jingles": ("85 Short music jingles", "Kenney (kenney.nl)", "85-short-music-jingles", "CC0"),
    "swishes": ("Swishes Sound Pack", "artisticdude", "swishes-sound-pack", "CC0"),
    "hits": ("37 hits/punches", "Independent.nu", "37-hitspunches", "CC0"),
    "screams": ("15 vocal male strain/hurt/pain/jump sounds", "qubodup", "15-vocal-male-strainhurtpainjump-sounds", "CC0"),
    "creature": ("80 CC0 creature SFX", "rubberduck", "80-cc0-creature-sfx", "CC0"),
    "zombies": ("Zombies Sound Pack", "artisticdude", "zombies-sound-pack", "CC0"),
    "moans": ("Zombie moans", "Darsycho", "zombie-moans", "CC0"),
    "yells": ("Male Grunt/Yelling sounds", "HaelDB", "male-gruntyelling-sounds", "CC0"),
    # La page OpenGameArt dit CC0, le fichier dans l'archive dit CC-BY 3.0 : on suit le plus strict.
    "gunshots": ("Gunshot Sounds", "Vincent Sevedge (publié par Tabasco)", "gunshot-sounds", "CC-BY 3.0"),
    "rpg": ("80 CC0 RPG SFX", "rubberduck", "80-cc0-rpg-sfx", "CC0"),
    "paper": ("Various Paper Sound Effects", "Luckius", "various-paper-sound-effects", "CC0"),
    "pencil": ("Pencil Sounds", "AntumDeluge", "pencil-sounds", "CC0"),
    "steam": ("Steam release sounds", "bart", "steam-release-sounds", "CC0"),
    "whistle": ("Steam whistle", "bart", "steam-whistle", "CC0"),
    "boiler": ("Steam boiler sound loop", "bart", "steam-boiler-sound-loop", "CC0"),
    "doors": ("Door Open, Door Close Set", "qubodup", "door-open-door-close-set", "CC0"),
    "metal": ("Metal Impact Sounds", "Brian MacIntosh (BMacZero)", "metal-impact-sounds", "CC0"),
    "loops": ("30 CC0 SFX loops", "rubberduck", "30-cc0-sfx-loops", "CC0"),
    "metalwood": ("100 CC0 metal and wood SFX", "rubberduck", "100-cc0-metal-and-wood-sfx", "CC0"),
    "workshop": ("68 Workshop Sounds", "bart", "68-workshop-sounds", "CC0"),
    "bottle": ("Liquid Bottle Drink Set", "qubodup", "liquid-bottle-drink-set", "CC0"),
    "heartbeat": ("Heartbeat sounds", "bart", "heartbeat-sounds", "CC0"),
    "rain": ("Rain (loopable)", "Ylmir", "rain-loopable", "CC0"),
    "thunder": ("Rain + Long Thunder", "WuxiaScrub", "rain-long-thunder", "CC0"),
}

DIRS = {
    "interface": "rt_sfx__interface-sounds__kenney-interfacesounds/Audio/",
    "jingles": "rt_sfx__85-short-music-jingles__jinglesounds-kenney/OGG/",
    "swishes": "rt_sfx__swishes-sound-pack__swishes/swishes/",
    "hits": "rt_sfx__37-hitspunches__independent-nu-ljudbank-hits-and-punches/hits/",
    "screams": "rt_sfx__15-vocal-male-strainhurtpainjump-sounds__slightscreams/",
    "creature": "rt_sfx__80-cc0-creature-sfx__80-cc0-creature-sfx/",
    "zombies": "rt_sfx__zombies-sound-pack__zombies/zombies/",
    "moans": "",
    "yells": "rt_sfx__male-gruntyelling-sounds__yelling-sounds/yelling sounds/",
    "gunshots": "rt_sfx__gunshot-sounds__sounds/sounds/",
    "rpg": "rt_sfx__80-cc0-rpg-sfx__80-cc0-rpg-sfx/",
    "paper": "rt_sfx__various-paper-sound-effects__sounds/WAV/",
    "pencil": "rt_sfx__pencil-sounds__pencil/ogg/",
    "steam": "rt_sfx__steam-release-sounds__steam-hisses/",
    "whistle": "",
    "boiler": "",
    "doors": "rt_sfx__door-open-door-close-set__qubodup-doorset/qubodup-DoorSet/ogg/",
    "metal": "",
    "loops": "rt_sfx__30-cc0-sfx-loops__sfx-loops/",
    "metalwood": "rt_sfx__100-cc0-metal-and-wood-sfx__100-cc0-wood-metal-sfx/",
    "workshop": "rt_sfx__68-workshop-sounds__workshop/workshop/workshop - ",
    "bottle": "rt_sfx__liquid-bottle-drink-set__qubodup-bottle-and-drink-sounds/qubodup-bottle-and-drink-sounds/",
    "heartbeat": "",
    "rain": "rt_sfx__rain-loopable__rain-ogg/",
    "thunder": "",
}


def L(pack: str, name: str, at: float = 0.0, start: float | None = None, dur: float | None = None,
      gain: float = 0.0, lp: float | None = None, hp: float | None = None, drive: float = 0.0) -> dict:
    """Un extrait : `start` None = calé sur l'attaque du son ; `at` = moment où il entre dans le mix."""
    return dict(pack=pack, name=name, at=at, start=start, dur=dur, gain=gain, lp=lp, hp=hp, drive=drive)


# Recettes : son -> liste de variantes ; une variante = liste d'extraits mixés.
SFX = {
    "ui_click": [[L("interface", "click_001.ogg")]],
    "ui_open": [[L("interface", "open_002.ogg")]],
    "ui_close": [[L("interface", "close_002.ogg")]],
    "ui_error": [[L("interface", "error_004.ogg")]],
    "encounter": [[L("interface", "question_001.ogg")]],
    "swing": [[L("swishes", f"swish-{n}.wav")] for n in (3, 7, 9)],
    "hit": [[L("hits", f"hit{n}.mp3.flac", dur=0.45)] for n in (21, 24, 28, 33)],
    "hurt": [[L("screams", f"slightscream-{n:02d}.flac")] for n in (8, 11, 1)],
    "enemy_die": [[L("zombies", "zombie-16.wav", dur=1.2)], [L("rpg", "creature_die_01.ogg")]],
    "raider_die": [[L("yells", "3grunt1.wav", dur=0.5)], [L("yells", "yell12.wav", dur=0.6)]],
    "shot": [[L("gunshots", "cz.wav", dur=0.5)], [L("gunshots", "sks.wav", dur=0.5)], [L("gunshots", "mosin.wav", dur=0.6)]],
    "spit": [[L("creature", "spit_02.ogg")], [L("creature", "spit_01.ogg")]],
    "growl": [[L("zombies", f"zombie-{n}.wav")] for n in (4, 6, 7, 10)],
    "bark": [[L("yells", "yell12.wav", dur=0.7)], [L("yells", "yell7.wav", dur=0.6)], [L("yells", "2yell1.wav", dur=0.45)]],
    "freed": [[L("yells", "3grunt4.wav", dur=0.3), L("swishes", "swish-2.wav", at=0.05, gain=-6)]],
    "pickup": [[L("rpg", "item_misc_01.ogg")], [L("rpg", "item_misc_02.ogg")], [L("rpg", "item_wood_03.ogg")]],
    "drop": [[L("interface", "drop_003.ogg"), L("rpg", "item_stone_01.ogg", gain=-6)]],
    "plan_found": [[L("paper", "Paper Sound - 1.wav"), L("jingles", "jingles_NES/jingles_NES09.ogg", at=0.25, gain=-3)]],
    "whistle": [[L("whistle", "rt_sfx__steam-whistle__steam-whistle.wav")]],
    "train_depart": [[L("steam", "steam hisses - Marker #1.wav"),
                      L("boiler", "rt_sfx__steam-boiler-sound-loop__generator-loop.wav", at=0.3, start=2.0, dur=2.4, gain=-6)]],
    "brake": [[L("workshop", "scrape1.wav", dur=1.2), L("steam", "steam hisses - Marker #2.wav", at=0.2, gain=-3)]],
    "door": [[L("doors", "qubodup-DoorClose07.ogg")], [L("doors", "qubodup-DoorOpen05.ogg")]],
    "train_hit": [[L("metalwood", "metal_slam_01.ogg"), L("metal", "rt_sfx__metal-impact-sounds__bong1.wav", gain=-10, dur=0.8)],
                  [L("metalwood", "metal_hit_01.ogg"), L("metal", "rt_sfx__metal-impact-sounds__bong1.wav", gain=-12, dur=0.8)]],
    "horde": [[L("zombies", "zombie-16.wav"), L("zombies", "zombie-17.wav", at=0.15, gain=-2),
               L("zombies", "zombie-18.wav", at=0.35, gain=-3), L("zombies", "zombie-21.wav", at=0.6, gain=-2),
               L("moans", "rt_sfx__zombie-moans__darsycho-zombie-moans.ogg", at=0.2, start=0.25, dur=2.2, gain=-4)]],
    "alarm": [[L("loops", "alarm_01.ogg")]],
    "thunder": [[L("thunder", "rt_sfx__rain-long-thunder__rain-thunder.ogg", start=21.0, dur=7.0)]],
    "craft": [[L("metalwood", "hammer_01.ogg"), L("metalwood", "hammer_03.ogg", at=0.28), L("metalwood", "hammer_02.ogg", at=0.56)]],
    "build": [[L("workshop", "metal hammering.wav", dur=1.0), L("loops", "saw.ogg", at=0.9, start=0.0, dur=1.1, gain=-3)]],
    "research": [[L("pencil", "pencil_write.ogg", dur=0.9), L("paper", "Paper Sound - 2.wav", at=0.85)]],
    "coal_load": [[L("rpg", "stones_01.ogg"), L("rpg", "stones_02.ogg", at=0.25), L("metalwood", "metal_hit_03.ogg", at=0.6, gain=-4)]],
    "repair_done": [[L("metalwood", "tools_07.ogg"), L("steam", "steam hisses - Marker #3.wav", at=0.25)]],
    "breakdown": [[L("metalwood", "metal_falling_02.ogg"), L("metal", "rt_sfx__metal-impact-sounds__bong1.wav", at=0.1, gain=-3),
                   L("steam", "steam hisses - Marker #4.wav", at=0.3)]],
    "medicine": [[L("bottle", "bottle-open-01.flac"), L("bottle", "swallow-02.flac", at=0.45)]],
    "promotion": [[L("jingles", "jingles_SAX/jingles_SAX02.ogg")]],
    "order_done": [[L("jingles", "jingles_SAX/jingles_SAX15.ogg")]],
    "defeat": [[L("jingles", "jingles_SAX/jingles_SAX01.ogg")]],
    # Le cœur est très grave : un peu de saturation pour qu'on l'entende sur un téléphone.
    "infection_up": [[L("heartbeat", "rt_sfx__heartbeat-sounds__heartbeat-fast-0.wav", drive=4.0)]],
}

# Volume moyen visé pour chaque bruitage (le reste du mixage se règle dans core/audio.gd).
SFX_RMS_DB = -16.0
SFX_PEAK_DB = -1.0


# --- Briques ---------------------------------------------------------------------------

def decode(path: Path, channels: int = 1) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-f", "f32le", "-ac", str(channels),
                          "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    data = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    return data.reshape(-1, channels) if channels > 1 else data


def onset(signal: np.ndarray, db: float = -30.0) -> int:
    peak = np.max(np.abs(signal)) or 1.0
    hits = np.where(np.abs(signal) > peak * 10 ** (db / 20))[0]
    return max(int(hits[0]) - int(0.004 * RATE), 0) if hits.size else 0


def trim_tail(signal: np.ndarray, db: float = -45.0) -> np.ndarray:
    peak = np.max(np.abs(signal)) or 1.0
    hits = np.where(np.abs(signal) > peak * 10 ** (db / 20))[0]
    return signal[: int(hits[-1]) + 1] if hits.size else signal


def fade(signal: np.ndarray, fade_in: float = 0.003, fade_out: float = 0.03) -> np.ndarray:
    out = signal.copy()
    a, b = min(int(fade_in * RATE), out.size), min(int(fade_out * RATE), out.size)
    if a:
        out[:a] *= np.linspace(0, 1, a)
    if b:
        out[-b:] *= np.linspace(1, 0, b)
    return out


def filt(signal: np.ndarray, lp: float | None, hp: float | None) -> np.ndarray:
    if lp:
        signal = sosfilt(butter(4, lp, "low", fs=RATE, output="sos"), signal)
    if hp:
        signal = sosfilt(butter(2, hp, "high", fs=RATE, output="sos"), signal)
    return signal


def layer(src: Path, spec: dict) -> np.ndarray:
    path = src / "sfx" / (DIRS[spec["pack"]] + spec["name"])
    data = decode(path)
    start = onset(data) if spec["start"] is None else int(spec["start"] * RATE)
    data = data[start:]
    if spec["dur"]:
        data = data[: int(spec["dur"] * RATE)]
    data = trim_tail(data)
    data = filt(data, spec["lp"], spec["hp"])
    if spec["drive"]:
        data = np.tanh(data / (np.max(np.abs(data)) or 1.0) * spec["drive"])
    peak = np.max(np.abs(data)) or 1.0
    return fade(data / peak * 10 ** (spec["gain"] / 20), fade_out=0.04 if spec["dur"] else 0.01)


def mix_layers(src: Path, layers: list) -> np.ndarray:
    parts = [(int(spec["at"] * RATE), layer(src, spec)) for spec in layers]
    out = np.zeros(max(offset + part.size for offset, part in parts))
    for offset, part in parts:
        out[offset: offset + part.size] += part
    return out


def level(signal: np.ndarray, rms_db: float, peak_db: float) -> np.ndarray:
    rms = np.sqrt(np.mean(signal ** 2)) or 1e-9
    peak = np.max(np.abs(signal)) or 1e-9
    return signal * min(10 ** (rms_db / 20) / rms, 10 ** (peak_db / 20) / peak)


def write_wav(path: Path, signal: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(signal, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1 if data.ndim == 1 else data.shape[1])
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def ogg(src_path: Path, dest: Path, quality: int, extra: list | None = None) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(src_path), *(extra or []), "-ar", str(RATE),
                    "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis", "-q:a", str(quality),
                    str(dest)], check=True)


def seamless(signal: np.ndarray, length: int, overlap: int) -> np.ndarray:
    """Boucle de `length` échantillons : ce qui dépasse se fond dans le début."""
    out = signal[:length].copy()
    ramp = np.linspace(0, 1, overlap)
    out[:overlap] = out[:overlap] * ramp + signal[length: length + overlap] * (1 - ramp)
    return out


# --- Construction ----------------------------------------------------------------------

def build_music(src: Path) -> dict:
    playlists: dict = {}
    for moment, source, name, *_ in MUSIC:
        path = src / "music" / source
        # Deux passes de loudnorm : mesure, puis correction linéaire (pas de pompage).
        probe = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af",
                                "loudnorm=I=-18:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"],
                               capture_output=True, text=True).stderr
        stats = json.loads(probe[probe.rindex("{"): probe.rindex("}") + 1])
        norm = ("loudnorm=I=-18:TP=-1.5:LRA=11:linear=true:measured_I={input_i}:measured_TP={input_tp}:"
                "measured_LRA={input_lra}:measured_thresh={input_thresh}:offset={target_offset}").format(**stats)
        dest = MUSIC_OUT / moment / f"{name}.ogg"
        # Un léger fondu au début évite le « clic » d'entrée.
        ogg(path, dest, 0, ["-af", norm + ",afade=t=in:d=0.05"])
        playlists.setdefault(moment, []).append(f"{moment}/{name}")
        print(f"  musique {moment}/{name}: {dest.stat().st_size / 1e6:.1f} Mo")
    return playlists


def build_sfx(src: Path) -> dict:
    variants: dict = {}
    for name, recipes in SFX.items():
        for old in SFX_OUT.glob(f"{name}*.wav"):
            if old.stem == name or old.stem.rsplit("_", 1)[0] == name and old.stem.rsplit("_", 1)[1].isdigit():
                old.unlink()
                Path(str(old) + ".import").unlink(missing_ok=True)
        for index, recipe in enumerate(recipes, 1):
            sound = level(fade(mix_layers(src, recipe)), SFX_RMS_DB, SFX_PEAK_DB)
            write_wav(SFX_OUT / (f"{name}_{index}.wav" if len(recipes) > 1 else f"{name}.wav"), sound)
        variants[name] = len(recipes)
    print(f"  {len(SFX)} bruitages, {sum(variants.values())} fichiers")
    return variants


def build_loops(src: Path) -> None:
    # Pluie : 26 s, raccord fondu sur 1 s.
    rain = decode(src / "sfx" / DIRS["rain"] / "1.ogg")
    loop = seamless(rain, rain.size - RATE, RATE)
    write_tmp_ogg(level(loop, -20, -3), SFX_OUT / "rain_loop.ogg")
    # Roulement : grondement de la chaudière + « ta-tam » des rails (impacts métalliques étouffés).
    length = 8 * RATE
    rumble = decode(src / "sfx" / "rt_sfx__steam-boiler-sound-loop__generator-loop.wav")[: length + RATE]
    rumble = filt(rumble, 500, 40) * 0.35
    clack_a = filt(decode(src / "sfx" / "rt_sfx__metal-impact-sounds__thud3.wav"), 2200, 80)
    clack_b = filt(decode(src / "sfx" / "rt_sfx__metal-impact-sounds__thud2.wav"), 2200, 80)
    clacks = np.zeros(length + RATE)
    for beat in range(8):
        for offset, clack, gain in ((0.0, clack_a, 1.0), (0.16, clack_b, 0.8)):
            pos = int((beat + offset) * RATE)
            part = clack[onset(clack):][: int(0.3 * RATE)] / (np.max(np.abs(clack)) or 1) * gain
            clacks[pos: pos + part.size] += part[: clacks.size - pos]
    write_tmp_ogg(level(seamless(rumble + clacks * 0.6, length, RATE // 2), -22, -3), SFX_OUT / "train_loop.ogg")
    print("  ambiances : pluie, roulement")


def write_tmp_ogg(signal: np.ndarray, dest: Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        write_wav(wav, signal)
        ogg(wav, dest, 2)


def gd_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_catalog(playlists: dict, variants: dict) -> None:
    lines = [
        "class_name AudioCatalog",
        "## Généré par tools/build_audio.py : ne pas modifier à la main.",
        "##",
        "## Playlists de musique par moment du jeu, variantes de chaque bruitage, et crédits",
        "## (affichés par l'écran Crédits).",
        "",
        "## Moment -> morceaux (chemins sous assets/audio/music/, sans extension).",
        "const PLAYLISTS: Dictionary[StringName, Array] = {",
    ]
    for moment, tracks in playlists.items():
        lines.append(f"\t&\"{moment}\": [{', '.join(gd_string(t) for t in tracks)}],")
    lines += ["}", "", "## Bruitage -> nombre de variantes (une seule : <son>.wav ; plusieurs : <son>_1.wav…).",
              "const VARIANTS: Dictionary[StringName, int] = {"]
    for name, count in variants.items():
        lines.append(f"\t&\"{name}\": {count},")
    lines += ["}", "", "## [titre, auteur, licence, lien]", "const MUSIC_CREDITS: Array[Array] = ["]
    seen = set()
    for _moment, _source, _name, title, author, page, licence in MUSIC:
        key = (title if "lofi Compilation" not in title else "lofi Compilation", author)
        if key in seen:
            continue
        seen.add(key)
        shown = "lofi Compilation (9 morceaux)" if "lofi Compilation" in title else title
        lines.append(f"\t[{gd_string(shown)}, {gd_string(author)}, {gd_string(licence)}, {gd_string(OGA + page)}],")
    lines += ["]", "", "const SFX_CREDITS: Array[Array] = ["]
    for title, author, page, licence in PACKS.values():
        lines.append(f"\t[{gd_string(title)}, {gd_string(author)}, {gd_string(licence)}, {gd_string(OGA + page)}],")
    lines.append("]")
    CATALOG.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"  catalogue : {CATALOG.relative_to(ROOT)}")
    write_credits(playlists)


def write_credits(playlists: dict) -> None:
    """assets/audio/CREDITS.md : qui a fait quoi, sous quelle licence, où le trouver."""
    names = {"title": "Écran titre", "train": "Train (à bord, trajet, gare)", "explore_day": "Exploration de jour",
             "explore_night": "Exploration de nuit", "danger": "Horde", "defeat": "Sortie ratée"}
    out = ["# Crédits audio", "",
           "Musiques et bruitages libres, trouvés sur [OpenGameArt](https://opengameart.org) et préparés par",
           "`tools/build_audio.py` (volume égalisé, découpe, conversion). CC0 = domaine public : aucun crédit",
           "obligatoire, on remercie quand même. CC-BY = crédit obligatoire.", "", "## Musiques", ""]
    for moment in playlists:
        out.append(f"### {names.get(moment, moment)}")
        out.append("")
        for m, _source, name, title, author, page, licence in MUSIC:
            if m == moment:
                out.append(f"- **{title}** — {author} — {licence} — {OGA + page}")
        out.append("")
    out += ["## Bruitages", "", "Packs dont viennent les extraits (souvent mixés entre eux) :", ""]
    for title, author, page, licence in PACKS.values():
        out.append(f"- **{title}** — {author} — {licence} — {OGA + page}")
    (ROOT / "assets" / "audio" / "CREDITS.md").write_text("\n".join(out) + "\n", encoding="utf-8")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = Path(sys.argv[1]).resolve()
    what = sys.argv[2] if len(sys.argv) > 2 else "all"
    playlists = {}
    variants = {}
    if what in ("all", "music"):
        for old in [*MUSIC_OUT.rglob("*.ogg"), *MUSIC_OUT.rglob("*.ogg.import")]:
            old.unlink()
        playlists = build_music(src)
    if what in ("all", "sfx"):
        variants = build_sfx(src)
        build_loops(src)
    if what == "all":
        write_catalog(playlists, variants)


if __name__ == "__main__":
    main()
