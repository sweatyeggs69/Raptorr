"""Renders the tvOS app icon layers and Top Shelf images into the asset catalog.

Run from the repo root: python3 Design/AppIcon/generate.py (needs cairosvg and Pillow).
Layers are drawn on a 1280x768 canvas and scaled to each required size.
"""
import io
import json
import math
import os

import cairosvg
from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BRAND = os.path.join(ROOT, "Raptorr", "Assets.xcassets", "App Icon & Top Shelf Image.brandassets")
INFO = {"author": "xcode", "version": 1}

W, H = 1280, 768

BACK = """
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#1E2550"/>
    <stop offset="1" stop-color="#090B18"/>
  </linearGradient>
  <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#FF8A3D" stop-opacity="0.35"/>
    <stop offset="1" stop-color="#FF8A3D" stop-opacity="0"/>
  </radialGradient>
</defs>
<rect width="1280" height="768" fill="url(#bg)"/>
<ellipse cx="640" cy="384" rx="560" ry="420" fill="url(#glow)"/>
"""

# Rounded play triangle (corners rounded by a 72pt stroke), optically centered.
TRIANGLE = [(524, 200), (844, 384), (524, 568)]
ROUNDING = 36

def offset_line(p, q):
    # The edge p-q pushed outward by the stroke's half width (the triangle winds clockwise).
    dx, dy = q[0] - p[0], q[1] - p[1]
    length = math.hypot(dx, dy)
    nx, ny = dy / length * ROUNDING, -dx / length * ROUNDING
    return (p[0] + nx, p[1] + ny), (q[0] + nx, q[1] + ny)

def ray_hit(origin, direction, line):
    # Distance along the ray to the line, or None when it never reaches it.
    (x1, y1), (x2, y2) = line
    ex, ey = x2 - x1, y2 - y1
    det = direction[0] * ey - direction[1] * ex
    if abs(det) < 1e-9:
        return None
    t = ((x1 - origin[0]) * ey - (y1 - origin[1]) * ex) / det
    return t if t > 0 else None

def claw(t, reach=0.7, width=20):
    """A claw mark that opens in the top edge at fraction t and runs `reach` of the way across."""
    top = offset_line(TRIANGLE[0], TRIANGLE[1])
    start = (top[0][0] + (top[1][0] - top[0][0]) * t, top[0][1] + (top[1][1] - top[0][1]) * t)
    direction = (-0.42, 1.0)
    norm = math.hypot(*direction)
    direction = (direction[0] / norm, direction[1] / norm)
    hits = [ray_hit(start, direction, offset_line(TRIANGLE[i], TRIANGLE[(i + 1) % 3])) for i in (1, 2)]
    across = min(h for h in hits if h)
    end = (start[0] + direction[0] * across * reach, start[1] + direction[1] * across * reach)
    # Begin outside the edge so the cut opens cleanly, taper to a point at the end.
    outside = (start[0] - direction[0] * 30, start[1] - direction[1] * 30)
    px, py = -direction[1], direction[0]
    mid = ((outside[0] + end[0]) / 2, (outside[1] + end[1]) / 2)
    return (f'M {outside[0] - px * width:.1f} {outside[1] - py * width:.1f} '
            f'Q {mid[0] - px * width * 0.9:.1f} {mid[1] - py * width * 0.9:.1f} {end[0]:.1f} {end[1]:.1f} '
            f'Q {mid[0] + px * width * 0.5:.1f} {mid[1] + py * width * 0.5:.1f} {outside[0] + px * width * 0.3:.1f} {outside[1] + py * width * 0.3:.1f} Z')

# Cut out of the triangle after rendering (cairosvg ignores SVG masks).
CLAWS = "".join(f'<path d="{claw(t)}" fill="#000000"/>' for t in (0.3, 0.5, 0.7))
POINTS = " ".join(f"{x},{y}" for x, y in TRIANGLE)

FRONT = f"""
<defs>
  <linearGradient id="play" x1="0" y1="0" x2="0.6" y2="1">
    <stop offset="0" stop-color="#FFC24B"/>
    <stop offset="1" stop-color="#F0532A"/>
  </linearGradient>
</defs>
<polygon points="{POINTS}" fill="url(#play)" stroke="url(#play)"
         stroke-width="{ROUNDING * 2}" stroke-linejoin="round"/>
"""

def svg(body, w, h, vw=W, vh=H, vx=0):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="{vx} 0 {vw} {vh}">{body}</svg>')

def rasterize(body, w, h, **kw):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg(body, w, h, **kw).encode()))).convert("RGBA")

def render(body, w, h, cut=None, **kw):
    image = rasterize(body, w, h, **kw)
    if cut:
        hole = rasterize(cut, w, h, **kw).getchannel("A")
        image.putalpha(ImageChops.subtract(image.getchannel("A"), hole))
    return image

def save(body, path, w, h, cut=None, **kw):
    render(body, w, h, cut, **kw).save(path)

def write_json(path, data):
    with open(os.path.join(path, "Contents.json"), "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

def image_stack(name, size, scales):
    stack = os.path.join(BRAND, f"{name}.imagestack")
    layers = [("Front", FRONT), ("Back", BACK)]
    for layer, body in layers:
        cut = CLAWS if layer == "Front" else None
        content = os.path.join(stack, f"{layer}.imagestacklayer", "Content.imageset")
        os.makedirs(content, exist_ok=True)
        images = []
        for scale in scales:
            filename = f"{layer}{'' if scale == 1 else f'@{scale}x'}.png"
            save(body, os.path.join(content, filename), size[0] * scale, size[1] * scale, cut)
            images.append({"filename": filename, "idiom": "tv", "scale": f"{scale}x"})
        write_json(content, {"images": images, "info": INFO})
        write_json(os.path.dirname(content), {"info": INFO})
    write_json(stack, {"info": INFO, "layers": [{"filename": f"{l}.imagestacklayer"} for l, _ in layers]})

def top_shelf(name, size):
    folder = os.path.join(BRAND, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    w, h = size
    # Widen the 1280x768 artwork to the banner's aspect, keeping the mark centered.
    vh = H
    vw = vh * w / h
    vx = (W - vw) / 2
    back = BACK.replace('width="1280"', f'x="{vx}" width="{vw}"').replace('rx="560"', f'rx="{vw * 0.4}"')
    images = []
    for scale in (1, 2):
        filename = f"{name.replace(' ', '')}{'' if scale == 1 else '@2x'}.png"
        size = (w * scale, h * scale)
        view = {"vw": vw, "vh": vh, "vx": vx}
        image = Image.alpha_composite(render(back, *size, **view), render(FRONT, *size, CLAWS, **view))
        image.convert("RGB").save(os.path.join(folder, filename))
        images.append({"filename": filename, "idiom": "tv", "scale": f"{scale}x"})
    write_json(folder, {"images": images, "info": INFO})

def main():
    os.makedirs(BRAND, exist_ok=True)
    image_stack("App Icon", (400, 240), (1, 2))
    image_stack("App Icon - App Store", (1280, 768), (1,))
    top_shelf("Top Shelf Image", (1920, 720))
    top_shelf("Top Shelf Image Wide", (2320, 720))
    write_json(BRAND, {
        "assets": [
            {"filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"},
            {"filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"},
            {"filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"},
            {"filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"},
        ],
        "info": INFO,
    })

if __name__ == "__main__":
    main()
