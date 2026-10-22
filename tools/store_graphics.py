#!/usr/bin/env python3
"""Графика для Chrome Web Store: два скриншота 1280×800 и малая промо-плитка 440×280.

    python3 tools/store_graphics.py <снимок карты из приложения.png>

Снимок делается tools/shot.sh; из него берется только область карты справа от боковой
панели, без аватара и личных мест.
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


def screenshot_app(map_img):
    img = background(1280, 800).convert("RGBA")
    d = ImageDraw.Draw(img)
    y = text_block(d, (64, 92), [
        ("Google Maps links", 44, 760, TEXT),
        ("open in a Mac app", 44, 760, ACCENT),
    ], gap=6)
    text_block(d, (64, y + 28), [
        ("Click a map link in Chrome — the place,", 22, 450, MUTED),
        ("search or route opens in Maps Desktop:", 22, 450, MUTED),
        ("its own window, dark mode, trackpad", 22, 450, MUTED),
        ("gestures. Chrome stays your browser.", 22, 450, MUTED),
    ], gap=8)
    ic = icon(84)
    img.paste(ic, (64, 640), ic)
    d.text((164, 652), "Maps Desktop", font=font(26, 700), fill=TEXT)
    d.text((164, 688), "Free and open source", font=font(18, 450), fill=MUTED)
    shadow_paste(img, app_window(map_img, 620, 620), (610, 90))
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
    for text, y, size, weight, color in [("Open in Maps Desktop", 166, 30, 760, TEXT),
                                         ("Google Maps links in a Mac app", 210, 18, 500, MUTED)]:
        f = font(size, weight)
        d.text(((440 - f.getlength(text)) / 2, y), text, font=f, fill=color)
    return img.convert("RGB")


if __name__ == "__main__":
    shot = Image.open(sys.argv[1]).convert("RGB")
    s = shot.width / 853      # снимок с Retina-экрана; координаты ниже — в масштабе 1/3
    map_img = shot.crop((int(318 * s), int(42 * s), int(812 * s), int(520 * s)))
    screenshot_app(map_img).save(f"{ROOT}/store/screenshot-1.png")
    screenshot_flow(map_img).save(f"{ROOT}/store/screenshot-2.png")
    promo_small().save(f"{ROOT}/store/promo-small.png")
    print("store/screenshot-1.png, store/screenshot-2.png, store/promo-small.png")
