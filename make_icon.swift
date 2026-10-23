import AppKit
// Иконка Maps Desktop: темная плашка и своя метка-капля с плавным радужным градиентом по кругу
// и большим отверстием. Нарисована с нуля, логотип Google не используется.
// swift make_icon.swift <папка .iconset>
let out = CommandLine.arguments[1]

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!

// Цвета по кругу от «12 часов» по часовой стрелке.
let ring: [(CGFloat, UInt32)] = [
    (0.00, 0x8A7BFF), (0.09, 0x4F8BFF), (0.22, 0x2FA8D8), (0.33, 0x22B573),
    (0.50, 0x1DB954), (0.60, 0x7CCB4A), (0.67, 0xF2C230), (0.74, 0xF59A2E),
    (0.81, 0xF0563F), (0.89, 0xE0457B), (0.95, 0xB45CD6), (1.00, 0x8A7BFF),
]

func pinPath(center c: CGPoint, radius r: CGFloat) -> CGMutablePath {
    let tip = CGPoint(x: c.x, y: c.y - r * 1.75)
    let alpha = acos(r / (c.y - tip.y))
    let right = -CGFloat.pi / 2 + alpha, left = -CGFloat.pi / 2 - alpha
    let path = CGMutablePath()
    path.addArc(center: c, radius: r, startAngle: right, endAngle: left + 2 * .pi, clockwise: false)
    let lp = CGPoint(x: c.x + r * cos(left), y: c.y + r * sin(left))
    let rp = CGPoint(x: c.x + r * cos(right), y: c.y + r * sin(right))
    // Бока слегка выгнуты, острие скруглено — как у современных значков-меток.
    path.addCurve(to: CGPoint(x: tip.x - r * 0.08, y: tip.y + r * 0.10),
                  control1: CGPoint(x: lp.x + (tip.x - lp.x) * 0.35, y: lp.y + (tip.y - lp.y) * 0.45),
                  control2: CGPoint(x: tip.x - r * 0.22, y: tip.y + r * 0.32))
    path.addQuadCurve(to: CGPoint(x: tip.x + r * 0.08, y: tip.y + r * 0.10), control: tip)
    path.addCurve(to: rp,
                  control1: CGPoint(x: tip.x + r * 0.22, y: tip.y + r * 0.32),
                  control2: CGPoint(x: rp.x + (tip.x - rp.x) * 0.35, y: rp.y + (tip.y - rp.y) * 0.45))
    path.closeSubpath()
    path.addEllipse(in: CGRect(x: c.x - r * 0.45, y: c.y - r * 0.45, width: r * 0.9, height: r * 0.9))
    return path
}

for (size, name) in [(16,"16x16"),(32,"16x16@2x"),(32,"32x32"),(64,"32x32@2x"),(128,"128x128"),(256,"128x128@2x"),(256,"256x256"),(512,"256x256@2x"),(512,"512x512"),(1024,"512x512@2x")] {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Плашка по сетке значков macOS: тело 824/1024, скругление ≈ 22,5 %.
    let inset = s * 100 / 1024
    let body = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let plate = CGPath(roundedRect: body, cornerWidth: body.width * 0.225, cornerHeight: body.width * 0.225, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.02, color: rgb(0x000000, 0.35))
    ctx.addPath(plate); ctx.setFillColor(rgb(0x1E1F22)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(plate); ctx.clip()
    let shade = CGGradient(colorsSpace: space, colors: [rgb(0x34363C), rgb(0x1C1D21)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(shade, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])
    ctx.restoreGState()

    // Метка: высота ≈ 61 % тела, ровно посередине плашки (от верха головки до острия). По центру масс
    // она смотрится низко — внизу только тонкое острие.
    let r = body.width * 0.225
    let center = CGPoint(x: body.midX, y: body.midY + r * 0.35)
    let pin = pinPath(center: center, radius: r)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.03, color: rgb(0x000000, 0.45))
    ctx.addPath(pin); ctx.setFillColor(rgb(0x1DB954)); ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(pin); ctx.clip(using: .evenOdd)
    // Конический градиент из тонких секторов (с нахлестом, без швов).
    let steps = 720
    for i in 0..<steps {
        let t = CGFloat(i) / CGFloat(steps)
        let k = ring.firstIndex { $0.0 > t } ?? ring.count - 1
        let (t0, c0) = ring[k - 1], (t1, c1) = ring[k]
        let f = (t - t0) / (t1 - t0)
        func mix(_ shift: UInt32) -> CGFloat {
            let a = CGFloat(c0 >> shift & 0xff), b = CGFloat(c1 >> shift & 0xff)
            return (a + (b - a) * f) / 255
        }
        ctx.setFillColor(CGColor(srgbRed: mix(16), green: mix(8), blue: mix(0), alpha: 1))
        let a0 = .pi / 2 - 2 * .pi * t, a1 = a0 - 2 * .pi / CGFloat(steps) * 1.6
        let wedge = CGMutablePath()
        wedge.move(to: center)
        wedge.addArc(center: center, radius: s, startAngle: a0, endAngle: a1, clockwise: true)
        wedge.closeSubpath()
        ctx.addPath(wedge); ctx.fillPath()
    }
    // Легкий объем: светлее сверху.
    let gloss = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.18), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gloss, start: CGPoint(x: 0, y: center.y + r), end: CGPoint(x: 0, y: center.y - r * 0.4), options: [])
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
