"""Generate the small deterministic sound set used by the game."""

from __future__ import annotations

import math
import random
import struct
import sys
import wave
from pathlib import Path


SAMPLE_RATE = 22_050
OUTPUT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).parents[1] / "assets" / "audio"
OUTPUT.mkdir(parents=True, exist_ok=True)


def clamp(value: float) -> float:
    return max(-1.0, min(1.0, value))


def write_wav(name: str, samples: list[float]) -> None:
    path = OUTPUT / name
    with wave.open(str(path), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(SAMPLE_RATE)
        target.writeframes(b"".join(struct.pack("<h", int(clamp(sample) * 32767)) for sample in samples))
    print(f"AUDIO_ASSET {name}: {len(samples) / SAMPLE_RATE:.2f}s")


def tone(duration: float, components: list[tuple[float, float, float]], gain: float = 1.0) -> list[float]:
    count = int(duration * SAMPLE_RATE)
    result = []
    for index in range(count):
        t = index / SAMPLE_RATE
        value = sum(amplitude * math.sin(math.tau * frequency * t + phase) for frequency, amplitude, phase in components)
        result.append(value * gain)
    return result


def loop_texture(duration: float, seed: int, low: float, high: float, voices: int, gain: float) -> list[float]:
    rng = random.Random(seed)
    components = []
    cycle = 1.0 / duration
    for _ in range(voices):
        raw_frequency = rng.uniform(low, high)
        frequency = round(raw_frequency / cycle) * cycle
        components.append((frequency, rng.uniform(0.012, 0.035), rng.uniform(0.0, math.tau)))
    return tone(duration, components, gain)


def mix(*tracks: list[float]) -> list[float]:
    length = max(len(track) for track in tracks)
    return [sum(track[index] if index < len(track) else 0.0 for track in tracks) for index in range(length)]


def fade(samples: list[float], fade_in: float, fade_out: float) -> list[float]:
    in_count = max(1, int(fade_in * SAMPLE_RATE))
    out_count = max(1, int(fade_out * SAMPLE_RATE))
    result = samples[:]
    for index in range(len(result)):
        envelope = min(1.0, index / in_count, (len(result) - 1 - index) / out_count)
        result[index] *= max(0.0, envelope)
    return result


def make_ambient() -> list[float]:
    duration = 8.0
    hum = tone(duration, [(46.0, 0.065, 0.0), (92.0, 0.022, 0.4), (138.0, 0.009, 1.3)])
    air = loop_texture(duration, 17, 165.0, 760.0, 34, 0.32)
    return mix(hum, air)


def make_water() -> list[float]:
    duration = 2.0
    texture = loop_texture(duration, 31, 310.0, 3_800.0, 68, 0.62)
    body = tone(duration, [(118.0, 0.035, 0.3), (237.5, 0.025, 1.1), (471.0, 0.018, 2.0)])
    return mix(texture, body)


def make_drone() -> list[float]:
    duration = 2.0
    motor = tone(duration, [(72.0, 0.12, 0.0), (144.0, 0.055, 0.6), (216.0, 0.025, 1.4)])
    flutter = loop_texture(duration, 41, 280.0, 680.0, 16, 0.35)
    for index in range(len(motor)):
        motor[index] *= 0.82 + 0.18 * math.sin(math.tau * 7.0 * index / SAMPLE_RATE)
    return mix(motor, flutter)


def make_step(seed: int) -> list[float]:
    rng = random.Random(seed)
    duration = 0.23
    count = int(duration * SAMPLE_RATE)
    filtered = 0.0
    result = []
    for index in range(count):
        t = index / SAMPLE_RATE
        envelope = math.exp(-t * 22.0)
        filtered = filtered * 0.72 + rng.uniform(-1.0, 1.0) * 0.28
        thump = math.sin(math.tau * (72.0 + seed * 3.0) * t) * 0.42
        grit = filtered * 0.34
        result.append((thump + grit) * envelope)
    return fade(result, 0.004, 0.02)


def make_chime(notes: list[float], duration: float, warning: bool = False) -> list[float]:
    count = int(duration * SAMPLE_RATE)
    result = []
    for index in range(count):
        t = index / SAMPLE_RATE
        envelope = (1.0 - math.exp(-t * 45.0)) * math.exp(-t * (7.0 if warning else 5.0))
        value = 0.0
        for note_index, frequency in enumerate(notes):
            start = note_index * 0.075
            if t >= start:
                local = t - start
                value += math.sin(math.tau * frequency * local) * math.exp(-local * 6.5) * 0.20
        result.append(value * envelope)
    return result


write_wav("ambient_hall.wav", make_ambient())
write_wav("water_pour.wav", make_water())
write_wav("drone_motor.wav", make_drone())
for variant in range(4):
    write_wav(f"footstep_{variant + 1}.wav", make_step(variant + 3))
write_wav("ui_confirm.wav", make_chime([523.25, 659.25], 0.38))
write_wav("ui_warning.wav", make_chime([246.94, 207.65], 0.34, True))
write_wav("delivery.wav", make_chime([392.0, 523.25, 659.25], 0.62))
write_wav("harvest.wav", make_chime([587.33, 783.99], 0.42))
print(f"AUDIO_BUILD_COMPLETE output={OUTPUT}")
