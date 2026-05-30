#!/usr/bin/env swift
// Generates a 1024×1024 PNG of the Pane app icon.
// Usage: swift tools/IconGen.swift [output.png]
// Default output: /tmp/pane-icon-1024.png

import AppKit
import CoreGraphics

let side = 1024
let canvas = CGFloat(side)
let cs = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(
    data: nil, width: side, height: side,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fputs("CGContext failed\n", stderr); exit(1) }

// --- Background: rounded "squircle" with gradient & gloss --------------------

let bgInset: CGFloat = 80
let bgRect = CGRect(x: bgInset, y: bgInset, width: canvas - 2*bgInset, height: canvas - 2*bgInset)
let bgCorner = bgRect.width * 0.225
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: bgCorner, cornerHeight: bgCorner, transform: nil)

// Outer drop shadow (gives the whole icon a sense of weight)
ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -18),
    blur: 60,
    color: CGColor(srgbRed: 0, green: 0.05, blue: 0.20, alpha: 0.45)
)
ctx.addPath(bgPath)
ctx.setFillColor(CGColor(srgbRed: 0.30, green: 0.30, blue: 0.95, alpha: 1.0))
ctx.fillPath()
ctx.restoreGState()

// Background gradient: bright royal blue (top) → vivid indigo (bottom)
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
let bgColors = [
    CGColor(srgbRed: 0.46, green: 0.58, blue: 1.00, alpha: 1.0),
    CGColor(srgbRed: 0.28, green: 0.20, blue: 0.85, alpha: 1.0),
] as CFArray
let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0, 1])!
ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: canvas - bgInset), end: CGPoint(x: 0, y: bgInset), options: [])

// Top gloss highlight
let gloss = [
    CGColor(gray: 1.0, alpha: 0.32),
    CGColor(gray: 1.0, alpha: 0.0),
] as CFArray
let glossGrad = CGGradient(colorsSpace: cs, colors: gloss, locations: [0, 1])!
ctx.drawLinearGradient(
    glossGrad,
    start: CGPoint(x: 0, y: canvas - bgInset),
    end:   CGPoint(x: 0, y: canvas * 0.55),
    options: []
)
ctx.restoreGState()

// --- 2x2 grid of cells -------------------------------------------------------

let gridInset: CGFloat = 200
let gridSize = canvas - 2*gridInset
let cellGap: CGFloat = 30
let cellSize = (gridSize - cellGap) / 2
let cellCorner = cellSize * 0.22
let gridStartX = gridInset
let gridTopY   = canvas - gridInset    // CG origin is bottom-left; "top" is high Y

func drawCell(row: Int, col: Int, accent: Bool) {
    let x = gridStartX + CGFloat(col) * (cellSize + cellGap)
    let y = gridTopY - CGFloat(row + 1) * cellSize - CGFloat(row) * cellGap
    let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
    let path = CGPath(roundedRect: rect, cornerWidth: cellCorner, cornerHeight: cellCorner, transform: nil)

    // Drop shadow under the cell — keeps the 3D depth.
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -8),
        blur: 22,
        color: CGColor(srgbRed: 0, green: 0, blue: 0.10, alpha: 0.45)
    )
    ctx.addPath(path)
    ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // Fill: gradient inside the cell
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    if accent {
        let colors = [
            CGColor(srgbRed: 1.00, green: 0.83, blue: 0.30, alpha: 1.0),  // bright gold
            CGColor(srgbRed: 1.00, green: 0.42, blue: 0.10, alpha: 1.0),  // orange-red
        ] as CFArray
        let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: x, y: y + cellSize), end: CGPoint(x: x + cellSize, y: y), options: [])
    } else {
        let colors = [
            CGColor(gray: 1.00, alpha: 1.0),
            CGColor(gray: 0.86, alpha: 1.0),
        ] as CFArray
        let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: y + cellSize), end: CGPoint(x: 0, y: y), options: [])
    }

    // Inner top highlight (glassy edge)
    let hl = [
        CGColor(gray: 1.0, alpha: 0.70),
        CGColor(gray: 1.0, alpha: 0.0),
    ] as CFArray
    let hlGrad = CGGradient(colorsSpace: cs, colors: hl, locations: [0, 1])!
    ctx.drawLinearGradient(
        hlGrad,
        start: CGPoint(x: 0, y: y + cellSize),
        end:   CGPoint(x: 0, y: y + cellSize * 0.65),
        options: []
    )
    ctx.restoreGState()

    // Thin inner stroke for crispness
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setLineWidth(2)
    ctx.setStrokeColor(CGColor(gray: 1.0, alpha: 0.35))
    ctx.strokePath()
    ctx.restoreGState()
}

drawCell(row: 0, col: 0, accent: false)
drawCell(row: 0, col: 1, accent: true)   // top-right cell = pop of color
drawCell(row: 1, col: 0, accent: false)
drawCell(row: 1, col: 1, accent: false)

// --- Save PNG ----------------------------------------------------------------

guard let img = ctx.makeImage() else { fputs("makeImage failed\n", stderr); exit(1) }
let rep = NSBitmapImageRep(cgImage: img)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("PNG encode failed\n", stderr); exit(1)
}
let outPath = CommandLine.arguments.dropFirst().first ?? "/tmp/pane-icon-1024.png"
try png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
