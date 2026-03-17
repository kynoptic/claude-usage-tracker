//
//  IconRenderingPrimitives.swift
//  Claude Usage
//
//  Reusable drawing primitives for menu bar icon rendering.
//  All functions draw into the current NSGraphicsContext
//  (set up by NSImage(size:flipped:drawingHandler:)).
//

import Cocoa

// MARK: - Image Factory

/// Creates an `NSImage` using the modern block-based API, replacing deprecated `lockFocus`/`unlockFocus`.
func makeImage(width: CGFloat, height: CGFloat, drawing: @escaping (NSRect) -> Void) -> NSImage {
    NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
        drawing(rect)
        return true
    }
}

// MARK: - Rounded Bar Primitives

/// Draws a rounded-rect background bar.
func drawBarBackground(rect: NSRect, cornerRadius: CGFloat, color: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    color.setFill()
    path.fill()
}

/// Draws a rounded-rect fill bar (progress indicator).
func drawBarFill(rect: NSRect, cornerRadius: CGFloat, color: NSColor) {
    guard rect.width > 1 else { return }
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    color.setFill()
    path.fill()
}

/// Draws a battery-style outlined container with rounded corners.
func drawBarOutline(rect: NSRect, cornerRadius: CGFloat, color: NSColor, lineWidth: CGFloat = 1.2) {
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    color.setStroke()
    path.lineWidth = lineWidth
    path.stroke()
}

// MARK: - Progress Ring Primitives

/// Draws a full background ring at the given center/radius.
func drawRingBackground(center: NSPoint, radius: CGFloat, strokeWidth: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
    color.setStroke()
    path.lineWidth = strokeWidth
    path.stroke()
}

/// Draws a progress arc from 12-o'clock clockwise by `percentage` (0-100).
func drawProgressRing(
    center: NSPoint,
    radius: CGFloat,
    percentage: Double,
    strokeWidth: CGFloat,
    color: NSColor
) {
    guard percentage > 0 else { return }
    let startAngle: CGFloat = 90
    let endAngle = startAngle - (360 * CGFloat(percentage / 100.0))
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
    color.setStroke()
    path.lineWidth = strokeWidth
    path.lineCapStyle = .round
    path.stroke()
}

// MARK: - Text Primitives

/// Draws a string at the given point and returns its rendered size.
@discardableResult
func drawText(_ text: String, at point: NSPoint, attributes: [NSAttributedString.Key: Any]) -> CGSize {
    let nsString = text as NSString
    nsString.draw(at: point, withAttributes: attributes)
    return nsString.size(withAttributes: attributes)
}

/// Returns the size a string would occupy with the given attributes (without drawing).
func textSize(_ text: String, attributes: [NSAttributedString.Key: Any]) -> CGSize {
    (text as NSString).size(withAttributes: attributes)
}

/// Draws text centered horizontally within a given width at the specified y position.
func drawCenteredText(_ text: String, in width: CGFloat, xOrigin: CGFloat = 0, y: CGFloat, attributes: [NSAttributedString.Key: Any]) {
    let size = textSize(text, attributes: attributes)
    let x = xOrigin + (width - size.width) / 2
    drawText(text, at: NSPoint(x: x, y: y), attributes: attributes)
}

// MARK: - Shape Primitives

/// Draws a filled circle (dot indicator).
func drawDot(center: NSPoint, diameter: CGFloat, color: NSColor) {
    let rect = NSRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
    let path = NSBezierPath(ovalIn: rect)
    color.setFill()
    path.fill()
}

/// Draws a stroked circle outline.
func drawCircleOutline(center: NSPoint, diameter: CGFloat, color: NSColor, lineWidth: CGFloat) {
    let rect = NSRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
    let path = NSBezierPath(ovalIn: rect)
    color.setStroke()
    path.lineWidth = lineWidth
    path.stroke()
}
