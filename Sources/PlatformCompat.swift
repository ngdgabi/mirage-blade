#if os(iOS)
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
#else
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
#endif
import SpriteKit
import CoreGraphics
import CoreText

extension SKColor {
    static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> SKColor {
        #if os(iOS)
        return UIColor(red: r, green: g, blue: b, alpha: a)
        #else
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
        #endif
    }

    static func hex(_ rgb: UInt32, alpha: CGFloat = 1.0) -> SKColor {
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        return .rgba(r, g, b, alpha)
    }
}

enum CoreTextLabelRenderer {
    static func makeLabelNode(
        _ text: String,
        fontSize: CGFloat,
        color: SKColor,
        bold: Bool = true
    ) -> SKLabelNode {
        let lbl = SKLabelNode(fontNamed: bold ? "Menlo-Bold" : "Menlo")
        lbl.text = text
        lbl.fontSize = fontSize
        lbl.fontColor = color
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        return lbl
    }
}

@MainActor
final class TouchInputState {
    static let shared = TouchInputState()

    var moveDX: CGFloat = 0
    var moveDY: CGFloat = 0
    var primaryHeld: Bool = false        // Careful Step / Strike / Sneak
    var primaryJustPressed: Bool = false // Scimitar Slash / Confirm
    var secondaryHeld: Bool = false      // Jump / Climb / Parry
    var secondaryJustPressed: Bool = false

    func reset() {
        moveDX = 0
        moveDY = 0
        primaryHeld = false
        primaryJustPressed = false
        secondaryHeld = false
        secondaryJustPressed = false
    }
}

@MainActor
enum HapticsManager {
    #if os(iOS)
    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let medGen = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private static let notifGen = UINotificationFeedbackGenerator()
    #endif

    static func tap() {
        #if os(iOS)
        lightGen.impactOccurred(intensity: 0.65)
        #endif
    }

    static func lightImpact() {
        #if os(iOS)
        lightGen.impactOccurred()
        #endif
    }

    static func mediumImpact() {
        #if os(iOS)
        medGen.impactOccurred()
        #endif
    }

    static func heavyImpact() {
        #if os(iOS)
        heavyGen.impactOccurred()
        #endif
    }

    static func success() {
        #if os(iOS)
        notifGen.notificationOccurred(.success)
        #endif
    }
}
