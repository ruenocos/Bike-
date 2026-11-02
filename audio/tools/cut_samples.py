#!/usr/bin/env python
"""Cuts the game's sounds out of the downloaded CC0 packs (audio/sfx/).

Only edits existing recordings and pack samples: trim, mix takes, pitch by
resampling, filter, normalize, crossfade loop seams. It generates no sound:
no oscillators, no noise. Packs live outside the repo (Bike/sound-packs/).

Usage: python cut_samples.py <sound-packs dir> <audio/sfx dir> <manifest.csv>
Needs numpy and imageio-ffmpeg.
"""
import csv
import os
import subprocess
import sys

import imageio_ffmpeg
import numpy as np

SR = 44100
FF = imageio_ffmpeg.get_ffmpeg_exe()
PACKS, OUT, MANIFEST = sys.argv[1:4]
K_IMP = "kenney_impact-sounds/x/Audio/"
K_INT = "kenney_interface-sounds/x/Audio/"
K_JIN = "kenney_music-jingles/x/Audio/Steel jingles/"
O = {
	"swish": "oga_swishes-sound-pack/x/swishes/swish-%d.wav",
	"scrape": "oga_scrapes/x/scrape-%d.wav",
	"mech": "oga_mechanical-sounds/%s.wav",
	"ping": "oga_31-pings-and-metal-filing-sounds/x/pings and scrapes/pings and scrapes - Marker #%d.wav",
	"park": "oga_park-ambiences/park_ambience_wind.wav",
	"woosh": "oga_wind-whoosh-loop/wind woosh loop.ogg",
	"shortwind": "oga_short-wind-sound/short wind sound.wav",
	"road": "oga_high-traffic-road-sounds/gatve Varniu_2.ogg",
	"roll": "oga_bowling-ball-rolling/x/qubodup-bowling-roll/qubodup-bowling_roll-nofadeout.ogg",
	"rumble": "oga_rumble-fx/rumble.wav",
	"shake": "oga_earthquake-and-open-sesame/shake.flac",
	"cavein": "oga_cave-in/cave_in_-_starninjas_0.ogg",
	"crash": "oga_crash-collision/qubodup-crash.ogg",
	"idle": "oga_enginemechanic-working-sound/loop.flac",
	"racing": "oga_racing-car-engine-sound-loops/loop_0.wav",
	"steam": "oga_steamboat-engine-sound/steamboat_engine.wav",
	"car": "oga_car-sound-effects-pack-low-quality/x/%s.ogg",
	"winch": "oga_chain-winch-sounds/x/winch - %s.wav",
	"loops": "oga_30-cc0-sfx-loops/x/%s.ogg",
	"bang": "oga_25-cc0-bang-firework-sfx/x/%s.ogg",
	"cannon": "oga_cannon-fire/cannon_fire_0.ogg",
	"rpg": "oga_80-cc0-rpg-sfx/x/%s.ogg",
	"chop": "kenney_rpg-audio/x/Audio/chop.ogg",
}
rows: list = []


def load(rel: str, af: str = "") -> np.ndarray:
	"""Stereo float samples, shape (n, 2)."""
	cmd = [FF, "-v", "error", "-i", os.path.join(PACKS, rel), "-ac", "2", "-ar", str(SR)]
	if af:
		cmd += ["-af", af]
	raw = subprocess.run(cmd + ["-f", "f32le", "-"], capture_output=True, check=True).stdout
	return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def pitch(x: np.ndarray, semitones: float) -> np.ndarray:
	"""Resample: pitch and length change together, like a tape."""
	if semitones == 0.0:
		return x
	ratio = 2.0 ** (semitones / 12.0)
	pos = np.arange(0.0, len(x) - 1, ratio)
	return np.stack([np.interp(pos, np.arange(len(x)), x[:, c]) for c in (0, 1)], axis=1)


def fade_out(x: np.ndarray, seconds: float) -> np.ndarray:
	n = min(int(seconds * SR), len(x))
	y = x.copy()
	y[len(x) - n:] *= np.linspace(1.0, 0.0, n)[:, None]
	return y


def peak_norm(x: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
	return x / max(np.abs(x).max(), 1e-9) * 10.0 ** (peak_db / 20.0)


def rms_norm(x: np.ndarray, rms_db: float) -> np.ndarray:
	y = x / max(np.sqrt((x ** 2).mean()), 1e-9) * 10.0 ** (rms_db / 20.0)
	return y if np.abs(y).max() <= 0.89 else peak_norm(y, -1.0)


def mix(parts: list) -> tuple:
	"""parts: (path, gain dB, delay s, semitones, length s or 0). Returns (samples, sources)."""
	takes = []
	for rel, gain, delay, semis, length in parts:
		x = peak_norm(pitch(load(rel), semis), 0.0) * 10.0 ** (gain / 20.0)
		if length > 0.0:
			x = fade_out(x[: int(length * SR)], min(0.05, length * 0.3))
		takes.append((int(delay * SR), x))
	n = max(d + len(x) for d, x in takes)
	out = np.zeros((n, 2))
	for d, x in takes:
		out[d: d + len(x)] += x
	return out, [p[0] for p in parts]


def steady_window(x: np.ndarray, seconds: float) -> np.ndarray:
	"""The evenest stretch of a long recording that isn't one of its quiet parts."""
	hop = SR // 4
	env = np.array([np.sqrt((x[i: i + hop] ** 2).mean()) for i in range(0, len(x) - hop, hop)])
	win = int(seconds * SR / hop)
	best, best_score = 0, 1e12
	floor = np.median(env)
	for i in range(0, len(env) - win):
		w = env[i: i + win]
		if w.mean() < floor:
			continue
		score = w.std() / w.mean() + (w.max() / w.mean()) * 0.2
		if score < best_score:
			best, best_score = i, score
	return x[best * hop: (best + win) * hop]


def loop_seam(x: np.ndarray, seconds: float) -> np.ndarray:
	"""Equal-power crossfade of the tail into the head, so it loops."""
	n = int(seconds * SR)
	t = np.linspace(0.0, np.pi / 2.0, n)[:, None]
	y = x[:-n].copy()
	y[:n] = x[:n] * np.sin(t) + x[-n:] * np.cos(t)
	return y


def write(name: str, x: np.ndarray, sources: list, note: str) -> None:
	path = os.path.join(OUT, name)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	x = np.clip(x, -1.0, 1.0).astype(np.float32)
	codec = ["-c:a", "libvorbis", "-q:a", "5"] if name.endswith(".ogg") else ["-c:a", "pcm_s16le"]
	subprocess.run([FF, "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-"] + codec + [path],
			input=x.tobytes(), check=True)
	rows.append([name, ";".join(sorted(set(sources))), note])


def one_shot(name: str, parts: list, note: str) -> None:
	x, src = mix(parts)
	write(name, fade_out(peak_norm(x), 0.01), src, note)


def imp(stem: str, i: int) -> str:
	return K_IMP + "%s_%03d.ogg" % (stem, i)


def inter(stem: str, i: int) -> str:
	return K_INT + "%s_%03d.ogg" % (stem, i)


# --- Wind: real field recording + a looped wind section, three intensities.
park = load(O["park"], "highpass=f=30")
low = rms_norm(steady_window(park, 10.0), -20.0)
body = rms_norm(pitch(load(O["woosh"], "lowpass=f=900"), -6.0), -24.0)
body = np.tile(body, (int(len(low) / len(body)) + 1, 1))[: len(low)]
write("wind/wind_low.ogg", rms_norm(loop_seam(low + body, 0.8), -18.0), [O["park"], O["woosh"]],
		"evenest 10 s of the field recording + the whoosh loop 6 st down, low-passed, seam crossfaded")
woosh = load(O["woosh"])
write("wind/wind_mid.ogg", rms_norm(loop_seam(woosh, 0.25), -18.0), [O["woosh"]], "normalized")
sw = load(O["shortwind"], "highpass=f=500")
peak_at = int(np.argmax(np.abs(sw).sum(axis=1)))
start = max(0, peak_at - int(1.2 * SR))
sw = rms_norm(sw[start: start + int(2.4 * SR)], -20.0)
hi_w = rms_norm(pitch(load(O["woosh"], "highpass=f=1200"), 7.0), -20.0)
hi_n = len(hi_w)
hi = hi_w + np.tile(sw, (hi_n // len(sw) + 1, 1))[:hi_n] * 0.7
# Half a loop's offset between the channels: the high layer sounds wide.
hi = np.stack([hi[:, 0], np.roll(hi[:, 1], hi_n // 2)], axis=1)
write("wind/wind_high.ogg", rms_norm(loop_seam(hi, 0.3), -18.0), [O["woosh"], O["shortwind"]],
		"whoosh loop high-passed and 7 st up + short wind sound; channels offset for width")

# --- Tank: the sound set. Engine = real engine recordings, treads = chain + machine loops.
def tile_to(x: np.ndarray, n: int) -> np.ndarray:
	return np.tile(x, (n // len(x) + 1, 1))[:n]


idle = rms_norm(np.tile(load(O["idle"])[int(0.1 * SR): int(1.75 * SR)], (2, 1)), -18.0)
idle = idle + tile_to(rms_norm(load(O["racing"]), -24.0), len(idle))
write("tank/engine_idle.ogg", rms_norm(loop_seam(idle, 0.2), -16.0), [O["idle"], O["racing"]],
		"engine loop doubled, a low car engine under it, seam crossfaded")
steam = rms_norm(pitch(load(O["steam"]), 4.0), -18.0)
car = rms_norm(pitch(load(O["car"] % "Car_Engine_Loop"), -4.0), -20.0)
high = steam + tile_to(car, len(steam))
write("tank/engine_high.ogg", rms_norm(loop_seam(high, 0.4), -16.0), [O["steam"], O["car"] % "Car_Engine_Loop"],
		"chugging engine 4 st up + car engine 4 st down, seam crossfaded")
winch = rms_norm(load(O["winch"] % "Region #1", "highpass=f=200"), -20.0)
thump = rms_norm(load(O["loops"] % "machine_02"), -22.0)
slow = np.tile(winch, (2, 1))
write("tank/tread_slow.ogg", rms_norm(loop_seam(slow + tile_to(thump, len(slow)), 0.15), -16.0),
		[O["winch"] % "Region #1", O["loops"] % "machine_02"], "chain winch ratchet + machine thump, seam crossfaded")
fast_a = rms_norm(load(O["loops"] % "machine_06"), -19.0)
fast_b = rms_norm(pitch(load(O["winch"] % "Region #1", "highpass=f=200"), 4.0), -21.0)
write("tank/tread_fast.ogg", rms_norm(loop_seam(fast_a + tile_to(fast_b, len(fast_a)), 0.3), -16.0),
		[O["loops"] % "machine_06", O["winch"] % "Region #1"], "machine loop + the chain ratchet 4 st up, seam crossfaded")
grind = rms_norm(load(O["ping"] % 30, "lowpass=f=11000")[int(0.5 * SR): int(4.5 * SR)], -20.0)
grind_low = rms_norm(np.tile(load(O["ping"] % 20)[int(0.3 * SR): int(3.5 * SR)], (2, 1)), -22.0)
write("tank/grind_loop.ogg", rms_norm(loop_seam(grind + grind_low[: len(grind)], 0.4), -18.0), [O["ping"] % 30, O["ping"] % 20],
		"two metal filing takes mixed, seam crossfaded")
for i, (a, s, ring) in enumerate([(0, 1, 11), (1, 2, 1), (2, 3, 3), (3, 4, 11)]):
	one_shot("tank/grind_catch_%d.wav" % (i + 1),
			[(imp("impactMetal_heavy", a), 0.0, 0.0, 0.0, 0.0), (O["mech"] % "clank1", -8.0, 0.0, s - 3.0, 0.0),
			(O["ping"] % ring, -9.0, 0.01, 0.0, 0.7)], "heavy metal hit + clank + ping ring-out")
# Hop = the cannon's recoil: a boom cut short + a metal clunk.
for i, (src, semis) in enumerate([(O["cannon"], 0.0), (O["bang"] % "bang_03", -3.0), (O["bang"] % "cannon_01", -5.0), (O["bang"] % "cannon_02", -5.0)]):
	one_shot("tank/hop_%d.wav" % (i + 1),
			[(src, 0.0, 0.0, semis, 0.65), (imp("impactMetal_heavy", i), -4.0, 0.0, -2.0, 0.0),
			(imp("impactPunch_heavy", i), -6.0, 0.0, 0.0, 0.0)], "cannon boom cut to 0.65 s + metal clunk + low thud")
# Exhaust whoosh on any boost; the full blast only on a cannon boost (tank branch).
for i, s in enumerate((7, 8, 9)):
	one_shot("tank/boost_%d.wav" % (i + 1),
			[(O["swish"] % s, 0.0, 0.0, -9.0, 0.0), (O["swish"] % (s + 3), -5.0, 0.03, -5.0, 0.0), (O["bang"] % ("fw_0%d" % (i + 1)), -9.0, 0.0, -8.0, 0.5)],
			"two swishes pitched down + a firework burst far down")
for i, (src, semis) in enumerate([(O["bang"] % "cannon_02", -2.0), (O["cannon"], 2.0), (O["bang"] % "bang_01", -4.0)]):
	one_shot("tank/cannon_blast_%d.wav" % (i + 1),
			[(src, 0.0, 0.0, semis, 1.1), (imp("impactPunch_heavy", i), -3.0, 0.0, 0.0, 0.0), (O["swish"] % (i + 3), -5.0, 0.02, -7.0, 0.0)],
			"cannon boom + thud + swish")
for i in range(4):
	one_shot("tank/land_perfect_%d.wav" % (i + 1),
			[(imp("impactMetal_heavy", i), 0.0, 0.0, 0.0, 0.3), (imp("impactPunch_medium", i), -2.0, 0.0, -2.0, 0.22)],
			"tight metal hit cut to 0.3 s + punch")
	one_shot("tank/land_good_%d.wav" % (i + 1),
			[(imp("impactMetal_medium", (i + 1) % 5), -2.0, 0.0, -3.0, 0.3), (imp("impactSoft_medium", (i + 2) % 5), 0.0, 0.0, 0.0, 0.0)],
			"softer metal hit + soft thud")
	one_shot("tank/land_sketchy_%d.wav" % (i + 1),
			[(imp("impactPunch_heavy", i), 0.0, 0.0, -3.0, 0.0), (imp("impactPlate_heavy", i), -2.0, 0.0, -2.0, 0.0),
			(imp("impactMetal_heavy", 4 - i), -3.0, 0.02, -3.0, 0.0), (O["mech"] % "rattle1", -3.0, 0.03, float(i) - 3.0, 0.0),
			(O["rpg"] % ("chain_0%d" % (i % 3 + 1)), -8.0, 0.06, -6.0, 0.0)], "big slam: thud + plate + metal + rattle + chain")
	one_shot("tank/crash_%d.wav" % (i + 1),
			[(imp("impactMetal_heavy", i), 0.0, 0.0, -2.0, 0.0), (O["bang"] % "bang_03", -4.0, 0.0, -2.0, 0.7), (O["crash"], -5.0, 0.04, -2.0, 0.0),
			(O["cavein"], -7.0, 0.1, 0.0, 1.2), (O["scrape"] % (i + 1), -7.0, 0.15, -3.0, 0.0)],
			"metal crash + boom + stapler crash + debris + scrape")
# Crushing props (the prop_crushed signal on the tank branch).
one_shot("tank/crush_1.wav", [(O["chop"], 0.0, 0.0, -3.0, 0.0), (imp("impactPlank_medium", 0), -3.0, 0.0, -2.0, 0.0), (imp("impactWood_heavy", 0), -4.0, 0.0, 0.0, 0.0)], "wood: chop + plank + heavy wood")
one_shot("tank/crush_2.wav", [(imp("impactPlank_medium", 2), 0.0, 0.0, -3.0, 0.0), (imp("impactWood_medium", 1), -2.0, 0.02, -2.0, 0.0), (O["chop"], -5.0, 0.03, 0.0, 0.0)], "wood: plank + wood + chop")
one_shot("tank/crush_3.wav", [(imp("impactMining", 1), 0.0, 0.0, -4.0, 0.0), (imp("impactMining", 2), -3.0, 0.02, -2.0, 0.0), (O["cavein"], -9.0, 0.03, 0.0, 0.6)], "rock: mining hits + debris")
one_shot("tank/crush_4.wav", [(imp("impactMining", 4), 0.0, 0.0, -5.0, 0.0), (imp("impactWood_heavy", 3), -3.0, 0.0, 0.0, 0.0), (O["cavein"], -9.0, 0.03, 2.0, 0.5)], "rock + wood + debris")
# Turret spin.
one_shot("tank/turret_1.wav", [(O["loops"] % "machine_10", 0.0, 0.0, 0.0, 0.55), (O["winch"] % "Marker #7", -7.0, 0.0, 3.0, 0.55)], "machine loop cut short + winch")
one_shot("tank/turret_2.wav", [(O["loops"] % "machine_07", 0.0, 0.0, 3.0, 0.55), (O["winch"] % "Marker #7", -7.0, 0.0, 5.0, 0.55)], "machine loop pitched up + winch")
one_shot("tank/turret_3.wav", [(O["loops"] % "machine_09", -2.0, 0.0, -3.0, 0.55), (O["winch"] % "Marker #5", -8.0, 0.0, 2.0, 0.55)], "machine loop pitched down + winch")

# --- Shared tonal layers, all tuned to A: every note is a pack sample, pitched.
# Kenney's confirmation_004 is an E major stab, _001 a G open fifth, pluck_001 is on A.
one_shot("feedback/note_perfect_1.wav",
		[(inter("confirmation", 4), 0.0, 0.0, -7.0, 0.0), (K_INT + "glass_004.ogg", -11.0, 0.03, 0.0, 0.0)],
		"major stab tuned to A + glass shimmer")
one_shot("feedback/note_perfect_2.wav",
		[(inter("confirmation", 1), 0.0, 0.0, 2.0, 0.0), (K_INT + "glass_004.ogg", -11.0, 0.03, 0.0, 0.0)],
		"open fifth tuned to A + glass shimmer")
one_shot("feedback/note_perfect_3.wav",
		[(inter("confirmation", 4), -2.0, 0.0, -7.0, 0.0), (inter("confirmation", 1), -5.0, 0.0, 2.0, 0.0),
		(K_INT + "glass_004.ogg", -11.0, 0.03, 0.0, 0.0)], "both stabs on A + glass shimmer")
one_shot("feedback/note_good_1.wav", [(inter("pluck", 1), 0.0, 0.0, 0.0, 0.0)], "pluck on A")
one_shot("feedback/note_good_2.wav", [(inter("pluck", 2), 0.0, 0.0, -6.0, 0.0)], "pluck tuned to A")
one_shot("feedback/note_sketchy_1.wav", [(imp("impactBell_heavy", 3), 0.0, 0.0, 0.0, 0.0)], "off-key bell; slides down at runtime")
one_shot("feedback/note_sketchy_2.wav", [(imp("impactBell_heavy", 2), 0.0, 0.0, 3.0, 0.0)], "off-key bell; slides down at runtime")
for i in range(3):
	one_shot("feedback/trick_%d.wav" % (i + 1), [(K_INT + "glass_%03d.ogg" % (i + 1), 0.0, 0.0, 0.0, 0.0)], "glass ping")
one_shot("feedback/gate_1.wav", [(inter("confirmation", 2), 0.0, 0.0, 0.0, 0.0)], "normalized")
one_shot("feedback/gate_2.wav", [(inter("confirmation", 3), 0.0, 0.0, -5.0, 0.0)], "pitched")
one_shot("feedback/banked_1.wav", [(K_JIN + "jingles_STEEL08.ogg", 0.0, 0.0, 5.0, 0.0)], "steel drum jingle, on A")
one_shot("feedback/banked_2.wav", [(K_JIN + "jingles_STEEL09.ogg", 0.0, 0.0, 5.0, 0.0)], "steel drum jingle")

# --- Collapse.
rumble = load(O["rumble"])[int(6.0 * SR): int(14.0 * SR)]
write("collapse/rumble.ogg", rms_norm(loop_seam(rumble, 1.0), -16.0), [O["rumble"]], "steady middle, seam crossfaded")
cave = load(O["cavein"])[int(0.8 * SR): int(3.8 * SR)]
write("collapse/debris.ogg", rms_norm(loop_seam(np.concatenate([cave, cave[::-1]]), 0.3), -18.0), [O["cavein"]],
		"steady middle played forward then back, seam crossfaded")
shake = load(O["shake"])[int(0.2 * SR): int(5.0 * SR)]
write("collapse/roar.ogg", rms_norm(loop_seam(shake, 0.6), -14.0), [O["shake"]], "seam crossfaded")
for i, (stem, take, semis) in enumerate([("impactWood_medium", 0, -3.0), ("impactPlank_medium", 1, -3.0), ("impactPlank_medium", 3, -5.0),
		("impactMining", 0, -3.0), ("impactMining", 3, -2.0)]):
	one_shot("collapse/crack_%d.wav" % (i + 1), [(imp(stem, take), 0.0, 0.0, semis, 0.0)], "pitched down")

with open(MANIFEST, "w", newline="", encoding="utf8") as f:
	csv.writer(f).writerows(rows)
print(len(rows), "files")
