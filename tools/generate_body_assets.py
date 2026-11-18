"""Generate original retro-CRT anatomy art. Pillow is only needed to regenerate."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / 'combat_v2/assets/body'
OUT.mkdir(parents=True, exist_ok=True)
SCALE = 3
PALETTE = {'unknown': '#365b47', 'clear': '#78f7a3', 'warning': '#ffd166',
           'broken': '#ff755f', 'mangled': '#ec83ff'}
PARTS = ('head', 'torso', 'left_arm', 'right_arm', 'left_leg', 'right_leg')


def piece(part, ink):
    layer = Image.new('RGBA', (200*SCALE, 320*SCALE))
    d = ImageDraw.Draw(layer)
    rgb = tuple(bytes.fromhex(ink[1:]))
    fill, edge = rgb+(32,), rgb+(245,)
    def points(p):
        return [(int(x*SCALE), int(y*SCALE)) for x, y in p]
    def line(p, width=1):
        d.line(points(p), fill=edge, width=width*SCALE, joint='curve')
    def poly(p):
        q = points(p)
        d.polygon(q, fill=fill)
        d.line(q+[q[0]], fill=edge, width=2*SCALE, joint='curve')
    def rect(box, radius=0):
        b = tuple(int(v*SCALE) for v in box)
        d.rounded_rectangle(b, radius=radius*SCALE, fill=fill, outline=edge, width=2*SCALE)
    if part == 'head':
        rect((69, 20, 131, 82), 24)
        line([(72, 42), (83, 29), (112, 28), (128, 41)], 2)
        line([(78, 48), (91, 48)], 3)
        line([(108, 48), (120, 48)], 3)
        line([(99, 48), (96, 60), (103, 60)])
        line([(85, 68), (96, 73), (111, 68)], 2)
        rect((64, 46, 69, 62), 2); rect((131, 46, 136, 62), 2)
    elif part == 'torso':
        poly([(88, 83), (112, 83), (142, 96), (136, 132), (124, 179),
              (76, 179), (64, 132), (58, 96)])
        line([(88, 85), (100, 99), (112, 85)], 2)
        line([(70, 103), (87, 118), (113, 118), (130, 103)], 2)
        line([(100, 99), (100, 152)])
        line([(78, 151), (122, 151)], 3)
        rect((76, 161, 124, 175), 3)
        rect((94, 163, 106, 173), 2)
        line([(78, 125), (87, 125), (87, 138), (78, 138), (78, 125)])
        line([(112, 125), (123, 125)]); line([(112, 133), (123, 133)])
    elif part.endswith('arm'):
        p = [(142, 95), (155, 96), (176, 137), (173, 151), (156, 184),
             (144, 179), (155, 143), (136, 116)]
        if part == 'right_arm': p = [(200-x, y) for x, y in p]
        poly(p)
        mirror = (lambda x: 200-x) if part == 'right_arm' else (lambda x: x)
        line([(mirror(154), 135), (mirror(172), 143)], 3)
        box = (140, 177, 159, 198) if part == 'left_arm' else (41, 177, 60, 198)
        rect(box, 6)
        for x in (145, 150, 155):
            line([(mirror(x), 182), (mirror(x), 190)])
    else:
        p = [(102, 182), (123, 182), (133, 232), (127, 281), (106, 281),
             (108, 234), (99, 205)]
        if part == 'right_leg': p = [(200-x, y) for x, y in p]
        poly(p)
        mirror = (lambda x: 200-x) if part == 'right_leg' else (lambda x: x)
        line([(mirror(109), 233), (mirror(129), 233)], 3)
        boot = [(106, 280), (127, 280), (147, 293), (147, 303), (103, 303), (103, 292)]
        if part == 'right_leg': boot = [(200-x, y) for x, y in boot]
        poly(boot)
        line([(mirror(110), 287), (mirror(124), 290)])
    glow = layer.filter(ImageFilter.GaussianBlur(3*SCALE))
    return Image.alpha_composite(glow, layer).resize((200, 320), Image.Resampling.LANCZOS)


for part in PARTS:
    for name, ink in PALETTE.items():
        piece(part, ink).save(OUT / f'{part}_{name}.png', optimize=True)
background = Image.new('RGB', (920, 620), '#07100b')
d = ImageDraw.Draw(background)
for y in range(0, 620, 4):
    d.line((0, y, 920, y), fill='#0c1a11')
for x in range(0, 920, 40):
    d.line((x, 0, x, 620), fill='#102518')
for y in range(0, 620, 40):
    d.line((0, y, 920, y), fill='#102518')
background.save(OUT / 'crt_grid.png', optimize=True)
print(f'Generated {len(PARTS)*len(PALETTE)+1} original PNG assets in {OUT}')
