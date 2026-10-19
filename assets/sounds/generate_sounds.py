import numpy as np, subprocess, os, wave
SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '')
TMP = '/tmp/pips_wav/'
os.makedirs(OUT, exist_ok=True); os.makedirs(TMP, exist_ok=True)
rng = np.random.default_rng(42)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a, r, sustain=1.0):
    e = np.ones(n) * sustain
    na, nr = int(SR * a), int(SR * r)
    if na: e[:na] = np.linspace(0, 1, na) * sustain
    if nr: e[-nr:] *= np.linspace(1, 0, nr)
    return e
def lowpass(x, cutoff):
    # one-pole low-pass, cutoff may be array
    c = np.broadcast_to(np.asarray(cutoff, float), x.shape)
    a = 1 - np.exp(-2 * np.pi * c / SR)
    y = np.zeros_like(x); s = 0.0
    for i in range(len(x)):
        s += a[i] * (x[i] - s); y[i] = s
    return y
def highpass(x, cutoff): return x - lowpass(x, cutoff)
def saw(f, tt): ph = np.cumsum(np.broadcast_to(f, tt.shape) / SR); return 2 * (ph % 1) - 1
def sq(f, tt): return np.sign(np.sin(2 * np.pi * np.cumsum(np.broadcast_to(f, tt.shape) / SR)))
def sine(f, tt): return np.sin(2 * np.pi * np.cumsum(np.broadcast_to(f, tt.shape) / SR))
def reverb(x, wet=0.3, decay=1.6):
    n = int(SR * decay); ir = rng.standard_normal(n) * np.exp(-np.linspace(0, 7, n)); ir = lowpass(lowpass(ir, 1800), 2500)
    y = np.convolve(x, ir)[:len(x) + n] if False else fftconv(x, ir)
    y = y / (np.max(np.abs(y)) + 1e-9) * np.max(np.abs(x))
    out = np.zeros(len(y)); out[:len(x)] += x * (1 - wet); out += y * wet
    return out
def fftconv(a, b):
    n = len(a) + len(b) - 1; N = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(a, N) * np.fft.rfft(b, N), N)[:n]
def add(x, s, seg):
    e = min(len(x), s + len(seg)); x[s:e] += seg[:e - s]
def norm(x, peak=0.9): return x / (np.max(np.abs(x)) + 1e-9) * peak
def save(name, x, stereo_width=0.0):
    x = norm(x)
    if x.ndim == 1:
        x = np.stack([x, x], 1)
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    p = TMP + name + '.wav'
    with wave.open(p, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', p, '-codec:a', 'libmp3lame', '-b:a', '160k', OUT + name + '.mp3'], check=True)
def wrap(y, n):
    # fold the reverb tail back onto the start so the loop is seamless
    out = y[:n].copy(); tail = y[n:]; k = min(len(tail), n); out[:k] += tail[:k]; return out
def fadeout(x, d=0.05):
    k = int(SR * d); x[-k:] *= np.linspace(1, 0, k); return x
def loopify(x, fade=1.0):
    n = int(SR * fade); head, body = x[:n], x[n:]
    body[-n:] = body[-n:] * np.linspace(1, 0, n) + head * np.linspace(0, 1, n)
    return body

# 1. JUMPSCARE — screeching, distorted animatronic scream + impact
d = 1.8; tt = t(d); n = len(tt)
f0 = 900 * np.exp(-tt * 0.6) + 300 + 60 * np.sin(2 * np.pi * 23 * tt)
scream = sum(saw(f0 * r, tt) for r in (1, 1.06, 1.49, 2.02)) / 4
scream = np.tanh(scream * 6)
noise = highpass(rng.standard_normal(n), 1500) * 0.6
mech = sq(37 + 20 * np.sin(2 * np.pi * 3 * tt), tt) * 0.4  # servo grind
impact = np.sin(2 * np.pi * 55 * tt * np.exp(-tt * 3)) * np.exp(-tt * 6) * 2.5
x = (scream + noise + mech) * env(n, 0.005, 0.5) + impact
x = np.round(x * 10) / 10  # bitcrush
save('jumpscare', fadeout(reverb(x, 0.25, 1.2)))

# 2. AMBIENCE — 40s loop: low drone, electrical hum, wind, distant clanks
d = 41; tt = t(d); n = len(tt)
drone = sum(sine(f * (1 + 0.003 * np.sin(2 * np.pi * 0.07 * tt + k)), tt) for k, f in enumerate((55, 55.4, 82.4, 110.3))) / 4
hum = (sine(60, tt) + 0.5 * sine(120, tt) + 0.25 * sq(180, tt) * 0.2) * 0.12
wind = lowpass(rng.standard_normal(n), 300 + 250 * (1 + np.sin(2 * np.pi * 0.05 * tt))) * 2.5
x = drone * 0.5 + hum + wind * 0.35
for k in range(9):
    pos = int(rng.uniform(1, d - 3) * SR); m = int(SR * 2.5); ct = t(2.5)
    clank = sum(sine(f, ct) * np.exp(-ct * (3 + i)) for i, f in enumerate(rng.uniform(300, 1800, 4)))
    x[pos:pos + m] += clank * 0.08
x = lowpass(wrap(reverb(x, 0.45, 3.0), n), 1400)
save('ambience', x)

# 3. HEARTBEAT — 2 beats loop (~80 bpm)
d = 1.5; tt = t(d); n = len(tt); x = np.zeros(n)
for start, amp in ((0.0, 1.0), (0.24, 0.7)):
    s = int(start * SR); bt = t(0.35)
    beat = np.sin(2 * np.pi * (60 * np.exp(-bt * 4) + 35) * bt) * np.exp(-bt * 12) * amp
    x[s:s + len(beat)] += beat
x = lowpass(x, 200)
save('heartbeat', x)

# 4. CHASE — 9.6s tense loop, 150 bpm, minor ostinato + stabs + drums
bpm = 150; beat = 60 / bpm; bars = 6; d = beat * 4 * bars; tt = t(d); n = len(tt); x = np.zeros(n)
notes = [55, 55, 65.4, 55, 58.3, 55, 69.3, 61.7]  # A minor-ish with b2 tension
step = beat / 2
for i in range(int(d / step)):
    s = int(i * step * SR); nt = t(step * 0.95); f = notes[i % len(notes)]
    b = (saw(f, nt) + 0.5 * saw(f * 2.005, nt)) * np.exp(-nt * 5)
    x[s:s + len(b)] += lowpass(b, 900) * 0.6
for i in range(int(d / beat)):
    s = int(i * beat * SR); kt = t(0.25)
    kick = np.sin(2 * np.pi * (120 * np.exp(-kt * 25) + 45) * kt) * np.exp(-kt * 10)
    x[s:s + len(kick)] += kick * 0.9
    if i % 2 == 1:
        sn = highpass(rng.standard_normal(len(kt)), 2000) * np.exp(-kt * 18) * 0.5
        x[s:s + len(sn)] += sn
for bar in range(bars):
    s = int(bar * beat * 4 * SR); st = t(beat * 1.5)
    chord = sum(saw(f, st) for f in (440, 466.2, 659.3)) * np.exp(-st * 2.5) * 0.18
    x[s:s + len(chord)] += highpass(chord, 400)
save('chase', wrap(reverb(x, 0.15, 0.8), n))

# 5. PICKUP — bright two-note chime
d = 0.5; tt = t(d); x = np.zeros(len(tt))
for st, f in ((0, 1318.5), (0.07, 1975.5)):
    s = int(st * SR); ct = t(d - st)
    add(x, s, (sine(f, ct) + 0.3 * sine(f * 2, ct)) * np.exp(-ct * 9))
save('pickup', fadeout(reverb(x, 0.2, 0.6)))

# 6. CAPSULE — pop + rising sparkle arpeggio
d = 1.4; tt = t(d); n = len(tt); x = np.zeros(n)
pt = t(0.12); x[:len(pt)] += highpass(rng.standard_normal(len(pt)), 800) * np.exp(-pt * 40) + np.sin(2 * np.pi * 300 * pt) * np.exp(-pt * 30)
for i, f in enumerate((784, 988, 1175, 1568, 1976, 2349)):
    s = int((0.1 + i * 0.07) * SR); ct = t(0.6)
    seg = (sine(f, ct) + 0.4 * sine(f * 3, ct)) * np.exp(-ct * 7) * 0.6
    x[s:s + len(seg)] += seg[:n - s]
save('capsule', fadeout(reverb(x, 0.3, 1.0)))

# 7. SIX AM — victory bell chimes (major arpeggio, bell partials)
d = 4.0; tt = t(d); n = len(tt); x = np.zeros(n)
for i, f in enumerate((523.3, 659.3, 784, 1046.5)):
    s = int(i * 0.35 * SR); ct = t(d - i * 0.35)
    bell = sum(sine(f * p, ct) * np.exp(-ct * (1.2 + k * 1.5)) * a for k, (p, a) in enumerate(((1, 1), (2.76, 0.4), (5.4, 0.2), (2.0, 0.3))))
    add(x, s, bell)
save('six_am', fadeout(reverb(x, 0.35, 2.0)))

# 8. MUSIC BOX — creepy lullaby loop (played near the music box / when Jinx is out)
melody = [(659.3, 1), (587.3, 1), (523.3, 1), (587.3, 1), (659.3, 1), (659.3, 1), (659.3, 2), (587.3, 1), (587.3, 1), (587.3, 2),
          (659.3, 1), (783.99, 1), (783.99, 2), (659.3, 1), (587.3, 1), (523.3, 1), (587.3, 1), (659.3, 1), (659.3, 1), (659.3, 1), (622.3, 1), (587.3, 1), (587.3, 1), (659.3, 1), (587.3, 1), (523.3, 4)]
q = 0.32; d = sum(b for _, b in melody) * q + 0.5; tt = t(d); n = len(tt); x = np.zeros(n); pos = 0.0
for f, b in melody:
    s = int(pos * SR); ct = t(1.4); detune = 1 + rng.uniform(-0.006, 0.006)
    note = (sine(f * 2 * detune, ct) + 0.35 * sine(f * 4 * detune, ct) + 0.15 * sine(f * 6.8, ct)) * np.exp(-ct * 3.2)
    end = min(n, s + len(note)); x[s:end] += note[:end - s]; pos += b * q
x *= 1 + 0.15 * np.sin(2 * np.pi * 0.5 * tt)
save('music_box', wrap(reverb(x, 0.4, 2.0), n))
print('done', sorted(os.listdir(OUT)))
