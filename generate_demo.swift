#!/usr/bin/env swift
import Foundation
import CoreGraphics
import CoreText
import ImageIO

let W = 1400, H = 680
let wf = CGFloat(W), hf = CGFloat(H)
let cs = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { exit(1) }

// ── Background ────────────────────────────────────────────────────────────────
ctx.setFillColor(CGColor(red:0.055, green:0.055, blue:0.075, alpha:1))
ctx.fill(CGRect(x:0, y:0, width:wf, height:hf))

// Panel backgrounds
func panel(_ rect: CGRect) {
    let p = CGPath(roundedRect:rect, cornerWidth:16, cornerHeight:16, transform:nil)
    ctx.setFillColor(CGColor(red:0.10, green:0.10, blue:0.14, alpha:1))
    ctx.addPath(p); ctx.fillPath()
}
panel(CGRect(x:28,  y:28, width:654, height:624))
panel(CGRect(x:718, y:28, width:654, height:624))

// Arrow between panels
ctx.setFillColor(CGColor(red:0.361, green:0.431, blue:0.980, alpha:1))
let aw: CGFloat = 44, ah: CGFloat = 30, ax: CGFloat = wf/2 - aw/2, ay: CGFloat = hf/2
let arr = CGMutablePath()
arr.move(to:    CGPoint(x:ax,           y:ay + ah/2))
arr.addLine(to: CGPoint(x:ax+aw*0.55,  y:ay + ah/2))
arr.addLine(to: CGPoint(x:ax+aw*0.55,  y:ay + ah))
arr.addLine(to: CGPoint(x:ax+aw,       y:ay))
arr.addLine(to: CGPoint(x:ax+aw*0.55,  y:ay - ah))
arr.addLine(to: CGPoint(x:ax+aw*0.55,  y:ay - ah/2))
arr.addLine(to: CGPoint(x:ax,           y:ay - ah/2))
arr.closeSubpath()
ctx.addPath(arr); ctx.fillPath()

// ── Mini window helper ────────────────────────────────────────────────────────
func drawWindow(_ rect: CGRect) {
    let r: CGFloat = 10
    let path = CGPath(roundedRect:rect, cornerWidth:r, cornerHeight:r, transform:nil)
    ctx.setFillColor(CGColor(red:0.16, green:0.17, blue:0.22, alpha:1))
    ctx.addPath(path); ctx.fillPath()
    let tH: CGFloat = 22
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    ctx.setFillColor(CGColor(red:0.22, green:0.23, blue:0.30, alpha:1))
    ctx.fill(CGRect(x:rect.minX, y:rect.maxY-tH, width:rect.width, height:tH))
    // traffic lights
    let dotColors: [(CGFloat,CGFloat,CGFloat)] = [(1,0.37,0.34),(0.99,0.74,0.18),(0.16,0.78,0.25)]
    for (i, c) in dotColors.enumerated() {
        ctx.setFillColor(CGColor(red:c.0, green:c.1, blue:c.2, alpha:0.9))
        let dx = rect.minX + 12 + CGFloat(i)*18
        ctx.addEllipse(in: CGRect(x:dx-5, y:rect.maxY-tH/2-5, width:10, height:10))
        ctx.fillPath()
    }
    ctx.restoreGState()
    ctx.setStrokeColor(CGColor(red:1, green:1, blue:1, alpha:0.08))
    ctx.setLineWidth(1)
    ctx.addPath(path); ctx.strokePath()
}

// ── BEFORE: scattered windows ─────────────────────────────────────────────────
let bx: CGFloat = 28
for rect in [
    CGRect(x:bx+40,  y:280, width:340, height:220),
    CGRect(x:bx+120, y:100, width:440, height:290),
    CGRect(x:bx+50,  y:80,  width:200, height:160),
    CGRect(x:bx+300, y:390, width:300, height:180),
] { drawWindow(rect) }

// ── AFTER: one maximized window ───────────────────────────────────────────────
drawWindow(CGRect(x:736, y:46, width:618, height:588))

// ── Text labels via CoreText ──────────────────────────────────────────────────
func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, alpha: CGFloat = 1) {
    let font = CTFontCreateUIFontForLanguage(.system, size, nil)
              ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    let color = CGColor(red:1, green:1, blue:1, alpha:alpha)
    let attrs = [kCTFontAttributeName: font,
                 kCTForegroundColorFromContextAttributeName: true] as CFDictionary
    ctx.setFillColor(color)
    let str  = CFAttributedStringCreate(nil, text as CFString, attrs)!
    let line = CTLineCreateWithAttributedString(str)
    ctx.saveGState()
    ctx.textMatrix = CGAffineTransform(scaleX:1, y:-1)
    ctx.move(to: CGPoint(x:x, y:hf-y))
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

label("Before",  x:280, y:42,  size:17, alpha:0.40)
label("After",   x:975, y:42,  size:17, alpha:0.40)
label("Maximize",x:200, y:600, size:26, alpha:0.90)
label("Green button maximizes • Works on every app",
       x:100, y:632, size:14, alpha:0.35)

// ── Save ──────────────────────────────────────────────────────────────────────
guard let image = ctx.makeImage() else { print("makeImage failed"); exit(1) }
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "demo.png"
let dest = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: outPath) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("✓ Saved \(outPath)")
