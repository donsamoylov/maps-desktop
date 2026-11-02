#!/usr/bin/env python3
"""Графика для Chrome Web Store: три скриншота 1280×800 и малая промо-плитка 440×280.

    ./build.sh            # рисует build/AppIcon.iconset
    python3 tools/store_graphics.py <темный снимок.png> <светлый снимок.png>

Снимки делает tools/shot.sh из одного и того же места карты, без входа в аккаунт:
window.__gmDark(true), затем window.__gmDark(false) и событие resize, чтобы карта перерисовалась.
Логотип и строка внизу карты в кадр не попадают.
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = __file__.rsplit("/tools/", 1)[0]
FONT = "/System/Library/Fonts/HelveticaNeue.ttc"
BG_TOP, BG_BOTTOM = (36, 38, 44), (16, 17, 20)
TEXT, MUTED, ACCENT = (240, 242, 246), (160, 166, 178), (138, 180, 248)


def font(size, weight=600):
    # Начертания Helvetica Neue в .ttc: 0 Regular, 10 Medium, 1 Bold.
    index = 1 if weight >= 700 else 10 if weight >= 550 else 0
    return ImageFont.truetype(FONT, size, index=index)


def background(w, h):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)))
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    return out


def shadow_paste(canvas, layer, xy, radius=24, blur=28, opacity=150):
    sh = Image.new("RGBA", (layer.width + blur * 4, layer.height + blur * 4), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([blur * 2, blur * 2, blur * 2 + layer.width, blur * 2 + layer.height],
                                         radius, fill=(0, 0, 0, opacity))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(sh, (xy[0] - blur * 2, xy[1] - blur * 2 + 12), sh)
    canvas.paste(layer, xy, layer)


def app_window(map_img, w, h, title="Maps Desktop"):
    bar = 40
    win = Image.new("RGB", (w, h), (30, 29, 30))
    crop = map_img.resize((w, int(map_img.height * w / map_img.width)), Image.LANCZOS)
    top = max(0, (crop.height - (h - bar)) // 2)
    win.paste(crop.crop((0, top, w, top + h - bar)), (0, bar))
    d = ImageDraw.Draw(win)
    for i, c in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
        d.ellipse([16 + i * 22, 13, 30 + i * 22, 27], fill=c)
    d.text((92, 9), title, font=font(17, 650), fill=(200, 204, 212))
    return rounded(win, 14)


def icon(size):
    return Image.open(f"{ROOT}/build/AppIcon.iconset/icon_512x512@2x.png").convert("RGBA").resize((size, size), Image.LANCZOS)


def text_block(d, xy, lines, gap=10):
    x, y = xy
    for text, size, weight, color in lines:
        f = font(size, weight)
        d.text((x, y), text, font=f, fill=color)
        y += f.getbbox(text)[3] + gap
    return y


def centered(d, text, y, f, fill, w=1280):
    d.text(((w - f.getlength(text)) / 2, y), text, font=f, fill=fill)


def pill(canvas, text, right=None, left=None, y=0, dark=True):
    f = font(17, 650)
    w = int(f.getlength(text)) + 32
    x = right - w if right is not None else left
    layer = Image.new("RGBA", (w, 36), (20, 22, 28, 235) if dark else (255, 255, 255, 240))
    ImageDraw.Draw(layer).text((16, 8), text, font=f, fill=TEXT if dark else (32, 33, 36))
    layer = rounded(layer, 18)
    canvas.paste(layer, (x, y), layer)


def screenshot_theme(dark, light):
    """Google Карты в Chrome до и после: один и тот же кадр, слева светлый, справа темный."""
    img = background(1280, 800).convert("RGBA")
    d = ImageDraw.Draw(img)
    centered(d, "Dark mode for Google Maps", 40, font(44, 760), TEXT)
    centered(d, "In Chrome, on any computer. It follows your system, or right-click the extension button",
             100, font(20, 450), MUTED)
    centered(d, "to keep it Light or Dark.", 128, font(20, 450), MUTED)

    w, bar, x, y = 1136, 44, 72, 176
    h = 800 - y - bar + 20    # окно уходит за нижний край кадра
    s = dark.width / 1280     # снимок с Retina-экрана
    box = (0, 0, dark.width, int(h * 1280 / w * s))
    page_dark = dark.crop(box).resize((w, h), Image.LANCZOS)
    page_light = light.crop(box).resize((w, h), Image.LANCZOS)
    middle = w // 2
    page = page_dark.copy()
    page.paste(page_light.crop((0, 0, middle, h)), (0, 0))

    win = Image.new("RGB", (w, bar + h), (41, 42, 46))
    wd = ImageDraw.Draw(win)
    wd.rectangle([0, 0, w, bar], fill=(53, 54, 58))
    for i, c in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
        wd.ellipse([16 + i * 20, 16, 28 + i * 20, 28], fill=c)
    wd.rounded_rectangle([96, 9, w - 60, 35], 13, fill=(32, 33, 36))
    wd.text((114, 13), "google.com/maps", font=font(14, 450), fill=MUTED)
    ic = icon(24)
    win.paste(ic, (w - 42, 10), ic)
    win.paste(page, (0, bar))
    wd.line([(middle, bar), (middle, bar + h)], fill=(255, 255, 255), width=3)
    win = rounded(win, 14).convert("RGBA")
    pill(win, "Without", right=middle - 14, y=bar + 66, dark=False)
    pill(win, "With Dark Maps", left=middle + 14, y=bar + 66)
    shadow_paste(img, win, (x, y))
    return img.convert("RGB")


def finger(d, x, y, r=17):
    d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, 210), outline=(255, 255, 255, 255), width=2)


def arrow(d, a, b, color=ACCENT, width=3, head=9):
    (x1, y1), (x2, y2) = a, b
    d.line([a, b], fill=color, width=width)
    dx, dy = x2 - x1, y2 - y1
    n = (dx * dx + dy * dy) ** 0.5 or 1
    ux, uy = dx / n, dy / n
    d.polygon([(x2 + ux * head, y2 + uy * head),
               (x2 - uy * head * 0.8, y2 + ux * head * 0.8),
               (x2 + uy * head * 0.8, y2 - ux * head * 0.8)], fill=color)


def gesture_row(img, x, y, kind, title, text):
    """Значок жеста и подпись."""
    tile = Image.new("RGB", (64, 64), (44, 47, 55))
    t = rounded(tile, 15).convert("RGBA")
    td = ImageDraw.Draw(t)
    if kind == "swipe":
        finger(td, 24, 40, 7), finger(td, 40, 40, 7)
        arrow(td, (24, 28), (24, 16), width=2, head=5), arrow(td, (40, 28), (40, 16), width=2, head=5)
    elif kind == "pinch":
        finger(td, 24, 40, 7), finger(td, 40, 24, 7)
        arrow(td, (17, 47), (11, 53), width=2, head=5), arrow(td, (47, 17), (53, 11), width=2, head=5)
    else:
        for row in (18, 32, 46):
            td.rounded_rectangle([14, row - 3, 42, row + 3], 3, fill=(170, 176, 188))
        arrow(td, (52, 40), (52, 24), width=2, head=5)
    img.paste(t, (x, y), t)
    d = ImageDraw.Draw(img)
    d.text((x + 82, y + 6), title, font=font(23, 700), fill=TEXT)
    d.text((x + 82, y + 36), text, font=font(18, 450), fill=MUTED)


def screenshot_app(map_img):
    img = background(1280, 800).convert("RGBA")
    d = ImageDraw.Draw(img)
    y = text_block(d, (64, 72), [
        ("A real Mac app", 44, 760, TEXT),
        ("with trackpad gestures", 44, 760, ACCENT),
    ], gap=6)
    rows = [("swipe", "Two-finger swipe", "Pans the map, like on a phone"),
            ("pinch", "Pinch", "Zooms in and out"),
            ("scroll", "Lists and panels", "Scroll normally")]
    for i, row in enumerate(rows):
        gesture_row(img, 64, y + 40 + i * 92, *row)
    ic = icon(84)
    img.paste(ic, (64, 640), ic)
    d.text((164, 652), "Maps Desktop", font=font(26, 700), fill=TEXT)
    d.text((164, 688), "Free and open source. macOS 14 or later.", font=font(18, 450), fill=MUTED)

    win = app_window(map_img, 620, 620)
    touch = Image.new("RGBA", win.size, (0, 0, 0, 0))
    td = ImageDraw.Draw(touch)
    cx, cy = 220, 215
    for fx in (cx - 30, cx + 30):
        arrow(td, (fx, cy - 24), (fx, cy - 70), width=4, head=11)
        td.ellipse([fx - 18, cy - 18, fx + 18, cy + 18], fill=(255, 255, 255, 120), outline=(255, 255, 255, 235), width=2)
    shadow_paste(img, Image.alpha_composite(win, touch), (610, 90))
    return img.convert("RGB")


def screenshot_flow(map_img):
    img = background(1280, 800).convert("RGBA")
    d = ImageDraw.Draw(img)
    title = "From a link to a map in one click"
    f = font(44, 760)
    d.text(((1280 - f.getlength(title)) / 2, 70), title, font=f, fill=TEXT)

    # Карточка «ссылка в Chrome».
    card = Image.new("RGB", (430, 300), (41, 42, 46))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle([0, 0, 429, 44], 0, fill=(53, 54, 58))
    for i, c in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
        cd.ellipse([14 + i * 20, 15, 26 + i * 20, 27], fill=c)
    cd.rounded_rectangle([86, 10, 410, 34], 12, fill=(32, 33, 36))
    cd.text((100, 13), "mail.example.com", font=font(14, 450), fill=MUTED)
    cd.text((28, 80), "Dinner on Friday?", font=font(22, 700), fill=TEXT)
    cd.text((28, 120), "Here's the place:", font=font(18, 450), fill=MUTED)
    cd.text((28, 152), "maps.app.goo.gl/Louvre", font=font(19, 550), fill=ACCENT)
    cd.line([(28, 178), (262, 178)], fill=ACCENT, width=2)
    cd.text((28, 222), "Chrome", font=font(15, 600), fill=(120, 126, 138))
    shadow_paste(img, rounded(card, 16), (70, 250))

    # Стрелка.
    d.line([(540, 400), (640, 400)], fill=ACCENT, width=6)
    d.polygon([(640, 384), (668, 400), (640, 416)], fill=ACCENT)
    d.text((520, 430), "Open in", font=font(17, 500), fill=MUTED)
    d.text((520, 452), "Maps Desktop", font=font(17, 650), fill=TEXT)

    shadow_paste(img, app_window(map_img, 500, 440), (710, 180))
    note = "The first time, tick “Always allow” in Chrome’s prompt."
    f = font(20, 450)
    d.text(((1280 - f.getlength(note)) / 2, 700), note, font=f, fill=MUTED)
    return img.convert("RGB")


def promo_small():
    img = background(440, 280).convert("RGBA")
    d = ImageDraw.Draw(img)
    ic = icon(112)
    img.paste(ic, (164, 34), ic)
    for text, y, size, weight, color in [("Dark Maps", 166, 30, 760, TEXT),
                                         ("by Maps Desktop · Mac app with gestures", 210, 18, 500, MUTED)]:
        f = font(size, weight)
        d.text(((440 - f.getlength(text)) / 2, y), text, font=f, fill=color)
    return img.convert("RGB")


if __name__ == "__main__":
    shot, light = (Image.open(path).convert("RGB") for path in sys.argv[1:3])
    s = shot.width / 1280     # снимок с Retina-экрана; для окна приложения — только карта, без панелей
    map_img = shot.crop((int(477 * s), int(63 * s), int(1218 * s), int(770 * s)))
    screenshot_theme(shot, light).save(f"{ROOT}/store/screenshot-1.png")
    screenshot_app(map_img).save(f"{ROOT}/store/screenshot-2.png")
    screenshot_flow(map_img).save(f"{ROOT}/store/screenshot-3.png")
    promo_small().save(f"{ROOT}/store/promo-small.png")
    print("store/screenshot-1.png, store/screenshot-2.png, store/screenshot-3.png, store/promo-small.png")
