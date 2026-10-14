"""Renders the tvOS app icon layers and Top Shelf images into the asset catalog.

Run from the repo root: python3 Design/AppIcon/generate.py (needs cairosvg).
Layers are drawn on a 1280x768 canvas and scaled to each required size.
"""
import json
import os

import cairosvg

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

# Rounded play triangle, centered optically (shifted right of center).
MIDDLE = """
<defs>
  <linearGradient id="play" x1="0" y1="0" x2="0.6" y2="1">
    <stop offset="0" stop-color="#FFC24B"/>
    <stop offset="1" stop-color="#F0532A"/>
  </linearGradient>
</defs>
<polygon points="524,200 844,384 524,568" fill="url(#play)"
         stroke="url(#play)" stroke-width="72" stroke-linejoin="round"/>
"""

def slash(x, y):
    # A tapered claw mark: two curves meeting in points at each end.
    return (f'<path d="M {x+80} {y-160} Q {x+0} {y-10} {x-80} {y+160} '
            f'Q {x+50} {y} {x+80} {y-160} Z" fill="#FFFFFF"/>')

FRONT = "".join(slash(592 + i * 78, 384) for i in range(3))
FRONT = f'<g opacity="0.96">{FRONT}</g>'

def svg(body, w, h, vw=W, vh=H, vx=0):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="{vx} 0 {vw} {vh}">{body}</svg>')

def render(body, path, w, h, **kw):
    cairosvg.svg2png(bytestring=svg(body, w, h, **kw).encode(), write_to=path)

def write_json(path, data):
    with open(os.path.join(path, "Contents.json"), "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

def image_stack(name, size, scales):
    stack = os.path.join(BRAND, f"{name}.imagestack")
    layers = [("Front", FRONT), ("Middle", MIDDLE), ("Back", BACK)]
    for layer, body in layers:
        content = os.path.join(stack, f"{layer}.imagestacklayer", "Content.imageset")
        os.makedirs(content, exist_ok=True)
        images = []
        for scale in scales:
            filename = f"{layer}{'' if scale == 1 else f'@{scale}x'}.png"
            render(body, os.path.join(content, filename), size[0] * scale, size[1] * scale)
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
    body = back + MIDDLE + FRONT
    images = []
    for scale in (1, 2):
        filename = f"{name.replace(' ', '')}{'' if scale == 1 else '@2x'}.png"
        render(body, os.path.join(folder, filename), w * scale, h * scale, vw=vw, vh=vh, vx=vx)
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
