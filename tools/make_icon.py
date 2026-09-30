"""Derive Resources/HerdrToolsIcon.png from the Herdr logo with a unicorn horn.

Run from the repository root: python3 tools/make_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Resources" / "HerdrIcon.png"
OUT = ROOT / "Resources" / "HerdrToolsIcon.png"
TARGET = 1024
SS = 2

DARK = (56, 59, 61, 255)
CREAM = (238, 236, 228, 255)

ram = Image.open(SRC).convert("RGBA").resize((TARGET, TARGET), Image.LANCZOS)
W, H = ram.size


def bez(p0, p1, p2, t):
    u = 1 - t
    return (
        u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
        u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
    )


tip = (207.0, 42.0)
left = [(189.0, 160.0), (196.0, 92.0), tip]
right = [tip, (240.0, 96.0), (242.0, 154.0)]

N = 240
left_pts = [bez(*left, i / N) for i in range(N + 1)]
right_pts = [bez(*right, i / N) for i in range(N + 1)]
poly = left_pts + right_pts[1:]

K = (TARGET / 512.0) * SS
layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(layer)
pts = [(x * K, y * K) for x, y in poly]
d.polygon(pts, fill=CREAM)
d.line(pts + [pts[0]], fill=DARK, width=max(1, int(3 * K)), joint="curve")

for i in [int(N * f) for f in (0.22, 0.35, 0.48, 0.61, 0.74, 0.86)]:
    l = left_pts[i]
    r = right_pts[i]
    d.line([(l[0] * K, (l[1] + 4) * K), (r[0] * K, (r[1] - 4) * K)],
           fill=DARK, width=max(1, int(2.5 * K)))

layer = layer.resize((W, H), Image.LANCZOS)
Image.alpha_composite(ram, layer).save(OUT)
print("wrote", OUT)
