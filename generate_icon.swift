#!/usr/bin/env swift
// Generates icon_1024.png using pure CoreGraphics — no NSApplication needed.
import Foundation
import CoreGraphics
import ImageIO

let sz  = 1024
let szf = CGFloat(sz)
let cs  = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(
    data: nil, width: sz, height: sz, bitsPerComponent: 8,
    bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { print("CGContext failed"); exit(1) }

// ── Clip to macOS Big Sur rounded square (22 % corner radius) ─────────────────
let r22  = szf * 0.22
let bgClip = CGPath(roundedRect: CGRect(x:0,y:0,width:szf,height:szf),
                    cornerWidth: r22, cornerHeight: r22, transform: nil)
ctx.addPath(bgClip); ctx.clip()

// ── Background: deep navy → near-black (diagonal) ────────────────────────────
let bgC = [CGColor(red:0.082,green:0.090,blue:0.220,alpha:1),
           CGColor(red:0.027,green:0.027,blue:0.082,alpha:1)] as CFArray
let bgG = CGGradient(colorsSpace:cs, colors:bgC, locations:[0,1])!
ctx.drawLinearGradient(bgG,
    start: CGPoint(x:0, y:szf), end: CGPoint(x:szf, y:0), options:[])

// ── Soft indigo radial glow in the centre ─────────────────────────────────────
let glC = [CGColor(red:0.361,green:0.431,blue:0.980,alpha:0.22),
           CGColor(red:0.361,green:0.431,blue:0.980,alpha:0)] as CFArray
let glG = CGGradient(colorsSpace:cs, colors:glC, locations:[0,1])!
let gc  = CGPoint(x:szf/2, y:szf*0.53)
ctx.drawRadialGradient(glG,
    startCenter:gc, startRadius:0,
    endCenter:gc,   endRadius:szf*0.42,
    options: CGGradientDrawingOptions(rawValue: 0))

// ── Window rect ───────────────────────────────────────────────────────────────
let wX:CGFloat=242, wY:CGFloat=336, wW:CGFloat=540, wH:CGFloat=364
let wR:CGFloat=30,  tH:CGFloat=84     // tH = title-bar height

let wPath = CGPath(roundedRect: CGRect(x:wX,y:wY,width:wW,height:wH),
                   cornerWidth:wR, cornerHeight:wR, transform:nil)

// Title-bar fill (clipped to window shape)
ctx.saveGState()
ctx.addPath(wPath); ctx.clip()
ctx.setFillColor(CGColor(red:1,green:1,blue:1,alpha:0.09))
ctx.fill(CGRect(x:wX, y:wY+wH-tH, width:wW, height:tH))
ctx.restoreGState()

// Title-bar separator
ctx.setStrokeColor(CGColor(red:1,green:1,blue:1,alpha:0.13))
ctx.setLineWidth(2)
ctx.move(to: CGPoint(x:wX,    y:wY+wH-tH))
ctx.addLine(to: CGPoint(x:wX+wW,y:wY+wH-tH))
ctx.strokePath()

// Traffic-light dots
let dotY = wY + wH - tH/2
for (x,r,g,b): (CGFloat,CGFloat,CGFloat,CGFloat) in [
    (wX+50,  1.000,0.373,0.341),   // red    #FF5F57
    (wX+98,  0.992,0.737,0.180),   // yellow #FEBC2E
    (wX+146, 0.157,0.784,0.251),   // green  #28C840
] {
    ctx.setFillColor(CGColor(red:r,green:g,blue:b,alpha:0.90))
    ctx.addEllipse(in: CGRect(x:x-14,y:dotY-14,width:28,height:28))
    ctx.fillPath()
}

// Window outline
ctx.addPath(wPath)
ctx.setStrokeColor(CGColor(red:1,green:1,blue:1,alpha:0.88))
ctx.setLineWidth(26)
ctx.strokePath()

// ── Four diagonal expand arrows ───────────────────────────────────────────────
let d:CGFloat  = 132 / CGFloat(2.0.squareRoot())  // diagonal step ≈ 93
let hd:CGFloat = 66                                // arrowhead arm length
let lw:CGFloat = 25                                // line width

ctx.setStrokeColor(CGColor(red:1,green:1,blue:1,alpha:0.93))
ctx.setLineWidth(lw)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

// (shaft-start, shaft-tip, [arm-end-1, arm-end-2])
let arrows: [(CGPoint, CGPoint, [CGPoint])] = [
    // SW — bottom-left corner
    ( CGPoint(x:wX,    y:wY),
      CGPoint(x:wX-d,  y:wY-d),
      [CGPoint(x:wX-d,    y:wY-d+hd), CGPoint(x:wX-d+hd,y:wY-d)] ),
    // SE — bottom-right corner
    ( CGPoint(x:wX+wW, y:wY),
      CGPoint(x:wX+wW+d,y:wY-d),
      [CGPoint(x:wX+wW+d,y:wY-d+hd), CGPoint(x:wX+wW+d-hd,y:wY-d)] ),
    // NW — top-left corner
    ( CGPoint(x:wX,    y:wY+wH),
      CGPoint(x:wX-d,  y:wY+wH+d),
      [CGPoint(x:wX-d,    y:wY+wH+d-hd), CGPoint(x:wX-d+hd,y:wY+wH+d)] ),
    // NE — top-right corner
    ( CGPoint(x:wX+wW, y:wY+wH),
      CGPoint(x:wX+wW+d,y:wY+wH+d),
      [CGPoint(x:wX+wW+d,y:wY+wH+d-hd), CGPoint(x:wX+wW+d-hd,y:wY+wH+d)] ),
]

for (start, tip, armEnds) in arrows {
    ctx.move(to:start); ctx.addLine(to:tip); ctx.strokePath()
    for arm in armEnds {
        ctx.move(to:tip); ctx.addLine(to:arm); ctx.strokePath()
    }
}

// ── Write PNG ─────────────────────────────────────────────────────────────────
guard let image = ctx.makeImage() else { print("makeImage failed"); exit(1) }
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let url     = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    print("ImageDestination failed"); exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { print("Finalize failed"); exit(1) }
print("✓ Saved \(outPath)")
